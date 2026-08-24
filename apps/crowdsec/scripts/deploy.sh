#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="crowdsec"
LAPI="deploy/crowdsec-lapi"
BI_KEY="homelab/crowdsec/blocklist-import/bouncer-key"
BI_PWD="homelab/crowdsec/blocklist-import/machine-password"

echo "=== Ensuring namespace $NAMESPACE ==="
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "=== Ensuring Helm post-renderer plugin (crowdsec-agent-register) ==="
if ! helm plugin list 2>/dev/null | grep -q "crowdsec-agent-register"; then
  helm plugin install helm-plugins/crowdsec-agent-register
fi

echo "=== Deploying CrowdSec (LAPI + agent) ==="
helmfile -f helmfile.yaml apply

echo "  Waiting for LAPI to be ready..."
kubectl wait --for=condition=Available deployment/crowdsec-lapi -n "$NAMESPACE" --timeout=180s > /dev/null

echo ""
echo "=== Setting up blocklist-import (external threat feeds) ==="

# One-time provisioning: a LAPI machine (writes decisions) + a bouncer (reads
# decisions), stored in gopass. On subsequent runs the credentials already exist.
# If the LAPI machine was already registered but gopass is missing (partial
# state), this self-heals instead of failing: --force re-registers the machine
# and the bouncer is re-created so its (only-once-visible) key can be stored.
if ! gopass show -o "$BI_KEY" >/dev/null 2>&1 || ! gopass show -o "$BI_PWD" >/dev/null 2>&1; then
  echo "  Registering machine + bouncer in LAPI and storing credentials in gopass..."
  BI_MACHINE_PASSWORD=$(openssl rand -hex 24)
  kubectl -n "$NAMESPACE" exec "$LAPI" -- cscli machines add blocklist-import --password "$BI_MACHINE_PASSWORD" --force
  kubectl -n "$NAMESPACE" exec "$LAPI" -- cscli bouncers delete blocklist-import 2>/dev/null || true
  BI_BOUNCER_KEY=$(kubectl -n "$NAMESPACE" exec "$LAPI" -- cscli bouncers add blocklist-import -o raw)
  printf '%s' "$BI_BOUNCER_KEY" | gopass insert -f "$BI_KEY"
  printf '%s' "$BI_MACHINE_PASSWORD" | gopass insert -f "$BI_PWD"
else
  echo "  blocklist-import credentials already present in gopass: OK"
fi

BOUNCER_KEY=$(gopass show -o "$BI_KEY")
MACHINE_PWD=$(gopass show -o "$BI_PWD")

echo "  Ensuring credentials secret..."
kubectl create secret generic blocklist-import-credentials \
  -n "$NAMESPACE" \
  --from-literal=lapi-key="$BOUNCER_KEY" \
  --from-literal=machine-password="$MACHINE_PWD" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Deploying blocklist-import CronJob (every 6h)..."
kubectl apply -f blocklist-import.yaml

echo ""
echo "=== Done ==="
echo "  CrowdSec LAPI + agent deployed in namespace $NAMESPACE"
echo "  blocklist-import CronJob deployed (external threat feeds, every 6h)"
echo ""
if gopass show -o homelab/crowdsec/bouncer-key >/dev/null 2>&1; then
  echo "  Bouncer key already present in gopass (homelab/crowdsec/bouncer-key): OK"
  echo "  You can now deploy the public Traefik with the bouncer plugin:"
  echo "    mise run deploy-traefik-public"
else
  echo "  Traefik bouncer key NOT found in gopass. Generate and store it:"
  echo "    kubectl -n $NAMESPACE exec $LAPI -- cscli bouncers add traefik-bouncer"
  echo "    # copy the returned key into gopass:"
  echo "    gopass insert homelab/crowdsec/bouncer-key"
  echo "    # then deploy the public Traefik with the bouncer plugin:"
  echo "    mise run deploy-traefik-public"
fi