#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../"

if [ -z "${CNPG_BACKUPS_BUCKET:-}" ]; then
  if [ -f "config/cnpg/env" ]; then
    CNPG_BACKUPS_BUCKET=$(grep '^CNPG_BACKUPS_BUCKET=' "config/cnpg/env" | cut -d'"' -f2)
    CNPG_BACKUPS_REGION=$(grep '^CNPG_BACKUPS_REGION=' "config/cnpg/env" | cut -d'"' -f2)
  fi
fi

if [ -z "${CNPG_BACKUPS_ACCESS_KEY:-}" ]; then
  if [ -f ".secret" ]; then
    CNPG_BACKUPS_ACCESS_KEY=$(grep '^CNPG_BACKUPS_ACCESS_KEY=' ".secret" | cut -d'"' -f2)
    CNPG_BACKUPS_SECRET_KEY=$(grep '^CNPG_BACKUPS_SECRET_KEY=' ".secret" | cut -d'"' -f2)
  fi
fi

ENDPOINT="https://s3.$CNPG_BACKUPS_REGION.scw.cloud"

echo "=== CloudNativePG Backups ==="
echo "Bucket: s3://$CNPG_BACKUPS_BUCKET"
echo "Endpoint: $ENDPOINT"
echo ""

AWS_ACCESS_KEY_ID="$CNPG_BACKUPS_ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$CNPG_BACKUPS_SECRET_KEY" \
mise x awscli -- aws s3 ls --recursive --human-readable --summarize \
  --endpoint-url "$ENDPOINT" \
  "s3://$CNPG_BACKUPS_BUCKET/"
