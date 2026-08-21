#!/usr/bin/env bash
set -euo pipefail

NS="crowdsec"

echo "=== Blocklist-import status ==="
echo ""

echo "--- Number of decisions imported (origin blocklist-import) ---"
kubectl -n "$NS" exec deploy/crowdsec-lapi -- cscli decisions list --origin blocklist-import | wc -l
echo ""

echo "--- CronJob blocklist-import ---"
kubectl -n "$NS" get cronjob blocklist-import
