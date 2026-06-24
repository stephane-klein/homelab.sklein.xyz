#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Destroying CNPG cluster: hindsight ==="

helmfile -f helmfile/helmfile.yaml.gotmpl destroy

echo "=== Done ==="
