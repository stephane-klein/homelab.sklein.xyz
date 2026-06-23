#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying external-secrets ==="

helm repo add external-secrets https://charts.external-secrets.io --force-update > /dev/null

helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace > /dev/null

echo "  Waiting for external-secrets to be ready..."
kubectl wait --for=condition=Available deployment \
  -n external-secrets external-secrets --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  External secrets operator deployed in namespace external-secrets"
