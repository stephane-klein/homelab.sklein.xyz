#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

DUMP_FILE="/tmp/dummy-db.dump"

echo "=== Dumping dummydb database from CNPG cluster ==="
kubectl exec dummy-1 -c postgres -n cnpg-demo -- pg_dump -Fc -d dummydb > "$DUMP_FILE"

echo "=== Cleaning local app database ==="
scripts/clean-local-db.sh

echo "=== Restoring to local Podman PostgreSQL ==="
podman exec -i pg-dummy-local pg_restore -U app --no-owner --role=app -d app < "$DUMP_FILE"

echo "=== Cleaning up ==="
rm -f "$DUMP_FILE"

echo "=== Done ==="
