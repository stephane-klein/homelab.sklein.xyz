#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying external-dns ==="

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN is not set" >&2
  echo "Load it via mise: mise x -- $0" >&2
  exit 1
fi

echo "  Creating external-dns namespace..."
kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Applying manifest..."
kubectl apply -f config/external-dns/manifest.yaml > /dev/null

echo "  Injecting Cloudflare API token into secret..."
kubectl create secret generic cloudflare-api-token \
  --namespace external-dns \
  --from-literal=CF_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Waiting for external-dns to be ready..."
kubectl wait --for=condition=Available deployment \
  -n external-dns external-dns --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  external-dns deployed — creating AAAA records for hosts under stephane-klein.info"
