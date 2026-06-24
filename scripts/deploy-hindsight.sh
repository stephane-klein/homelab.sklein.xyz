#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="hindsight"

echo "=== Loading secrets ==="
if [ -z "${HINDSIGHT_LLM_API_KEY:-}" ]; then
  HINDSIGHT_LLM_API_KEY=$(grep '^HINDSIGHT_LLM_API_KEY=' ".secret" | cut -d'"' -f2)
fi
if [ -z "${HINDSIGHT_MCP_TOKEN:-}" ]; then
  HINDSIGHT_MCP_TOKEN=$(grep '^HINDSIGHT_MCP_TOKEN=' ".secret" | cut -d'"' -f2)
fi
if [ -z "${HINDSIGHT_API_RERANKER_OPENROUTER_API_KEY:-}" ]; then
  HINDSIGHT_API_RERANKER_OPENROUTER_API_KEY=$(grep '^HINDSIGHT_API_RERANKER_OPENROUTER_API_KEY=' ".secret" | cut -d'"' -f2)
fi
if [ -z "${HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY:-}" ]; then
  HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY="${HINDSIGHT_API_EMBEDDINGS_DEEPSEEK_API_KEY:-}"
fi
if [ -z "${HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY:-}" ]; then
  HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY=$(grep '^HINDSIGHT_API_EMBEDDINGS_DEEPSEEK_API_KEY=' ".secret" | cut -d'"' -f2)
fi

echo "=== Extracting CNPG app password ==="
POSTGRES_PASSWORD=$(kubectl get secret hindsight-cnpg-cluster-app \
  -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)

echo "=== Ensuring namespace ==="
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "=== Creating hindsight-config secret ==="
kubectl create secret generic hindsight-config \
  -n "$NAMESPACE" \
  --from-literal=postgres-password="${POSTGRES_PASSWORD}" \
  --from-literal=HINDSIGHT_API_LLM_API_KEY="${HINDSIGHT_LLM_API_KEY}" \
  --from-literal=HINDSIGHT_API_MCP_AUTH_TOKEN="${HINDSIGHT_MCP_TOKEN}" \
  --from-literal=HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY="${HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY}" \
  --from-literal=HINDSIGHT_API_RERANKER_OPENROUTER_API_KEY="${HINDSIGHT_API_RERANKER_OPENROUTER_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "=== Deploying Hindsight ==="
helmfile -f helmfile/helmfile.yaml.gotmpl apply

echo "  Waiting for API to be ready..."
kubectl rollout status deployment hindsight-api \
  -n "$NAMESPACE" --timeout=180s > /dev/null

echo "  Waiting for Control Plane to be ready..."
kubectl rollout status deployment hindsight-control-plane \
  -n "$NAMESPACE" --timeout=180s > /dev/null

echo "=== Creating S3 backup credentials ==="
CNPG_BACKUPS_ACCESS_KEY=$(grep '^CNPG_BACKUPS_ACCESS_KEY=' ".secret" | cut -d'"' -f2)
CNPG_BACKUPS_SECRET_KEY=$(grep '^CNPG_BACKUPS_SECRET_KEY=' ".secret" | cut -d'"' -f2)

kubectl create secret generic hindsight-backup-credentials \
  -n "$NAMESPACE" \
  --from-literal=accessKey="${CNPG_BACKUPS_ACCESS_KEY}" \
  --from-literal=secretKey="${CNPG_BACKUPS_SECRET_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "=== Deploying logical backup CronJob ==="
kubectl apply -f config/hindsight/cronjob-backup.yaml

echo "=== Deploying API certificate for MCP ==="
kubectl apply -f config/hindsight/mcp-certificate.yaml

echo "=== Deploying API IngressRoute for MCP ==="
kubectl apply -f config/hindsight/mcp-ingress.yaml

echo ""
echo "=== Done ==="
echo "  UI: https://hindsight.sklein.internal"
echo "  API: https://api.hindsight.sklein.internal"
echo "  Backup: nightly at 3am Paris (retention 7 days)"
