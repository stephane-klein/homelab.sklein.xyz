#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="perses"
DASHBOARDS_DIR="perses/dashboards"
TMPFILE="/tmp/push-perses-dashboards-expected.txt"

echo "=== Pushing dashboards to Perses ==="

for yaml_file in "$DASHBOARDS_DIR"/*.yaml; do
  name="perses-dashboard-$(basename "$yaml_file" .yaml)"
  echo "  $name"

  kubectl create configmap "$name" \
    --namespace "$NAMESPACE" \
    --from-file="$(basename "$yaml_file")=$yaml_file" \
    --dry-run=client -o yaml | kubectl apply -f - > /dev/null

  kubectl label configmap -n "$NAMESPACE" "$name" \
    perses.dev/resource="true" --overwrite > /dev/null

  echo "$name" >> "$TMPFILE"
done

if [ -f "$TMPFILE" ]; then
  existing_managed=$(kubectl get configmap -n "$NAMESPACE" -l perses.dev/resource=true -o name 2>/dev/null | grep perses-dashboard- || true)
  for cm in $existing_managed; do
    cm_name="${cm#configmap/}"
    if ! grep -qxF "$cm_name" "$TMPFILE"; then
      echo "  Removing $cm_name (no longer present in $DASHBOARDS_DIR)"
      kubectl delete configmap -n "$NAMESPACE" "$cm_name" --ignore-not-found > /dev/null
    fi
  done
  rm -f "$TMPFILE"
fi

echo ""
echo "=== Done ==="
