#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

NAMESPACE="victoria-metrics"

helm uninstall victoria-metrics --namespace "$NAMESPACE" --ignore-not-found > /dev/null
kubectl delete persistentvolumeclaim -n "$NAMESPACE" -l app.kubernetes.io/instance=victoria-metrics --ignore-not-found > /dev/null
kubectl delete namespace "$NAMESPACE" --ignore-not-found > /dev/null

echo "=== VictoriaMetrics destroyed ==="
