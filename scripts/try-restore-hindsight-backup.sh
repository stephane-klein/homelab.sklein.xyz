#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

FILE="${1:-}"
BUCKET="${CNPG_BACKUPS_BUCKET:-homelab-cnpg-backups}"
REGION="${CNPG_BACKUPS_REGION:-fr-par}"
ENDPOINT="https://s3.${REGION}.scw.cloud"
PREFIX="hindsight-logical"
CONTAINER_NAME="hindsight-restore-tmp"
DB_NAME="hindsight"
DB_USER="hindsight"
DB_PASS="hindsight-restore"
DUMP_FILE="/tmp/hindsight-backup.dump"

cleanup() {
  echo ""
  echo "Stopping container..."
  podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

if [ -z "${CNPG_BACKUPS_ACCESS_KEY:-}" ] || [ -z "${CNPG_BACKUPS_SECRET_KEY:-}" ]; then
  echo "  CNPG_BACKUPS_ACCESS_KEY or CNPG_BACKUPS_SECRET_KEY not set"
  echo "  Source .secret first: source <(grep '^CNPG_BACKUPS_' .secret)"
  exit 1
fi

if [ -z "$FILE" ]; then
  echo "  No file specified, using latest backup..."
  FILE=$(AWS_ACCESS_KEY_ID="$CNPG_BACKUPS_ACCESS_KEY" \
         AWS_SECRET_ACCESS_KEY="$CNPG_BACKUPS_SECRET_KEY" \
         aws s3 ls "s3://${BUCKET}/${PREFIX}/" \
           --endpoint-url "$ENDPOINT" --region "$REGION" \
         | sort | tail -1 | awk '{print $4}')
  if [ -z "$FILE" ]; then
    echo "  No backups found."
    exit 1
  fi
  echo "  Latest: $FILE"
fi

S3_PATH="s3://${BUCKET}/${PREFIX}/${FILE}"
echo "=== Restoring: ${S3_PATH} ==="

echo "Starting ParadeDB container..."
podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
podman run -d --name "$CONTAINER_NAME" \
  -e POSTGRES_USER="$DB_USER" \
  -e POSTGRES_PASSWORD="$DB_PASS" \
  -e POSTGRES_DB="$DB_NAME" \
  docker.io/paradedb/paradedb:pg18

echo "Waiting for ParadeDB bootstrap to complete..."
podman exec "$CONTAINER_NAME" sh -c '
  # Wait for PostgreSQL to accept connections
  until pg_isready -q; do sleep 1; done
  # ParadeDB bootstrap may restart PostgreSQL, wait until stable
  while true; do
    if pg_isready -q; then
      sleep 3
      if pg_isready -q; then
        break
      fi
    fi
    sleep 1
  done
'

echo "Creating postgres role and a fresh restore database..."
podman exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" \
  -c "CREATE ROLE postgres;" 2>/dev/null || true
RESTORE_DB="hindsight_restore"
podman exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" \
  -c "CREATE DATABASE ${RESTORE_DB};"

echo "Downloading backup from S3..."
AWS_ACCESS_KEY_ID="$CNPG_BACKUPS_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$CNPG_BACKUPS_SECRET_KEY" \
  aws s3 cp "${S3_PATH}" "${DUMP_FILE}" \
    --endpoint-url "$ENDPOINT" --region "$REGION"

echo "Copying dump into container..."
podman cp "${DUMP_FILE}" "${CONTAINER_NAME}:/tmp/backup.dump"

echo "Restoring into database ${RESTORE_DB}..."
podman exec "$CONTAINER_NAME" pg_restore -U "$DB_USER" -d "$RESTORE_DB" \
  -Fc --no-owner --no-privileges /tmp/backup.dump || true

rm -f "${DUMP_FILE}"

echo ""
echo "=== Restore complete. Opening psql ==="
echo "  (type 'exit' to quit)"
echo ""
podman exec -it "$CONTAINER_NAME" psql -U "$DB_USER" -d "$RESTORE_DB"
