#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Destroying Authelia ==="

echo "  Uninstalling Helm release..."
helm uninstall authelia --namespace authelia --ignore-not-found --wait --delete-pvcs > /dev/null 2>&1 || true

echo "  Deleting Traefik Middleware..."
kubectl delete middleware forwardauth-authelia --namespace traefik --ignore-not-found > /dev/null

echo "  Deleting users ConfigMap..."
kubectl delete configmap authelia-users --namespace authelia --ignore-not-found > /dev/null

echo ""
echo "=== Authelia destroyed ==="
echo "  Namespace 'authelia' was kept (delete manually with: kubectl delete namespace authelia)")
