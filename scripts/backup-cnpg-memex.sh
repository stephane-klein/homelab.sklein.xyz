#!/usr/bin/env bash
set -euo pipefail

echo "=== Triggering immediate backup for memex-cluster ==="

kubectl cnpg backup memex-cluster -n memex

echo ""
echo "  Watch: kubectl get backup -n memex -w"
