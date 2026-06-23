#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

TOGGL_API_TOKEN="$(gopass show toggl/stephane-klein/api-token)"

echo "=== Waiting for external-secrets operator ==="
kubectl wait --for=condition=Available deployment \
  -n external-secrets external-secrets --timeout=120s > /dev/null

echo "=== Ensuring ClusterSecretStore kubernetes-cnpg-memex ==="
kubectl apply -f config/external-secrets/clustersecretstore-cnpg-memex.yaml

echo "=== Ensuring namespace and toggl-api-token secret ==="
kubectl create namespace toggl-pg-mirror --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic toggl-api-token \
  -n toggl-pg-mirror \
  --from-literal=token="${TOGGL_API_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=== Deploying toggl-pg-mirror ==="
helmfile -f helmfile/helmfile.yaml.gotmpl apply

echo "=== Done ==="
