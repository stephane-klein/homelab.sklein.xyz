#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="grafana"

echo "=== Loading Grafana admin password ==="
GRAFANA_ADMIN_PASSWORD=$(grep '^GRAFANA_ADMIN_PASSWORD=' ".secret" | cut -d'"' -f2)

if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
  echo "ERROR: GRAFANA_ADMIN_PASSWORD not found in .secret"
  exit 1
fi

echo "=== Ensuring namespace ==="
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "=== Creating grafana-admin secret ==="
kubectl create secret generic grafana-admin \
  -n "$NAMESPACE" \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="${GRAFANA_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "=== Deploying Grafana ==="
helmfile -f helmfile/helmfile.yaml.gotmpl apply

echo "  Waiting for Grafana to be ready..."
kubectl rollout status deployment grafana \
  -n "$NAMESPACE" --timeout=180s > /dev/null

echo ""
echo "=== Configuring admin profile ==="
./scripts/configure-grafana-admin.sh

echo ""
echo "=== Done ==="
echo "  https://grafana.sklein.internal"
