#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying CNPG cluster: hindsight ==="

helmfile -f helmfile/helmfile.yaml.gotmpl apply

echo "=== Done ==="
echo "  Password: kubectl get secret hindsight-cnpg-cluster-app -n hindsight -o jsonpath='{.data.password}' | base64 -d"
echo "  Connect:  kubectl cnpg psql hindsight-cnpg-cluster -n hindsight"
