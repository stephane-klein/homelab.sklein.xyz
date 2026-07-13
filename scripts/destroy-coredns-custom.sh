#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Removing CoreDNS custom override ==="

echo "  Deleting coredns-custom ConfigMap..."
kubectl delete configmap coredns-custom --namespace kube-system --ignore-not-found > /dev/null

echo "  Restarting CoreDNS..."
kubectl -n kube-system rollout restart deployment coredns > /dev/null

echo "  Waiting for CoreDNS to be ready..."
kubectl -n kube-system rollout status deployment coredns --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  CoreDNS custom override removed"
