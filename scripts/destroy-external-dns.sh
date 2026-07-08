#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Destroying external-dns ==="

kubectl delete deployment external-dns -n external-dns --ignore-not-found=true > /dev/null
kubectl delete namespace external-dns --ignore-not-found=true > /dev/null
kubectl delete clusterrolebinding external-dns-viewer --ignore-not-found=true > /dev/null
kubectl delete clusterrole external-dns --ignore-not-found=true > /dev/null

echo ""
echo "=== Done ==="
echo "  external-dns removed"
