#!/usr/bin/env bash
set -euo pipefail

echo "=== Triggering immediate backup for forgejo-cluster ==="

kubectl cnpg backup forgejo-cluster -n forgejo

echo ""
echo "  Watch: kubectl get backup -n forgejo -w"
