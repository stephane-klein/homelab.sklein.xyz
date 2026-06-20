#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="cnpg-system"

echo "=== Destroying CloudNativePG Operator ==="

helm uninstall cnpg --namespace "$NAMESPACE" --ignore-not-found > /dev/null
kubectl delete namespace "$NAMESPACE" --ignore-not-found > /dev/null

echo ""
echo "=== Done ==="
echo "  CloudNativePG operator removed"

