#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

if [ -z "${CNPG_BACKUPS_BUCKET:-}" ] || [ -z "${CNPG_BACKUPS_ACCESS_KEY:-}" ]; then
  echo "  ERROR: CNPG backup credentials not found."
  echo "  Set CNPG_BACKUPS_* variables or ensure config/cnpg/env and .secret exist."
  exit 1
fi

NAMESPACE="cnpg-demo"
CLUSTER_NAME="dummy"
DB_NAME="dummydb"

ENDPOINT="https://s3.${CNPG_BACKUPS_REGION:-fr-par}.scw.cloud"
S3_URL="s3://${CNPG_BACKUPS_BUCKET}/${CLUSTER_NAME}"
TMP_VOLUME="pg-${CLUSTER_NAME}-dump-tmp"
TMP_CONTAINER="pg-dump-tmp"

CLUSTER_IMAGE=$(kubectl get pod -n "$NAMESPACE" \
  -l cnpg.io/cluster="$CLUSTER_NAME",cnpg.io/podRole=instance \
  -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || true)

CNPG_IMAGE="${CLUSTER_IMAGE:-ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie}"

echo "=== Restoring database ${DB_NAME} from barman S3 backup to local app ==="
echo "  S3 URL: $S3_URL"
echo "  CNPG image: $CNPG_IMAGE"
echo "  barman-cloud-restore version: $(podman run --rm "$CNPG_IMAGE" barman-cloud-restore --version 2>&1 | sed 's/^barman-cloud-restore //')"

echo ""
echo "  Fetching latest backup ID..."
BACKUP_ID=$(podman run --rm \
  -e AWS_ACCESS_KEY_ID="$CNPG_BACKUPS_ACCESS_KEY" \
  -e AWS_SECRET_ACCESS_KEY="$CNPG_BACKUPS_SECRET_KEY" \
  -e AWS_ENDPOINT_URL="$ENDPOINT" \
  "$CNPG_IMAGE" \
  barman-cloud-backup-list --format json \
    --endpoint-url "$ENDPOINT" \
    "${S3_URL}" \
    "$CLUSTER_NAME" 2>&1 | python3 -c "
import sys, json
data = json.load(sys.stdin)
backups = data.get('backups_list', [])
if backups:
    print(backups[-1]['backup_id'])
" 2>/dev/null || true)

if [ -z "$BACKUP_ID" ]; then
  echo "  ERROR: Could not determine latest backup ID."
  echo "  Make sure barman-cloud-backup-list can access the bucket."
  exit 1
fi

echo "  Latest backup ID: $BACKUP_ID"

echo ""
echo "  Ensuring local PostgreSQL is running..."
if ! podman container exists pg-dummy-local 2>/dev/null; then
  podman-compose -f podman-compose.yml up -d > /dev/null
fi
echo "  Waiting for local PostgreSQL to be ready..."
for i in $(seq 1 30); do
  if podman exec pg-dummy-local psql -U app -c "SELECT 1;" 2>/dev/null; then
    break
  fi
  sleep 1
done

if podman volume exists "$TMP_VOLUME" 2>/dev/null; then
  echo "  Removing existing temp volume..."
  podman volume rm "$TMP_VOLUME" > /dev/null
fi

echo "  Creating temp volume..."
podman volume create "$TMP_VOLUME" > /dev/null

echo "  Restoring PGDATA from S3..."
podman run --rm \
  -v "$TMP_VOLUME":/var/lib/postgresql/data \
  -e AWS_ACCESS_KEY_ID="$CNPG_BACKUPS_ACCESS_KEY" \
  -e AWS_SECRET_ACCESS_KEY="$CNPG_BACKUPS_SECRET_KEY" \
  -e AWS_ENDPOINT_URL="$ENDPOINT" \
  "$CNPG_IMAGE" \
  barman-cloud-restore \
    --endpoint-url "$ENDPOINT" \
    "${S3_URL}" \
    "$CLUSTER_NAME" \
    "$BACKUP_ID" \
    /var/lib/postgresql/data

echo "  Adjusting config for temporary PostgreSQL..."
podman run --rm \
  -v "$TMP_VOLUME":/var/lib/postgresql/data \
  "$CNPG_IMAGE" \
  sh -c "echo 'ssl = off' >> /var/lib/postgresql/data/postgresql.conf && \
         echo 'archive_mode = off' >> /var/lib/postgresql/data/postgresql.conf && \
         echo \"log_directory = 'log'\" > /var/lib/postgresql/data/custom.conf && \
         : > /var/lib/postgresql/data/override.conf && \
         rm -f /var/lib/postgresql/data/backup_label && \
         sed -i '/^host.*cert.*map=/s/^/# DISABLED: /' /var/lib/postgresql/data/pg_hba.conf && \
         mkdir -p /var/lib/postgresql/data/pg_wal/archive_status /var/lib/postgresql/data/pg_wal/summaries && \
         pg_resetwal -f -D /var/lib/postgresql/data"

echo "  Starting temporary PostgreSQL..."
podman run -d \
  --name "$TMP_CONTAINER" \
  -v "$TMP_VOLUME":/var/lib/postgresql/data \
  "$CNPG_IMAGE" \
  postgres -D /var/lib/postgresql/data \
  > /dev/null

echo "  Waiting for temporary PostgreSQL to be ready..."
for i in $(seq 1 30); do
  if podman exec "$TMP_CONTAINER" psql -U postgres -c "SELECT 1;" 2>/dev/null; then
    break
  fi
  sleep 1
done

echo "  Dumping database ${DB_NAME} from backup..."
podman exec -i "$TMP_CONTAINER" pg_dump -U postgres -Fc -d "$DB_NAME" > "/tmp/${DB_NAME}_${BACKUP_ID}.dump"

echo "  Cleaning up temporary container and volume..."
podman stop "$TMP_CONTAINER" > /dev/null 2>&1 || true
podman rm "$TMP_CONTAINER" > /dev/null 2>&1 || true
podman volume rm "$TMP_VOLUME" > /dev/null 2>&1 || true

echo "  Cleaning local app database..."
scripts/clean-local-db.sh

echo "  Restoring to local PostgreSQL (app)..."
podman exec -e PGPASSWORD=app -i pg-dummy-local pg_restore -U app -h 127.0.0.1 --no-owner --role=app -d app < "/tmp/${DB_NAME}_${BACKUP_ID}.dump"

rm -f "/tmp/${DB_NAME}_${BACKUP_ID}.dump"

echo ""
echo "=== Done ==="
echo "  Database ${DB_NAME} restored to local PostgreSQL (app)."
echo "  Connect with: mise enter-in-local-db"
