#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="crowdsec"
LAPI="deploy/crowdsec-lapi"
EXP_PWD="homelab/crowdsec/alerts-exporter/machine-password"

echo "=== Ensuring LAPI machine crowdsec-exporter ==="
if ! gopass show -o "$EXP_PWD" >/dev/null 2>&1; then
  echo "  Registering machine and storing credentials in gopass..."
  EXP_MACHINE_PASSWORD=$(openssl rand -hex 24)
  kubectl -n "$NAMESPACE" exec "$LAPI" -- cscli machines add crowdsec-exporter --password "$EXP_MACHINE_PASSWORD" --force
  printf '%s' "$EXP_MACHINE_PASSWORD" | gopass insert -f "$EXP_PWD"
else
  echo "  crowdsec-exporter credentials already present in gopass: OK"
fi

MACHINE_PWD=$(gopass show -o "$EXP_PWD")

echo "  Ensuring credentials secret..."
kubectl create secret generic crowdsec-exporter-credentials \
  -n "$NAMESPACE" \
  --from-literal=machine-id=crowdsec-exporter \
  --from-literal=machine-password="$MACHINE_PWD" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Deploying alerts exporter..."
kubectl apply -f alerts-exporter.yaml
kubectl -n "$NAMESPACE" rollout status deployment/crowdsec-alerts-exporter --timeout=180s > /dev/null

echo ""
echo "=== Done ==="
echo "  Exporter: crowdsec-alerts-exporter.crowdsec.svc:9300/metrics (scraped by vmagent)"
echo "  Grafana dashboard: 'CrowdSec blocked IPs'"