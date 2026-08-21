#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="crowdsec"
JOB="blocklist-import-manual"

echo "=== Forcing blocklist-import run ==="

# Rejouer proprement : on supprime un éventuel job manuel précédent (nom fixe).
kubectl -n "$NAMESPACE" delete job "$JOB" --ignore-not-found=true >/dev/null

echo "  Creating ad-hoc job $JOB from cronjob/blocklist-import..."
kubectl -n "$NAMESPACE" create job --from=cronjob/blocklist-import "$JOB"

echo "  Waiting for completion (max 5 min)..."
if kubectl -n "$NAMESPACE" wait --for=condition=complete "job/$JOB" --timeout=300s; then
  echo ""
  echo "  === Sources imported (job logs) ==="
  kubectl -n "$NAMESPACE" logs "job/$JOB"
else
  echo ""
  echo "  === Job FAILED — logs ==="
  kubectl -n "$NAMESPACE" logs "job/$JOB" --tail=50 || true
  kubectl -n "$NAMESPACE" describe "job/$JOB" | tail -30
  exit 1
fi