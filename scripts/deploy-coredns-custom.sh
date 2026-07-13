#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Configuring CoreDNS custom override for sklein.internal ==="

echo "  Creating/updating coredns-custom ConfigMap..."
kubectl create configmap coredns-custom \
    --namespace kube-system \
    --from-file=config/coredns/ \
    --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Restarting CoreDNS..."
kubectl -n kube-system rollout restart deployment coredns > /dev/null

echo "  Waiting for CoreDNS to be ready..."
kubectl -n kube-system rollout status deployment coredns --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  auth.sklein.internal is now resolved via Traefik service DNS"
echo "  Verify with: kubectl run debug --image=busybox:1.36 --restart=Never -- nslookup auth.sklein.internal"
