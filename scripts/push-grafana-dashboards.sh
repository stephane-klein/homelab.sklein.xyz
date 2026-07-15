#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="grafana"
DASHBOARDS_DIR="grafana/dashboards"
LABEL="grafana_dashboard=1"
TMPFILE="/tmp/push-grafana-dashboards-expected.txt"

echo "=== Pushing dashboards to Grafana ==="

for json_file in "$DASHBOARDS_DIR"/*.json; do
  name="grafana-dashboard-$(basename "$json_file" .json)"
  echo "  $name"

  kubectl create configmap "$name" \
    --namespace "$NAMESPACE" \
    --from-file="$(basename "$json_file")=$json_file" \
    --dry-run=client -o yaml | kubectl apply -f - > /dev/null

  kubectl label configmap -n "$NAMESPACE" "$name" \
    grafana_dashboard="1" --overwrite > /dev/null

  echo "$name" >> "$TMPFILE"
done

if [ -f "$TMPFILE" ]; then
  existing_managed=$(kubectl get configmap -n "$NAMESPACE" -l grafana_dashboard=1 -o name 2>/dev/null | grep grafana-dashboard- || true)
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
