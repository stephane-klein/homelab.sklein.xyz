#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Cleaning local database (app) ==="
podman exec pg-dummy-local psql -U app -d postgres \
  -c "DROP DATABASE IF EXISTS app;" \
  -c "CREATE DATABASE app OWNER app;"
echo "=== Done ==="
