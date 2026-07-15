#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="sveltekit-ssr-skeleton-myapp-test"
SECRET_NAME="sveltekit-ssr-skeleton-myapp-secrets"

echo "=== Deploying sveltekit-ssr-skeleton ==="

echo "  Ensuring namespace $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Creating Secret $SECRET_NAME"
kubectl create secret generic "$SECRET_NAME" \
  -n "$NAMESPACE" \
  --from-literal=AUTHELIA_CLIENT_SECRET="$(gopass show -o homelab/authelia/client-secret-sveltekit-ssr-skeleton)" \
  --from-literal=MY_APP_ADMIN_TOKEN="$(gopass show -o homelab/sveltekit_ssr_skeleton/ADMIN_TOKEN)" \
  --from-literal=SMTP_PASS="$(gopass show -o fastmail.com/sveltekit-ssr-skeleton-myapp-test/smtp-password)" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Applying helmfile"
helmfile -f helmfile.yaml apply

echo "=== Done ==="
