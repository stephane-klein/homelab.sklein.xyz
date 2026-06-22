#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

DUMP_FILE="${1:-}"

if [ -z "$DUMP_FILE" ]; then
  echo "  ERROR: No dump file specified."
  echo "  Usage: $0 <dump_file>"
  echo "  Example: $0 dumps/dummydb_20260622T040000.dump"
  exit 1
fi

if [ ! -f "$DUMP_FILE" ]; then
  echo "  ERROR: File not found: $DUMP_FILE"
  exit 1
fi

echo "=== Restoring dump to local PostgreSQL (app) ==="
echo "  Dump file: $DUMP_FILE"
echo "  Size: $(du -h "$DUMP_FILE" | cut -f1)"
echo "  Target database: app"
echo "  Target user: app"
echo ""

echo "  Waiting for PostgreSQL to be ready..."
for i in $(seq 1 30); do
  if podman exec pg-dummy-local psql -U app -c "SELECT 1;" 2>/dev/null; then
    break
  fi
  sleep 1
done

echo "  Cleaning local app database..."
scripts/clean-local-db.sh

podman exec -e PGPASSWORD=app -i pg-dummy-local pg_restore -U app -h 127.0.0.1 --no-owner --role=app -d app < "$DUMP_FILE"

echo ""
echo "=== Done ==="
echo "  Dump restored to database app."
echo "  Connect with: mise enter-in-local-db"
