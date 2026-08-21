#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="crowdsec"

echo "=== Destroying blocklist-import (CronJob/ConfigMap/Secret) ==="
kubectl delete cronjob blocklist-import -n "$NAMESPACE" --ignore-not-found=true
kubectl delete configmap blocklist-import-config -n "$NAMESPACE" --ignore-not-found=true
kubectl delete secret blocklist-import-credentials -n "$NAMESPACE" --ignore-not-found=true

echo "=== Destroying CrowdSec ==="
helmfile -f helmfile.yaml destroy

echo "=== Done ==="
echo "  CrowdSec removed. Note: this wipes LAPI decisions and the bouncer key."