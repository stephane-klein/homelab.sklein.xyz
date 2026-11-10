#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

# Read-only overview of the deployment: releases, pods, volumes, ingress, TLS,
# DNS, database and backups, application readiness (database + bucket),
# thumbnails, and the two public endpoints. It changes nothing.
#
# Exit code: 0 when the public /healthz answers 200, 1 otherwise. The other
# sections are informational, including /readyz: a database or bucket outage
# shows there but does not change the exit code.

NS="the-artifact"
CLUSTER="the-artifact-cluster"
APP_URL="https://artifact.stephane-klein.info"
CONTENT_URL="https://artifact-content.stephane-klein.info"
PUBLIC_IPV6="2001:861:8b91:6620::1000"

echo "=== The Artifact status ==="
echo

if ! kubectl get namespace "$NS" > /dev/null 2>&1; then
  echo "Namespace $NS not found: the stack is not deployed."
  echo "Run: mise run //apps/the-artifact:deploy"
  exit 1
fi

echo "--- Releases ---"
helm list -n "$NS" 2>/dev/null || echo "  namespace $NS not found (not deployed yet)"
echo

echo "--- Pods ---"
kubectl -n "$NS" get pods -o wide 2>/dev/null || true
echo

echo "--- Volumes ---"
kubectl -n "$NS" get pvc 2>/dev/null || true
echo

echo "--- Ingress ---"
kubectl -n "$NS" get ingress 2>/dev/null || true
echo

echo "--- TLS certificate ---"
kubectl -n "$NS" get certificate 2>/dev/null \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,EXPIRES:.status.notAfter' \
  || true
echo

echo "--- DNS ---"
if command -v dig > /dev/null; then
  for HOST in "${APP_URL#https://}" "${CONTENT_URL#https://}"; do
    AAAA="$(dig +short AAAA "$HOST" | head -1)"
    if [ "$AAAA" = "$PUBLIC_IPV6" ]; then
      echo "  $HOST -> $AAAA"
    else
      echo "  $HOST -> ${AAAA:-no AAAA record} (expected $PUBLIC_IPV6)"
    fi
  done
else
  echo "  (dig not installed, skipping)"
fi
echo

echo "--- Database ---"
kubectl cnpg status "$CLUSTER" -n "$NS" --color never 2>/dev/null \
  || echo "  (cannot read the cluster status: kubectl cnpg plugin absent, or cluster $CLUSTER missing)"
echo
echo "  Last backups:"
kubectl -n "$NS" get backups.postgresql.cnpg.io \
  --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -5 || true
echo

echo "--- Application readiness (database + bucket) ---"
kubectl -n "$NS" exec deploy/the-artifact -c app -- node -e '
fetch("http://127.0.0.1:3000/readyz")
  .then(async (r) => { console.log("  HTTP " + r.status + " " + (await r.text())) })
  .catch((e) => { console.error("  unreachable: " + e.message); process.exit(1) })
' 2>/dev/null || echo "  (cannot reach the application pod)"
echo

echo "--- Thumbnails (Chromium) ---"
SECCOMP="$(kubectl -n "$NS" get deploy the-artifact \
  -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}{" "}{.spec.template.spec.securityContext.seccompProfile.localhostProfile}' \
  2>/dev/null || true)"
echo "  seccomp profile: ${SECCOMP:-unknown}"
if [ "$SECCOMP" = "Localhost profiles/the-artifact-chromium.json" ]; then
  echo "  thumbnails are on, Chromium keeps its sandbox"
else
  echo "  thumbnails are off: inspect_artifact and PDF export are unavailable"
fi
kubectl -n "$NS" logs deploy/the-artifact -c app --tail=300 2>/dev/null \
  | grep -iE 'thumbnail|chromium' | tail -3 \
  || echo "  (no recent thumbnail or Chromium message)"
echo

echo "--- Public endpoints ---"
CODE="$(curl -sS -o /dev/null -m 10 -w '%{http_code}' "$APP_URL/healthz" 2>/dev/null || echo 000)"
echo "  $APP_URL/healthz -> $CODE (expected 200)"
HEALTH_CODE="$CODE"
CODE="$(curl -sS -o /dev/null -m 10 -w '%{http_code}' "$CONTENT_URL/" 2>/dev/null || echo 000)"
echo "  $CONTENT_URL/ -> $CODE (expected 404: page files only)"
echo

if [ "$HEALTH_CODE" != "200" ]; then
  echo "=== Failed: $APP_URL/healthz answered $HEALTH_CODE ==="
  exit 1
fi

echo "=== Done ==="
