#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="monitoring"

echo "=== Deploying kube-state-metrics ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update > /dev/null
helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics \
  --namespace "$NAMESPACE" --create-namespace > /dev/null

echo "  Waiting for kube-state-metrics to be ready..."
kubectl wait --for=condition=Available deployment \
  -n "$NAMESPACE" kube-state-metrics \
  --timeout=120s > /dev/null

echo ""
echo "=== Deploying node-exporter ==="
helm upgrade --install node-exporter prometheus-community/prometheus-node-exporter \
  --namespace "$NAMESPACE" > /dev/null

echo ""
echo "=== Deploying vmagent ==="
helm upgrade --install vmagent vm/victoria-metrics-agent \
  --namespace "$NAMESPACE" \
  --set 'remoteWrite[0].url=http://victoria-metrics-victoria-metrics-single-server.victoria-metrics.svc:8428/api/v1/write' \
  -f config/exporters/values.yaml > /dev/null

echo "  Waiting for vmagent to be ready..."
kubectl wait --for=condition=Available deployment \
  -n "$NAMESPACE" vmagent-victoria-metrics-agent \
  --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  kube-state-metrics, node-exporter, vmagent deployed"
