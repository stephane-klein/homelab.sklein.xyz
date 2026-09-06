#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

REGISTRY_HOST="registry.sklein.internal"
REGISTRY_USER="${REGISTRY_USER:-stephane}"

REGISTRY_PASSWORD="$(gopass show -o "homelab/registry/${REGISTRY_USER}/password")"
if [ -z "$REGISTRY_PASSWORD" ]; then
  echo "Error: empty gopass entry homelab/registry/${REGISTRY_USER}/password" >&2
  exit 1
fi

echo "=== Repositories in ${REGISTRY_HOST} ==="
curl -fsS -u "${REGISTRY_USER}:${REGISTRY_PASSWORD}" \
  "https://${REGISTRY_HOST}/v2/_catalog" |
  jq -r '.repositories[]' | sort
