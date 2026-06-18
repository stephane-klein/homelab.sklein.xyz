#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying VictoriaMetrics ==="

helm repo add vm https://victoriametrics.github.io/helm-charts/ --force-update > /dev/null
helm upgrade --install victoria-metrics vm/victoria-metrics-single \
  --namespace victoria-metrics --create-namespace \
  -f config/victoria-metrics/values.yaml > /dev/null

echo "  Waiting for VictoriaMetrics to be ready..."
kubectl wait --for=condition=Ready pod \
  -n victoria-metrics -l app.kubernetes.io/instance=victoria-metrics \
  --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  https://metrics.sklein.internal"
