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

echo "  Fetching current Cloudflare proxy ranges (trusted forwarded headers)..."

# Cloudflare terminates TLS for proxied zones, so traefik-public only ever sees
# Cloudflare anycast IPs otherwise. forwardedHeaders.trustedIPs makes Traefik
# honour forwarded headers (X-Forwarded-For) from these ranges only — never
# insecure=true — so access logs, middlewares and the CrowdSec bouncer see the
# real client IP again. Cloudflare connects to the origin over IPv6, hence the
# v6 ranges are mandatory. Only websecure is listed (web only 301-redirects).
# Ranges are fetched live at deploy time to stay current; the pinned snapshot
# below is a fallback if cloudflare.com is unreachable (an empty trusted list
# would silently mean no trust at all).
# Refs: https://doc.traefik.io/traefik/reference/install-configuration/entrypoints/#forwardedheaders
#       https://developers.cloudflare.com/fundamentals/reference/http-request-headers/
CF_IPS_V4_FALLBACK="173.245.48.0/20,103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,141.101.64.0/18,108.162.192.0/18,190.93.240.0/20,188.114.96.0/20,197.234.240.0/22,198.41.128.0/17,162.158.0.0/15,104.16.0.0/13,104.24.0.0/14,172.64.0.0/13,131.0.72.0/22"   # snapshot 2026-09-07
CF_IPS_V6_FALLBACK="2400:cb00::/32,2606:4700::/32,2803:f800::/32,2405:b500::/32,2405:8100::/32,2a06:98c0::/29,2c0f:f248::/32"   # snapshot 2026-09-07

CF_IPS_V4="$(curl -fsSL --max-time 10 https://www.cloudflare.com/ips-v4 2>/dev/null | tr '\n' ',' | sed 's/,$//')" || true
CF_IPS_V6="$(curl -fsSL --max-time 10 https://www.cloudflare.com/ips-v6 2>/dev/null | tr '\n' ',' | sed 's/,$//')" || true
if [ -n "$CF_IPS_V4" ] && [ -n "$CF_IPS_V6" ]; then
  CF_TRUSTED_IPS="${CF_IPS_V4},${CF_IPS_V6}"
else
  echo "  Warning: could not fetch Cloudflare ranges from cloudflare.com — using pinned snapshot" >&2
  CF_TRUSTED_IPS="${CF_IPS_V4_FALLBACK},${CF_IPS_V6_FALLBACK}"
fi
export CF_TRUSTED_IPS

# Remove orphaned Helm release secrets from previous failed installs
kubectl get secrets -n traefik -l "name=traefik-public,owner=helm" -o name 2>/dev/null | xargs -r kubectl delete -n traefik 2>/dev/null || true

helm repo add traefik https://traefik.github.io/charts --force-update > /dev/null

echo "  Ensuring namespace, bouncer secret and dynamic config..."
kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl create secret generic crowdsec-bouncer-key \
  --namespace traefik \
  --from-literal=key="$CROWDSEC_BOUNCER_KEY" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

# Generate the CrowdSec dynamic config from the template, substituting the
# Cloudflare ranges into the middleware's forwardedHeadersTrustedIPs (the
# plugin keeps the first X-Forwarded-For entry outside these ranges = the real
# client IP). awk -v avoids delimiter issues with IPv6 ':' and CIDR '/'.
CROWDSEC_DYNAMIC_FILE="$(mktemp)"
trap 'rm -f "$CROWDSEC_DYNAMIC_FILE"' EXIT
CF_TRUSTED_IPS_YAML="$(printf '%s\n' "$CF_TRUSTED_IPS" | tr ',' '\n' | sed 's|^|          - |')"
awk -v list="$CF_TRUSTED_IPS_YAML" '
  /forwardedHeadersTrustedIPs: __CF_TRUSTED_IPS__/ {
    print "          forwardedHeadersTrustedIPs:"
    print list
    next
  }
  { print }
' config/traefik-public/crowdsec-dynamic.yml > "$CROWDSEC_DYNAMIC_FILE"

kubectl create configmap crowdsec-dynamic \
  --namespace traefik \
  --from-file=crowdsec.yml="$CROWDSEC_DYNAMIC_FILE" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Deploying traefik-public on ${PUBLIC_IPV6}..."
# helm --set splits values on commas, so escape them (\,) in the trusted IP
# list; helm strvals unescapes them back to a literal comma-separated list.
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
  --set-string "additionalArguments[8]=--accesslog.format=json" \
  --set-string "additionalArguments[9]=--entryPoints.websecure.forwardedHeaders.trustedIPs=${CF_TRUSTED_IPS//,/\\,}" > /dev/null

echo "=== Done ==="