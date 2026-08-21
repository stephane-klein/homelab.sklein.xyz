#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

SERVER="${SERVER:-nuc-i7-gen11.homelab.stephane-klein.info}"
SSH_USER="${SSH_USER:-stephane}"

echo "=== Deploying public Traefik on IPv6 ==="
echo "  Detecting static IPv6 address on $SERVER..."
PUBLIC_IPV6=$(ssh "$SSH_USER@$SERVER" \
  'ip -6 addr show dev enp89s0 | grep "::1000" | grep -oP "inet6 \K[0-9a-f:]+" | cut -d/ -f1')

if [ -z "$PUBLIC_IPV6" ]; then
  echo "Error: Could not detect IPv6 ::1000 on $SERVER" >&2
  echo "Run 'mise run assign-static-ipv6' first" >&2
  exit 1
fi
export PUBLIC_IPV6

echo "  Reading CrowdSec bouncer key from gopass (homelab/crowdsec/bouncer-key)..."
CROWDSEC_BOUNCER_KEY=$(gopass show -o homelab/crowdsec/bouncer-key)
if [ -z "$CROWDSEC_BOUNCER_KEY" ]; then
  echo "Error: gopass secret homelab/crowdsec/bouncer-key is empty" >&2
  echo "Deploy CrowdSec first, then generate the key:" >&2
  echo "  mise run deploy-crowdsec" >&2
  echo "  kubectl -n crowdsec exec deploy/crowdsec-lapi -- cscli bouncers add traefik-bouncer" >&2
  echo "Then store it in gopass:" >&2
  echo "  gopass insert homelab/crowdsec/bouncer-key" >&2
  exit 1
fi

# Remove orphaned Helm release secrets from previous failed installs
kubectl get secrets -n traefik -l "name=traefik-public,owner=helm" -o name 2>/dev/null | xargs -r kubectl delete -n traefik 2>/dev/null || true

helm repo add traefik https://traefik.github.io/charts --force-update > /dev/null

echo "  Ensuring namespace, bouncer secret and dynamic config..."
kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl create secret generic crowdsec-bouncer-key \
  --namespace traefik \
  --from-literal=key="$CROWDSEC_BOUNCER_KEY" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl create configmap crowdsec-dynamic \
  --namespace traefik \
  --from-file=crowdsec.yml=config/traefik-public/crowdsec-dynamic.yml \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Deploying traefik-public on ${PUBLIC_IPV6}..."
helm upgrade --install traefik-public traefik/traefik \
  --namespace traefik --create-namespace \
  --values config/traefik-public/values.yaml \
  --set-string "additionalArguments[0]=--entryPoints.web.address=[${PUBLIC_IPV6}]:80" \
  --set-string "additionalArguments[1]=--entryPoints.websecure.address=[${PUBLIC_IPV6}]:443" \
  --set-string "additionalArguments[2]=--entryPoints.web.http.redirections.entryPoint.to=websecure" \
  --set-string "additionalArguments[3]=--entryPoints.web.http.redirections.entryPoint.scheme=https" \
  --set-string "additionalArguments[4]=--entryPoints.websecure.http.tls=true" \
  --set-string "additionalArguments[5]=--providers.file.filename=/config/crowdsec.yml" \
  --set-string "additionalArguments[6]=--entryPoints.websecure.http.middlewares=crowdsec@file" \
  --set-string "additionalArguments[7]=--accesslog=true" \
  --set-string "additionalArguments[8]=--accesslog.format=json" > /dev/null

echo "=== Done ==="