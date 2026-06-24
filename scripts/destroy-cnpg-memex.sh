#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Destroying CNPG cluster: memex ==="

helmfile -f helmfile/helmfile.yaml.gotmpl destroy --selector name=memex

echo "=== Done ==="
