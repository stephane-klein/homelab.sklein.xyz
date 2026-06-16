#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SECRET_FILE=".secret"

if [ -f "$SECRET_FILE" ]; then
  set -a
  source "$SECRET_FILE"
  set +a
fi

TOKEN="${NB_PAT:-${NETBIRD_API_TOKEN:-}}"

if [ -z "$TOKEN" ]; then
  echo "Error: NB_PAT or NETBIRD_API_TOKEN is not set" >&2
  echo "Set it in .secret or export it as an environment variable." >&2
  exit 1
fi

API_BASE="https://api.netbird.io/api"

echo "=== Netbird Groups ==="
curl -sf "$API_BASE/groups" \
  -H "Authorization: Token $TOKEN" \
  | jq -r '.[] | "  \(.id)  \(.name)"' || echo "  (none or error)"

echo ""
echo "=== Netbird Peers ==="
curl -sf "$API_BASE/peers" \
  -H "Authorization: Token $TOKEN" \
  | jq -r '.[] | "  \(.id)  \(.name)  \(.ip)"' || echo "  (none or error)"

echo ""
echo "=== Netbird Policies ==="
curl -sf "$API_BASE/policies" \
  -H "Authorization: Token $TOKEN" \
  | jq -r '.[] | "  \(.id)  \(.name)"' || echo "  (none or error)"
