#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying CloudNativePG Operator ==="

helm repo add cnpg https://cloudnative-pg.github.io/charts --force-update > /dev/null
helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system --create-namespace \
  --version 0.28.3 \
  --set-json 'nodeSelector={"kubernetes.io/hostname":"nuc-i7-gen11.homelab.stephane-klein.info"}' \
  --set crds.create=true > /dev/null

echo "  Waiting for CloudNativePG operator to be ready..."
kubectl wait --for=condition=Available deployment \
  -n cnpg-system cnpg-cloudnative-pg --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  CloudNativePG operator v1.29.1 deployed on nuc-i7-gen11"
echo "  Webhook certificates managed by the operator (self-signed CA)"
echo "  Ready for PostgreSQL clusters (CRD: Cluster)"
echo ""
echo "  Backup credentials are in .secret and config/cnpg/env"
echo "  Example cluster creation: see https://cloudnative-pg.io/documentation/1.29/"

