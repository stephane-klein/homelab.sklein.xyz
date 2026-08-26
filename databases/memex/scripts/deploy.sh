#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="memex"

echo "=== Ensuring namespace ==="
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "=== Creating toggl_mcp_reader password secret ==="
kubectl create secret generic toggl-mcp-reader \
  -n "$NAMESPACE" \
  --from-literal=password="$(gopass show -o toggl.sklein.internal/mcp-reader-postgres-password)" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "=== Deploying CNPG cluster: memex ==="
helmfile -f helmfile.yaml apply

echo "=== Creating S3 backup credentials secret ==="
kubectl create secret generic memex-cluster-backup-s3-creds \
  -n "$NAMESPACE" \
  --from-literal=ACCESS_KEY_ID="$(gopass show -o homelab/scaleway/CNPG_BACKUPS_ACCESS_KEY)" \
  --from-literal=ACCESS_SECRET_KEY="$(gopass show -o homelab/scaleway/CNPG_BACKUPS_SECRET_KEY)" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "=== Done ==="
echo "  Password: kubectl get secret memex-cluster-memex -n memex -o jsonpath='{.data.password}' | base64 -d"
echo "  Connect:  kubectl cnpg psql memex-cluster -n memex"