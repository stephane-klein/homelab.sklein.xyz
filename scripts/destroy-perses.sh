#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="perses"

helm uninstall perses-operator --namespace "$NAMESPACE" --ignore-not-found > /dev/null
helm uninstall perses --namespace "$NAMESPACE" --ignore-not-found > /dev/null
kubectl delete persistentvolumeclaim -n "$NAMESPACE" -l app.kubernetes.io/instance=perses --ignore-not-found > /dev/null
kubectl delete crd --ignore-not-found \
  perses.perses.dev \
  persesdashboard.perses.dev \
  persesdatasource.perses.dev \
  persesglobaldatasource.perses.dev > /dev/null 2>&1 || true
kubectl delete namespace "$NAMESPACE" --ignore-not-found > /dev/null

echo "=== Perses destroyed ==="
