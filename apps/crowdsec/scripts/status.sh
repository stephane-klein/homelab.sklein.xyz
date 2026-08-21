#!/usr/bin/env bash
set -euo pipefail

NS="crowdsec"
LAPI="deploy/crowdsec-lapi"

echo "=== CrowdSec status ==="
echo ""

echo "--- Bouncers ---"
kubectl -n "$NS" exec "$LAPI" -- cscli bouncers list
echo ""

echo "--- Active decisions ---"
kubectl -n "$NS" exec "$LAPI" -- cscli decisions list
echo ""

echo "--- Recent alerts ---"
kubectl -n "$NS" exec "$LAPI" -- cscli alerts list -l 5
echo ""

echo "--- LAPI / bouncer metrics (stream pulls) ---"
kubectl -n "$NS" exec "$LAPI" -- cscli metrics
echo ""

echo "--- Agent acquisition (traefik logs ingested) ---"
# Pick the agent running on the same node as traefik-public (ingress node),
# which is the one reading the traefik access logs.
PUB_POD=$(kubectl get pods -n traefik \
  -l app.kubernetes.io/instance=traefik-public-traefik \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
PUB_NODE=$(kubectl get pod -n traefik "$PUB_POD" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)
AGENT=""
if [ -n "$PUB_NODE" ]; then
  for p in $(kubectl get pods -n "$NS" -l type=agent \
      --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
    n=$(kubectl get pod -n "$NS" "$p" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)
    if [ "$n" = "$PUB_NODE" ]; then AGENT="$p"; break; fi
  done
fi
if [ -n "$AGENT" ]; then
  kubectl -n "$NS" exec "$AGENT" -- cscli metrics | grep -iE "acquisition|traefik" | head -15
else
  echo "  (no agent found on the traefik-public node)"
fi
echo ""

echo "=== Done ==="