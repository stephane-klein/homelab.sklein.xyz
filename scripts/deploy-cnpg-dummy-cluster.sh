#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="cnpg-demo"
CLUSTER_NAME="dummy"
BACKUP_SECRET="cnpg-backup-secret"

echo "=== Deploying CloudNativePG dummy cluster ==="

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

if [ -n "${CNPG_BACKUPS_ACCESS_KEY:-}" ] && [ -n "${CNPG_BACKUPS_SECRET_KEY:-}" ]; then
  kubectl create secret generic "$BACKUP_SECRET" \
    --namespace "$NAMESPACE" \
    --from-literal=ACCESS_KEY_ID="$CNPG_BACKUPS_ACCESS_KEY" \
    --from-literal=ACCESS_SECRET_KEY="$CNPG_BACKUPS_SECRET_KEY" \
    --dry-run=client -o yaml | kubectl apply -f - > /dev/null
  BACKUP_ENABLED=true
else
  echo "  WARNING: CNPG_BACKUPS_ACCESS_KEY not found"
  echo "  Cluster will be deployed without backup configuration"
  BACKUP_ENABLED=false
fi

echo "  Applying cluster manifest..."

apply_cluster() {
  cat <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: $CLUSTER_NAME
  namespace: $NAMESPACE
spec:
  instances: 1
  storage:
    size: 1Gi
  affinity:
    nodeSelector:
      kubernetes.io/hostname: nuc-i7-gen11.homelab.stephane-klein.info
    podAntiAffinityType: preferred
  postgresql:
    parameters:
      max_connections: "20"
EOF

  if [ "$BACKUP_ENABLED" = "true" ]; then
    cat <<EOF
  backup:
    barmanObjectStore:
      destinationPath: s3://homelab-cnpg-backups/$CLUSTER_NAME
      endpointURL: https://s3.fr-par.scw.cloud
      s3Credentials:
        accessKeyId:
          name: $BACKUP_SECRET
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: $BACKUP_SECRET
          key: ACCESS_SECRET_KEY
      wal:
        compression: gzip
      data:
        compression: gzip
    retentionPolicy: 7d
EOF
  fi
}

apply_cluster | kubectl apply -f - > /dev/null

echo "  Waiting for postgres instance to be ready..."
for i in $(seq 1 30); do
  if kubectl get pod -n "$NAMESPACE" -l cnpg.io/cluster="$CLUSTER_NAME",cnpg.io/podRole=instance -o name 2>/dev/null | grep -q .; then
    kubectl wait --for=condition=Ready pod \
      -n "$NAMESPACE" -l cnpg.io/cluster="$CLUSTER_NAME",cnpg.io/podRole=instance \
      --timeout=180s > /dev/null && break
  fi
  sleep 2
done

if [ "$BACKUP_ENABLED" = "true" ]; then
  echo "  Configuring scheduled backup..."
  cat <<EOF | kubectl apply -f - > /dev/null
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: daily
  namespace: $NAMESPACE
spec:
  schedule: "0 0 4 * * *"
  backupOwnerReference: self
  cluster:
    name: $CLUSTER_NAME
EOF
fi

echo ""
echo "=== Done ==="
echo "  Cluster $CLUSTER_NAME in namespace $NAMESPACE"
echo ""
echo "  Connect:"
echo "    kubectl port-forward -n $NAMESPACE service/${CLUSTER_NAME}-rw 5432:5432"
echo "    PGPASSWORD=\$(kubectl get secret -n $NAMESPACE ${CLUSTER_NAME}-app -o jsonpath='{.data.password}' | base64 -d)"
echo "    psql -h localhost -U app -d postgres"
if [ "$BACKUP_ENABLED" = "true" ]; then
  echo ""
  echo "  Backup:"
  echo "    Scheduled: daily at 04:00 UTC to s3://homelab-cnpg-backups/$CLUSTER_NAME"
  echo "    On-demand: kubectl cnpg backup $CLUSTER_NAME -n $NAMESPACE"
  echo "    List:       kubectl get backup -n $NAMESPACE -l cnpg.io/cluster=$CLUSTER_NAME"
fi
echo ""
echo "  Destroy: mise run destroy-cnpg-dummy-cluster"

