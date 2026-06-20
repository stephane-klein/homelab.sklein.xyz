#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

DASHBOARDS_DIR="perses/dashboards"

for yaml_file in "$DASHBOARDS_DIR"/*.yaml; do
  name="perses-dashboard-$(basename "$yaml_file" .yaml)"
  echo "=== Deploying $name ==="

  kubectl create configmap "$name" \
    --namespace perses \
    --from-file="$(basename "$yaml_file")=$yaml_file" \
    --dry-run=client -o yaml | kubectl apply -f - > /dev/null

  kubectl label configmap -n perses "$name" \
    perses.dev/resource="true" --overwrite > /dev/null

  echo "  Done"
done

echo ""
echo "=== All custom dashboards deployed ==="
