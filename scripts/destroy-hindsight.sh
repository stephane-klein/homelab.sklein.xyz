#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="hindsight"

echo "=== Destroying Hindsight ==="

helmfile -f helmfile/helmfile.yaml.gotmpl destroy --selector name=hindsight

kubectl delete secret hindsight-config -n "$NAMESPACE" --ignore-not-found > /dev/null

echo "=== Done ==="
