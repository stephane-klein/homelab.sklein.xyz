#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

CLUSTER_NAME="dummy"
ENDPOINT="https://s3.${CNPG_BACKUPS_REGION:-fr-par}.scw.cloud"
S3_URL="s3://${CNPG_BACKUPS_BUCKET}/${CLUSTER_NAME}"

echo "=== Delete ALL S3 objects for $CLUSTER_NAME ==="
echo "  S3 URL: $S3_URL"
echo "  Endpoint: $ENDPOINT"
echo ""
echo "  WARNING: This will permanently delete ALL backups (base + WAL)"
echo "           for cluster '$CLUSTER_NAME' from Scaleway Object Storage."
echo ""

read -rp "  Are you sure? Type 'yes' to confirm: " confirm
if [ "$confirm" != "yes" ]; then
  echo "  Aborted."
  exit 0
fi

echo ""
echo "  Deleting all objects under $S3_URL ..."

AWS_ACCESS_KEY_ID="$CNPG_BACKUPS_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$CNPG_BACKUPS_SECRET_KEY" \
  aws s3 rm "$S3_URL/" --recursive \
    --endpoint-url "$ENDPOINT"

echo ""
echo "=== Done ==="
echo "  All objects deleted under $S3_URL"
