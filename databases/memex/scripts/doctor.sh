#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="memex"
CLUSTER="memex-cluster"
READER_ROLE="toggl_mcp_reader"
READER_SECRET="toggl-mcp-reader"
READER_DB="app"
READER_TABLE="toggl.time_entries"
APP_SECRET_NAMESPACE="toggl-pg-mirror"
APP_SECRET="toggl-pg-mirror"
APP_SECRET_KEY="mcp-reader-postgres-password"

failures=0

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

echo "=== Role declared in cluster spec ==="
if kubectl get cluster "$CLUSTER" -n "$NAMESPACE" -o jsonpath='{.spec.managed.roles[*].name}' | tr ' ' '\n' | grep -qx "$READER_ROLE"; then
  pass "$READER_ROLE declared in spec.managed.roles"
else
  fail "$READER_ROLE not declared in spec.managed.roles"
fi

echo "=== Reader secret keys ==="
SECRET_KEYS=$(kubectl get secret "$READER_SECRET" -n "$NAMESPACE" -o jsonpath='{.data}' | python3 -c "import json,sys; print(' '.join(sorted(json.load(sys.stdin).keys())))" 2>/dev/null || echo "")
if [[ "$SECRET_KEYS" == *"username"* && "$SECRET_KEYS" == *"password"* ]]; then
  pass "$READER_SECRET has username and password keys"
else
  fail "$READER_SECRET missing keys, got: ${SECRET_KEYS:-<unreadable>}"
fi

echo "=== Password sync between reader secret and app secret ==="
READER_PASSWORD=$(kubectl get secret "$READER_SECRET" -n "$NAMESPACE" -o jsonpath='{.data.password}' 2>/dev/null || echo "")
APP_PASSWORD=$(kubectl get secret "$APP_SECRET" -n "$APP_SECRET_NAMESPACE" -o jsonpath="{.data.$APP_SECRET_KEY}" 2>/dev/null || echo "")
if [[ -n "$READER_PASSWORD" && "$READER_PASSWORD" == "$APP_PASSWORD" ]]; then
  pass "passwords match between $READER_SECRET and $APP_SECRET.$APP_SECRET_KEY"
else
  fail "passwords differ or unreadable ($READER_SECRET vs $APP_SECRET.$APP_SECRET_KEY)"
fi

echo "=== Role exists in PostgreSQL ==="
POD=$(kubectl get pod -n "$NAMESPACE" \
  -l "cnpg.io/cluster=$CLUSTER,cnpg.io/podRole=instance" \
  -o jsonpath='{.items[0].metadata.name}')
ROLE_LINE=$(kubectl exec -n "$NAMESPACE" "$POD" -- \
  env PGPASSWORD="$(kubectl get secret "$CLUSTER-app" -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)" \
  psql -h localhost -U memex -d "$READER_DB" -tAc \
  "SELECT rolcanlogin FROM pg_roles WHERE rolname='$READER_ROLE';" 2>/dev/null || echo "")
if [[ "$ROLE_LINE" == "t" ]]; then
  pass "$READER_ROLE exists in PostgreSQL with login"
else
  fail "$READER_ROLE missing or no login in PostgreSQL (got: ${ROLE_LINE:-<error>})"
fi

echo "=== Authentication with reader secret password ==="
AUTH_USER=$(kubectl exec -n "$NAMESPACE" "$POD" -- \
  env PGPASSWORD="$(kubectl get secret "$READER_SECRET" -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)" \
  psql -h localhost -U "$READER_ROLE" -d "$READER_DB" -tAc "SELECT current_user;" 2>/dev/null || echo "")
if [[ "$AUTH_USER" == "$READER_ROLE" ]]; then
  pass "authentication as $READER_ROLE with secret password"
else
  fail "authentication as $READER_ROLE failed (got: ${AUTH_USER:-<error>})"
fi

echo "=== Grants on toggl schema ==="
SCHEMA_USAGE=$(kubectl exec -n "$NAMESPACE" "$POD" -- \
  env PGPASSWORD="$(kubectl get secret "$CLUSTER-app" -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)" \
  psql -h localhost -U memex -d "$READER_DB" -tAc \
  "SELECT has_schema_privilege('$READER_ROLE', 'toggl', 'USAGE');" 2>/dev/null || echo "")
if [[ "$SCHEMA_USAGE" == "t" ]]; then
  pass "USAGE on schema toggl for $READER_ROLE"
else
  fail "no USAGE on schema toggl for $READER_ROLE (got: ${SCHEMA_USAGE:-<error>})"
fi

TABLE_SELECT=$(kubectl exec -n "$NAMESPACE" "$POD" -- \
  env PGPASSWORD="$(kubectl get secret "$CLUSTER-app" -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)" \
  psql -h localhost -U memex -d "$READER_DB" -tAc \
  "SELECT has_table_privilege('$READER_ROLE', '$READER_TABLE', 'SELECT');" 2>/dev/null || echo "")
if [[ "$TABLE_SELECT" == "t" ]]; then
  pass "SELECT on $READER_TABLE for $READER_ROLE"
else
  fail "no SELECT on $READER_TABLE for $READER_ROLE (got: ${TABLE_SELECT:-<error>})"
fi

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "All checks passed"
else
  echo "$failures check(s) failed"
fi
exit "$failures"