#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP=$(date +%s)
JOB_NAME="hindsight-logical-backup-manual-${TIMESTAMP}"

echo "=== Triggering immediate Hindsight logical backup ==="
kubectl create job --from=cronjob/hindsight-logical-backup \
  -n hindsight "${JOB_NAME}"

echo ""
echo "  Job created: ${JOB_NAME}"
echo "  Watch: kubectl get jobs -n hindsight -w | grep hindsight-logical"
echo "  List:  mise run list-hindsight-backups"
