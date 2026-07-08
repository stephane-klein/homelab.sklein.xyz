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

# Remove orphaned Helm release secrets from previous failed installs
kubectl get secrets -n traefik -l "name=traefik-public,owner=helm" -o name 2>/dev/null | xargs -r kubectl delete -n traefik 2>/dev/null || true

helm repo add traefik https://traefik.github.io/charts --force-update > /dev/null

echo "  Deploying traefik-public on ${PUBLIC_IPV6}..."

helm upgrade --install traefik-public traefik/traefik \
  --namespace traefik --create-namespace \
  --set hostNetwork=true \
  --set deployment.dnsPolicy=ClusterFirstWithHostNet \
  --set deployment.replicas=1 \
  --set-json "ports.web=null" \
  --set-json "ports.websecure=null" \
  --set ports.traefik.port=9001 \
  --set-json "ports.metrics=null" \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=false \
  --set ingressClass.name=traefik-public \
  --set-string nodeSelector."node-role\.kubernetes\.io/ingress"=true \
  --set service.enabled=false \
  --set-json 'podSecurityContext=null' \
  --set-json 'securityContext={"allowPrivilegeEscalation":true,"capabilities":{"add":["NET_BIND_SERVICE"],"drop":[]},"readOnlyRootFilesystem":true}' \
  --set providers.kubernetesCRD.enabled=false \
  --set-string "additionalArguments[0]=--entryPoints.web.address=[${PUBLIC_IPV6}]:80" \
  --set-string "additionalArguments[1]=--entryPoints.websecure.address=[${PUBLIC_IPV6}]:443" \
  --set-string "additionalArguments[2]=--entryPoints.web.http.redirections.entryPoint.to=websecure" \
  --set-string "additionalArguments[3]=--entryPoints.web.http.redirections.entryPoint.scheme=https" \
  --set-string "additionalArguments[4]=--entryPoints.websecure.http.tls=true" > /dev/null

echo "=== Done ==="
