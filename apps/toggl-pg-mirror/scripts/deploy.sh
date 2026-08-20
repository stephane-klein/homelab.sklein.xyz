#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="toggl-pg-mirror"

echo "=== Waiting for external-secrets operator ==="
kubectl wait --for=condition=Available deployment \
  -n external-secrets external-secrets --timeout=120s > /dev/null

echo "=== Ensuring ClusterSecretStore kubernetes-cnpg-memex ==="
kubectl apply -f ../../config/external-secrets/clustersecretstore-cnpg-memex.yaml

echo "=== Ensuring namespace and toggl-pg-mirror secret ==="
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic toggl-pg-mirror \
  -n "$NAMESPACE" \
  --from-literal=toggl-token="$(gopass show -o toggl/stephane-klein/api-token)" \
  --from-literal=admin-token="$(gopass show -o toggl.sklein.internal/admin-token)" \
  --from-literal=smtp-password="$(gopass show -o toggl.sklein.internal/fastmail-smtp)" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=== Deploying toggl-pg-mirror ==="
helmfile -f helmfile.yaml apply

echo "=== Sync users ==="

curl -fsS -X PUT -H "Authorization: Bearer $(gopass show -o toggl.sklein.internal/admin-token)" \
    -H "Content-Type: application/json" \
    --data-binary "$(gopass cat toggl.sklein.internal/users.json)" \
    https://toggl.sklein.internal/api/v1/admin/users/sync | jq

echo "=== Done ==="
