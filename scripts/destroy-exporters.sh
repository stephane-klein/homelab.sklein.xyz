#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="monitoring"

helm uninstall vmagent --namespace "$NAMESPACE" --ignore-not-found > /dev/null
helm uninstall node-exporter --namespace "$NAMESPACE" --ignore-not-found > /dev/null
helm uninstall kube-state-metrics --namespace "$NAMESPACE" --ignore-not-found > /dev/null
kubectl delete namespace "$NAMESPACE" --ignore-not-found > /dev/null

echo "=== Exporters destroyed ==="
