#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

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
  --set hostNetwork=false \
  --set deployment.replicas=1 \
  --set ports.web.port=80 \
  --set ports.web.hostPort=80 \
  --set ports.websecure.port=443 \
  --set ports.websecure.hostPort=443 \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true \
  --set service.type=ClusterIP \
  --set-string nodeSelector."node-role\.kubernetes\.io/ingress"=true > /dev/null

echo "  Transforming Traefik service from LoadBalancer to ClusterIP..."
kubectl patch svc traefik -n traefik -p '{"spec":{"type":"ClusterIP"}}' --type=merge > /dev/null 2>&1 || true

echo "  Waiting for Traefik to be ready..."
kubectl wait --for=condition=Available deployment \
  -n traefik traefik --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  Traefik + cert-manager deployed"
echo "  Traefik with hostPort 80/443 on nuc-i7-gen11"
echo "  DNS wildcard *.sklein.internal -> nuc-i7-gen11"
