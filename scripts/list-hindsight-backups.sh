#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

NAMESPACE="hindsight"
BUCKET="${CNPG_BACKUPS_BUCKET:-homelab-cnpg-backups}"
REGION="${CNPG_BACKUPS_REGION:-fr-par}"
ENDPOINT="https://s3.${REGION}.scw.cloud"
PREFIX="hindsight-logical"

if [ -z "${CNPG_BACKUPS_ACCESS_KEY:-}" ] || [ -z "${CNPG_BACKUPS_SECRET_KEY:-}" ]; then
  echo "  CNPG_BACKUPS_ACCESS_KEY or CNPG_BACKUPS_SECRET_KEY not set"
  echo "  Source .secret first: source <(grep '^CNPG_BACKUPS_' .secret)"
  exit 1
fi

echo "=== Recent backup jobs ==="
echo ""

JOBS=$(kubectl get jobs -n "$NAMESPACE" -o wide 2>/dev/null \
  | grep hindsight-logical-backup \
  | awk '{ printf "  %s  %s  %s\n", $1, $2, $3 }' \
) || true

if [ -z "$JOBS" ]; then
  echo "  No backup jobs found."
else
  echo "$JOBS"
fi

echo ""
echo "=== Backup files on S3 ($BUCKET/$PREFIX) ==="
echo ""

AWS_ACCESS_KEY_ID="$CNPG_BACKUPS_ACCESS_KEY" \
  AWS_SECRET_ACCESS_KEY="$CNPG_BACKUPS_SECRET_KEY" \
  aws s3 ls "s3://${BUCKET}/${PREFIX}/" \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" 2>&1 \
  | python3 -c "
import sys

lines = [l.strip() for l in sys.stdin if l.strip()]
if not lines:
    print('  No backups found.')
    sys.exit(0)

for line in lines:
    parts = line.split()
    if len(parts) < 4:
        continue
    date, time, size_str, *name = parts
    size = int(size_str)
    if size < 1024:
        human = f'{size} B'
    elif size < 1024**2:
        human = f'{size/1024:.1f} KiB'
    elif size < 1024**3:
        human = f'{size/1024**2:.1f} MiB'
    else:
        human = f'{size/1024**3:.1f} GiB'
    print(f'  {date} {time}  {human:>10}  {\" \".join(name)}')
" || echo "  Bucket $BUCKET not accessible."
