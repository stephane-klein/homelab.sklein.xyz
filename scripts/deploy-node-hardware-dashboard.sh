#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PERSES_URL="https://perses.sklein.internal"
DASHBOARD_FILE="../perses/dashboards/node-hardware.yaml"
API_PATH="/api/v1/projects/perses-dev/dashboards/node-hardware"

echo "=== Deploying Node Hardware Dashboard ==="

PAYLOAD=$(python3 -c "
import json, yaml
with open('$DASHBOARD_FILE') as f:
    print(json.dumps(yaml.safe_load(f)))
")

echo "  Creating or updating dashboard..."

HTTP_CODE=$(curl -sk -o /dev/null -w '%{http_code}' \
  -X PUT "$PERSES_URL$API_PATH" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo "  Done (HTTP $HTTP_CODE)"
else
  # Create if not exists (POST expects no existing resource)
  echo "  Creating new dashboard..."
  curl -sk -X POST "$PERSES_URL/api/v1/projects/perses-dev/dashboards" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" > /dev/null
  echo "  Done (created)"
fi

echo ""
echo "  https://perses.sklein.internal/projects/perses-dev/dashboards/node-hardware"
