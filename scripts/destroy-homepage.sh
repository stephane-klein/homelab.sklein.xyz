#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="homepage"

helm uninstall homepage --namespace "$NAMESPACE" --ignore-not-found > /dev/null
kubectl delete namespace "$NAMESPACE" --ignore-not-found > /dev/null

echo "=== Homepage destroyed ==="
