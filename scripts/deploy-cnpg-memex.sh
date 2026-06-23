#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying CNPG cluster: memex ==="

helmfile -f helmfile/helmfile.yaml.gotmpl apply

echo "=== Done ==="
echo "  Password: kubectl get secret memex-cluster-memex -n memex -o jsonpath='{.data.password}' | base64 -d"
echo "  Connect:  kubectl cnpg psql memex-cluster -n memex"
