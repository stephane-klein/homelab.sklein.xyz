#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

SECRET_FILE="../.secret"

usage() {
  echo "Usage: $0 [options] [key-type]" >&2
  echo "Options:" >&2
  echo "  --secret-file PATH   Path to secret file to update (default: ../.secret)" >&2
  echo "  --help               Show this help" >&2
  echo "" >&2
  echo "Arguments:" >&2
  echo "  key-type        one-time (default) or reusable" >&2
  exit 1
}

KEY_TYPE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --secret-file) SECRET_FILE="$2"; shift 2 ;;
    --help) usage ;;
    --*) echo "Error: Unknown option: $1" >&2; usage ;;
    *) KEY_TYPE="$1"; shift ;;
  esac
done

case "${KEY_TYPE:-one-time}" in
  one-time|reusable) ;;
  *) echo "Error: key-type must be 'one-time' or 'reusable'" >&2; usage ;;
esac

if [ ! -f "$SECRET_FILE" ]; then
  echo "Error: $SECRET_FILE not found" >&2
  exit 1
fi

set -a
source "$SECRET_FILE"
set +a

if [ -z "${NETBIRD_API_TOKEN:-}" ]; then
  echo "Error: NETBIRD_API_TOKEN is not set in $SECRET_FILE" >&2
  exit 1
fi

MACHINE_NAME="nuc-i3-gen5.homelab.stephane-klein.info"
echo "=== NetBird Setup Key Generator ==="
echo "  Machine: $MACHINE_NAME"
echo "  Key type: ${KEY_TYPE:-one-time}"
echo "  Secret file: $SECRET_FILE"
echo ""

if [ "${KEY_TYPE:-one-time}" = "one-time" ]; then
  JSON_PAYLOAD=$(cat <<EOF
{
  "name": "$MACHINE_NAME",
  "type": "one-off",
  "expires_in": 604800,
  "auto_groups": [],
  "usage_limit": 1,
  "ephemeral": false
}
EOF
)
else
  JSON_PAYLOAD=$(cat <<EOF
{
  "name": "$MACHINE_NAME",
  "type": "reusable",
  "expires_in": 604800,
  "auto_groups": [],
  "ephemeral": false
}
EOF
)
fi

echo "Calling NetBird API..."
RESPONSE=$(curl -s -X POST https://api.netbird.io/api/setup-keys \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Token $NETBIRD_API_TOKEN" \
  -d "$JSON_PAYLOAD")

SETUP_KEY=$(echo "$RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SETUP_KEY" ]; then
  echo "Error: failed to create setup key. API response:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

echo "  Key created: ${SETUP_KEY:0:8}..."

if grep -q "^NUC_I3_GEN5_NETBIRD_SETUP_KEY=" "$SECRET_FILE"; then
  sed -i "s/^NUC_I3_GEN5_NETBIRD_SETUP_KEY=.*/NUC_I3_GEN5_NETBIRD_SETUP_KEY=\"$SETUP_KEY\"/" "$SECRET_FILE"
else
  echo "NUC_I3_GEN5_NETBIRD_SETUP_KEY=\"$SETUP_KEY\"" >> "$SECRET_FILE"
fi

echo "  NUC_I3_GEN5_NETBIRD_SETUP_KEY written to: $SECRET_FILE"
