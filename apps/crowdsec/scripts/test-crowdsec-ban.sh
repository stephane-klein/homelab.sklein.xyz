#!/usr/bin/env bash
set -euo pipefail

NS="crowdsec"
LAPI="deploy/crowdsec-lapi"

usage() {
  cat <<'EOF'
End-to-end CrowdSec ban test (probe -> detect -> block -> cleanup).

Usage: $0 <host-or-url> [requests]

  host-or-url   Hostname or base URL to probe, e.g. example.com
                (a trailing probe path such as /.env is stripped)
  requests      Number of probes (default: 60)

Probes a set of distinct sensitive/404 paths (http-probing needs >=10 distinct
paths, http-sensitive-files >=4 distinct sensitive requests, so a single
repeated path would never trigger) with a live progress counter, waits for
CrowdSec to detect and for the stream bouncer to enforce the ban, verifies the
block (HTTP 403), then removes the decision. Needs kubectl, curl, jq.
EOF
  exit 1
}

HOST="${1:-}"
[ -n "$HOST" ] || usage
REQUESTS="${2:-60}"

case "$HOST" in
  http://*|https://*) BASE_URL="$HOST" ;;
  *) BASE_URL="https://$HOST" ;;
esac
BASE_URL="${BASE_URL%/}"
BASE_URL="${BASE_URL%.env}"
BASE_URL="${BASE_URL%/}"

# Distinct probe paths. Both scenarios use `distinct`, so the same path probed
# repeatedly never counts: http-probing needs >=10 distinct 404/403/400 paths,
# http-sensitive-files >=4 distinct sensitive requests. This list covers both.
PATHS=(
  ".env"
  ".git/HEAD"
  ".git/config"
  ".git/index"
  ".DS_Store"
  ".htaccess"
  ".env.local"
  "backup.sql"
  "config.php.bak"
  "wp-config.php"
  "phpinfo.php"
  ".aws/credentials"
  ".ssh/id_rsa"
  "server-status"
)

echo "=== CrowdSec ban test ==="
echo "  target : $BASE_URL"
echo "  probes : $REQUESTS (cycling ${#PATHS[@]} distinct paths)"

snapshot() {
  kubectl -n "$NS" exec "$LAPI" -- cscli decisions list -o json 2>/dev/null \
    | jq -r '.[].decisions[]? | select(.origin=="crowdsec") | .value' | sort -u
}
BEFORE="$(snapshot)"

echo "--- Probing (200/404 first, 403 once banned) ---"
BANNED=0
for i in $(seq 1 "$REQUESTS"); do
  path="${PATHS[$(( (i - 1) % ${#PATHS[@]} ))]}"
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE_URL/$path" || true)
  printf '  probe %02d/%s %-22s HTTP %s\r' "$i" "$REQUESTS" "$path" "$code"
  [ "$code" = "403" ] && BANNED=1
  sleep 0.3
done
printf '\n'

echo "--- Waiting for ban (scenario + stream sync, up to 3 min) ---"
DEADLINE=$(( $(date +%s) + 180 ))
while [ "$BANNED" -eq 0 ] && [ "$(date +%s)" -lt "$DEADLINE" ]; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE_URL/.env" || true)
  [ "$code" = "403" ] && BANNED=1 && break
  sleep 10
done

if [ "$BANNED" -eq 0 ]; then
  echo "  FAIL: no 403 within timeout. Recent alerts:"
  kubectl -n "$NS" exec "$LAPI" -- cscli alerts list -l 5 || true
  echo "  (check that the agent sees real client IPs and that the bouncer"
  echo "   forwardedHeadersTrustedIPs/entrypoint trustedIPs are set)"
  exit 1
fi
echo "  OK: HTTP 403 observed."

NEW_VALUES="$(comm -13 <(printf '%s\n' "$BEFORE") <(snapshot))"
echo "  decisions created by this test:"
echo "$NEW_VALUES" | sed 's/^/    /'
for v in $NEW_VALUES; do
  if echo "$v" | grep -q '/'; then
    kubectl -n "$NS" exec "$LAPI" -- cscli decisions remove --range "$v" >/dev/null 2>&1 || true
  else
    kubectl -n "$NS" exec "$LAPI" -- cscli decisions remove --ip "$v" >/dev/null 2>&1 || true
  fi
  echo "  removed decision for $v"
done
echo "=== Done ==="