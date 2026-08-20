#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="toggl-pg-mirror"

echo "=== Waiting for external-secrets operator ==="
kubectl wait --for=condition=Available deployment \
  -n external-secrets external-secrets --timeout=120s > /dev/null

echo "=== Ensuring ClusterSecretStore kubernetes-cnpg-memex ==="
kubectl apply -f ../../config/external-secrets/clustersecretstore-cnpg-memex.yaml

echo "=== Ensuring namespace and toggl-api-token secret ==="
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic toggl-api-token \
  -n "$NAMESPACE" \
  --from-literal=token="$(gopass show toggl/stephane-klein/api-token)" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=== Deploying toggl-pg-mirror ==="
helmfile -f helmfile.yaml apply

echo "=== Done ==="
