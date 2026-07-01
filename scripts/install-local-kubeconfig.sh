#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Restoring kubeconfig from Gopass ==="
gopass show homelab/k3s.kubeconfig > k3s.kubeconfig
echo "  k3s.kubeconfig restored from Gopass (homelab/k3s.kubeconfig)"
