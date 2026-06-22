#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Creating dummydb if not exists ==="
kubectl cnpg psql dummy -n cnpg-demo -- -d postgres -c "CREATE DATABASE dummydb;" 2>/dev/null || \
  echo "  dummydb already exists"

echo "=== Importing schema ==="
kubectl cnpg psql dummy -n cnpg-demo -- -d dummydb < dummy-database/schema.sql

echo "=== Importing fixtures ==="
kubectl cnpg psql dummy -n cnpg-demo -- -d dummydb < dummy-database/data-fixtures.sql

echo "=== Done ==="
