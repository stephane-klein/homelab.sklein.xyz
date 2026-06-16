#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "=== Destroying Traefik ==="
helm uninstall traefik --namespace traefik 2>/dev/null || true
kubectl delete namespace traefik --ignore-not-found=true

echo ""
echo "=== Destroying cert-manager ==="
helm uninstall cert-manager --namespace cert-manager 2>/dev/null || true
kubectl delete clusterissuer homelab-ca --ignore-not-found=true
kubectl delete secret ca-key-pair --namespace cert-manager --ignore-not-found=true
kubectl delete namespace cert-manager --ignore-not-found=true

echo ""
echo "=== Done ==="
echo "  Traefik + cert-manager removed"
