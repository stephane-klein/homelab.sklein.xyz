#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="perses"
PROJECT="homelab"
LOCAL_PORT=8080
DASHBOARDS_DIR="perses/dashboards"

cleanup() {
  kill "$PF_PID" 2>/dev/null || true
  wait "$PF_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Pulling dashboards from Perses ==="

kubectl port-forward -n "$NAMESPACE" svc/perses "$LOCAL_PORT:8080" &>/dev/null &
PF_PID=$!
sleep 2

if ! kill -0 "$PF_PID" 2>/dev/null; then
  echo "ERROR: port-forward failed to start"
  exit 1
fi

dashboards=$(curl -s "http://localhost:$LOCAL_PORT/api/v1/projects/$PROJECT/dashboards")
if [ -z "$dashboards" ] || echo "$dashboards" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  true
else
  echo "ERROR: failed to list dashboards. Is Perses running?"
  exit 1
fi

names=$(echo "$dashboards" | python3 -c "
import json, sys
for d in json.load(sys.stdin):
    print(d['metadata']['name'])
")

for name in $names; do
  echo "  $name"
  curl -s "http://localhost:$LOCAL_PORT/api/v1/projects/$PROJECT/dashboards/$name" \
    | python3 -c "
import json, sys, yaml
data = json.load(sys.stdin)
print(yaml.dump(data, sort_keys=False))
" > "$DASHBOARDS_DIR/$name.yaml"
  yamlfmt "$DASHBOARDS_DIR/$name.yaml"
done

echo ""
echo "=== Done ==="
