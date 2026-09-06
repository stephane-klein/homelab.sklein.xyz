#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

REGISTRY_HOST="registry.sklein.internal"
REGISTRY_USER="${REGISTRY_USER:-stephane}"

REPO="${1:-}"
if [ -z "$REPO" ]; then
  echo "Usage: $0 <repository>  (e.g. $0 whoami)" >&2
  exit 1
fi

REGISTRY_PASSWORD="$(gopass show -o "homelab/registry/${REGISTRY_USER}/password")"
if [ -z "$REGISTRY_PASSWORD" ]; then
  echo "Error: empty gopass entry homelab/registry/${REGISTRY_USER}/password" >&2
  exit 1
fi

echo "=== Tags of ${REPO} in ${REGISTRY_HOST} ==="
tags="$(curl -fsS -u "${REGISTRY_USER}:${REGISTRY_PASSWORD}" \
  "https://${REGISTRY_HOST}/v2/${REPO}/tags/list")" || {
  echo "Error: repository '${REPO}' not found or not accessible" >&2
  exit 1
}
echo "$tags" | jq -r '.tags[]?' | sort -V
