#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="cnpg-demo"
CLUSTER_NAME="dummy"
ENDPOINT="https://s3.${CNPG_BACKUPS_REGION:-fr-par}.scw.cloud"
S3_URL="s3://${CNPG_BACKUPS_BUCKET}/${CLUSTER_NAME}"

CNPG_IMAGE="ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie"

echo "=== Barman backups for $CLUSTER_NAME ==="
echo ""

podman run --rm \
  -e AWS_ACCESS_KEY_ID="$CNPG_BACKUPS_ACCESS_KEY" \
  -e AWS_SECRET_ACCESS_KEY="$CNPG_BACKUPS_SECRET_KEY" \
  -e AWS_ENDPOINT_URL="$ENDPOINT" \
  "$CNPG_IMAGE" \
  barman-cloud-backup-list --format json \
    --endpoint-url "$ENDPOINT" \
    "$S3_URL" \
    "$CLUSTER_NAME" 2>&1 | python3 -c "
import sys, json
data = json.load(sys.stdin)
backups = data.get('backups_list', [])
if not backups:
    print('  No backups found.')
    sys.exit(0)
print(f'  {len(backups)} backup(s) available:')
print()
for b in reversed(backups):
    bid = b['backup_id']
    et = b.get('end_time_iso', b.get('end_time', '?'))
    wal = b.get('begin_wal', '?')
    status = b.get('status', '?')
    print(f'    {bid}  {et}  [{status}]')
"
