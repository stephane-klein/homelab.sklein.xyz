#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP=$(date +%s)
JOB_NAME="forgejo-data-backup-manual-${TIMESTAMP}"

echo "=== Triggering manual Forgejo data backup (PVC -> S3) ==="
kubectl create job --from=cronjob/forgejo-data-backup \
  -n forgejo "${JOB_NAME}"

echo ""
echo "  Job created: ${JOB_NAME}"
echo "  Watch: kubectl get jobs -n forgejo -w | grep forgejo-data"
echo "  Logs:  kubectl logs job/${JOB_NAME} -n forgejo -c s3-upload"
