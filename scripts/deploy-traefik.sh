#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SSH_USER="${SSH_USER:-stephane}"

echo "=== Deploying cert-manager ==="
helm repo add jetstack https://charts.jetstack.io --force-update > /dev/null
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true > /dev/null

echo "  Creating CA secret..."
kubectl create secret tls ca-key-pair \
  --namespace cert-manager \
  --cert=../certs/ca/ca.crt \
  --key=../certs/ca/ca.key \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Creating ClusterIssuer..."
cat <<EOF | kubectl apply -f - > /dev/null
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: homelab-ca
spec:
  ca:
    secretName: ca-key-pair
EOF

echo "  Waiting for cert-manager to be ready..."
kubectl wait --for=condition=Available deployment \
  -n cert-manager cert-manager cert-manager-webhook \
  --timeout=120s > /dev/null

echo ""
echo "=== Deploying Traefik ==="
helm repo add traefik https://traefik.github.io/charts --force-update > /dev/null
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set deployment.replicas=1 \
  --set hostNetwork=false \
  --set ports.web.port=80 \
  --set ports.websecure.port=443 \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true \
  --set service.type=LoadBalancer \
  --set-string nodeSelector."node-role\.kubernetes\.io/ingress"=true > /dev/null

echo "  Waiting for Traefik to be ready..."
kubectl wait --for=condition=Available deployment \
  -n traefik traefik --timeout=120s > /dev/null

echo ""
echo "=== Applying Netbird forward fix ==="
echo "  Adding nftables rule to accept traffic from Netbird to pods..."
INGRESS_NODE="nuc-i7-gen11.homelab.stephane-klein.info"
ssh "$SSH_USER@$INGRESS_NODE" 'sudo nft insert rule ip netbird netbird-acl-forward-filter iifname "wt0" ip saddr 100.91.0.0/16 ip daddr 10.42.0.0/16 accept 2>&1 || true' && echo "  Rule added"

echo ""
echo "=== Done ==="
echo "  Traefik + cert-manager deployed"
echo "  DNS wildcard *.sklein.internal -> nuc-i7-gen11"
