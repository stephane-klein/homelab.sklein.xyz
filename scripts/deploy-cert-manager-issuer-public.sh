#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying Let's Encrypt public ClusterIssuer ==="

echo "  Reading Cloudflare API token from gopass (homelab/cloudflare/stephane-klein.info/api-token)..."
CLOUDFLARE_API_TOKEN=$(gopass show -o homelab/cloudflare/stephane-klein.info/api-token)
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  echo "Error: gopass secret homelab/cloudflare/stephane-klein.info/api-token is empty" >&2
  exit 1
fi

echo "  Creating Cloudflare API token secret..."
kubectl create secret generic cloudflare-api-token \
  --namespace cert-manager \
  --from-literal=api-token="$CLOUDFLARE_API_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Applying ClusterIssuer..."
kubectl apply -f config/cert-manager/letsencrypt-public-issuer.yaml > /dev/null

echo "  Waiting for ClusterIssuer to be ready..."
kubectl wait --for=condition=Ready clusterissuer letsencrypt-public --timeout=60s > /dev/null 2>&1 || true

echo ""
echo "=== Done ==="
echo "  ClusterIssuer letsencrypt-public deployed"
