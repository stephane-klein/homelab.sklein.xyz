#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

EMAIL="${1:-}"

if [ -z "$EMAIL" ]; then
  echo "Usage: $0 <email>" >&2
  exit 1
fi

echo "=== Making $EMAIL an instance admin ==="
kubectl -n the-artifact exec deploy/the-artifact -c app -- \
  node dist/scripts/make-admin.js "$EMAIL"
