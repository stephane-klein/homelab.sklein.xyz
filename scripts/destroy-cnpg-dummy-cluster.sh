#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="cnpg-demo"

echo "=== Destroying CloudNativePG dummy cluster ==="

kubectl delete namespace "$NAMESPACE" --ignore-not-found > /dev/null

echo ""
echo "=== Done ==="
echo "  Cluster removed (namespace $NAMESPACE deleted)"

