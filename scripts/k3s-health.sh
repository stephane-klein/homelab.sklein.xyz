#!/usr/bin/env bash
set -euo pipefail

echo "=== k3s Cluster Health Check ==="
echo ""

echo "--- Nodes ---"
kubectl get nodes -o wide
echo ""

echo "--- Control-plane components ---"
kubectl get cs 2>/dev/null || echo "  componentstatuses not available (deprecated in newer k8s)"
echo ""

echo "--- All pods ---"
kubectl get pods -A
echo ""

echo "--- Recent events (last 20) ---"
kubectl get events -A --sort-by='.lastTimestamp' 2>/dev/null | tail -20 || true
echo ""

echo "--- Resource usage ---"
if kubectl top nodes > /dev/null 2>&1; then
  kubectl top nodes
else
  echo "  metrics-server not ready yet"
fi
echo ""

echo "=== Done ==="
