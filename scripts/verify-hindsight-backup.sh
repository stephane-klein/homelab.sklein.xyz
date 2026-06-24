#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BUCKET="${CNPG_BACKUPS_BUCKET:-homelab-cnpg-backups}"
REGION="${CNPG_BACKUPS_REGION:-fr-par}"
ENDPOINT="https://s3.${REGION}.scw.cloud"
PREFIX="hindsight-logical"
FILE="${1:-}"

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
echo "=== Verifying: ${S3_PATH} ==="

AWS_ACCESS_KEY_ID="$CNPG_BACKUPS_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$CNPG_BACKUPS_SECRET_KEY" \
  aws s3 cp "${S3_PATH}" - \
    --endpoint-url "$ENDPOINT" --region "$REGION" \
  | podman run --rm -i ghcr.io/cloudnative-pg/postgresql:18 \
    sh -c 'cat > /tmp/backup.dump && pg_restore -l /tmp/backup.dump' > /dev/null \
    && echo "  ✅ Backup is valid" \
    || echo "  ❌ Backup is corrupted"
