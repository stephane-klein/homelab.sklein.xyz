#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="forgejo"

echo "=== Deploying Forgejo ==="

echo "  Ensuring namespace and admin secret..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

# Admin credentials (keys: username, password) read by the forgejo-helm chart
# (gitea.admin.existingSecret). Source of truth: Gopass.
kubectl create secret generic forgejo-admin-secret \
  -n "$NAMESPACE" \
  --from-literal=username="$(gopass show -o homelab/forgejo/admin/username)" \
  --from-literal=password="$(gopass show -o homelab/forgejo/admin/password)" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Ensuring S3 backup credentials secret..."
kubectl create secret generic forgejo-cluster-backup-s3-creds \
  -n "$NAMESPACE" \
  --from-literal=ACCESS_KEY_ID="$(gopass show -o homelab/scaleway/CNPG_BACKUPS_ACCESS_KEY)" \
  --from-literal=ACCESS_SECRET_KEY="$(gopass show -o homelab/scaleway/CNPG_BACKUPS_SECRET_KEY)" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Deploying CNPG cluster (forgejo-cluster) + Forgejo app..."
helmfile -f helmfile.yaml apply

echo "  Applying weekly data-backup CronJob..."
kubectl apply -f backup/cronjob-backup.yaml

echo "  Applying SSH IngressRouteTCP (requires the internal Traefik 'ssh' entrypoint)..."
kubectl apply -f ssh/ingress-route-tcp.yaml

echo ""
echo "=== Done ==="
echo "  Forgejo:    https://forgejo.sklein.internal"
echo "  SSH clone:  ssh://git@forgejo.sklein.internal:32222/<user>/<repo>.git"
echo "  DB admin:   kubectl get secret forgejo-cluster-superuser -n forgejo -o jsonpath='{.data.password}' | base64 -d"
echo "  DB app:     kubectl get secret forgejo-cluster-app -n forgejo -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "  Note: if the 'ssh' entrypoint does not exist yet on Traefik (internal),"
echo "  re-run ./scripts/deploy-traefik.sh once, then this deploy again."
