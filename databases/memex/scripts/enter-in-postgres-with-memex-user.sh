#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="memex"
CLUSTER="memex-cluster"
DB_USER="memex"
DB_NAME="memex"

POD=$(kubectl get pod -n "$NAMESPACE" \
  -l "cnpg.io/cluster=$CLUSTER,cnpg.io/podRole=instance" \
  -o jsonpath='{.items[0].metadata.name}')

PASSWORD=$(kubectl get secret "$CLUSTER-app" -n "$NAMESPACE" \
  -o jsonpath='{.data.password}' | base64 -d)

kubectl exec -n "$NAMESPACE" -it "$POD" -- \
  env PGPASSWORD="$PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME"