#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="searxng"

echo "=== Deploying SearXNG ==="

echo "  Ensuring namespace and secret from Gopass..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl create secret generic searxng-secret \
  -n "$NAMESPACE" \
  --from-literal=secret-key="$(gopass show -o homelab/searxng/secret-key)" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Applying Helmfile..."
helmfile -f helmfile.yaml apply

echo ""
echo "=== Done ==="
echo "  UI:  https://searxng.sklein.internal"
echo "  API: https://searxng.sklein.internal/search?q=homelab&format=json"
