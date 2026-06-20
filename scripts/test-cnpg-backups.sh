#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Testing READ access to bucket '$CNPG_BACKUPS_BUCKET'..."

if SCW_ACCESS_KEY="$CNPG_BACKUPS_ACCESS_KEY" \
   SCW_SECRET_KEY="$CNPG_BACKUPS_SECRET_KEY" \
   scw object bucket list region="$CNPG_BACKUPS_REGION" -o human 2>&1 | grep -q "$CNPG_BACKUPS_BUCKET"; then
  echo "  OK - bucket found"
else
  echo "  FAILED - bucket '$CNPG_BACKUPS_BUCKET' not found"
  exit 1
fi
