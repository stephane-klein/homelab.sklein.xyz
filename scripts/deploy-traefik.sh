#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying cert-manager ==="
helm repo add jetstack https://charts.jetstack.io --force-update > /dev/null
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true > /dev/null

echo "  Creating CA secret..."
kubectl create secret tls ca-key-pair \
  --namespace cert-manager \
  --cert=certs/ca/ca.crt \
  --key=certs/ca/ca.key \
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
echo "=== Deploying Traefik (internal, Netbird-only) ==="

# Get Netbird IP from the node (k3s binds on this address)
NODE_NAME="nuc-i7-gen11.homelab.stephane-klein.info"
NETBIRD_IP=$(kubectl get node "$NODE_NAME" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
export NETBIRD_IP

# Remove conflicting managedFields from previous kubectl-patch on the service
kubectl delete svc traefik -n traefik --ignore-not-found=true > /dev/null 2>&1 || true

# Remove orphaned Helm release secrets from previous failed installs
kubectl get secrets -n traefik -l "name=traefik,owner=helm" -o name 2>/dev/null | xargs -r kubectl delete -n traefik 2>/dev/null || true

helm repo add traefik https://traefik.github.io/charts --force-update > /dev/null
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set hostNetwork=true \
  --set deployment.dnsPolicy=ClusterFirstWithHostNet \
  --set deployment.replicas=1 \
  --set ports.web.port=80 \
  --set ports.web.hostPort=0 \
  --set ports.websecure.port=443 \
  --set ports.websecure.hostPort=0 \
  --set ports.traefik.port=9000 \
  --set ports.metrics.port=9101 \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true \
  --set ingressClass.name=traefik \
  --set-string nodeSelector."node-role\.kubernetes\.io/ingress"=true \
  --set service.type=ClusterIP \
  --set-json 'podSecurityContext=null' \
  --set-json 'securityContext={"allowPrivilegeEscalation":true,"capabilities":{"add":["NET_BIND_SERVICE"],"drop":[]},"readOnlyRootFilesystem":true}' \
  --set-string "additionalArguments[0]=--entryPoints.metrics.address=${NETBIRD_IP}:9101" \
  --set-string "additionalArguments[1]=--entryPoints.web.address=${NETBIRD_IP}:80" \
  --set-string "additionalArguments[2]=--entryPoints.websecure.address=${NETBIRD_IP}:443" \
  --set-string "additionalArguments[3]=--entryPoints.web.http.redirections.entryPoint.to=websecure" \
  --set-string "additionalArguments[4]=--entryPoints.web.http.redirections.entryPoint.scheme=https" > /dev/null

echo "  Waiting for Traefik to be ready..."
kubectl wait --for=condition=Available deployment \
  -n traefik traefik --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  cert-manager deployed"
echo "  Traefik (internal) with hostNetwork on Netbird IP $NETBIRD_IP"
