#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

USERS_FILE="config/authelia/users.yml"

if [ ! -f "$USERS_FILE" ]; then
  echo "  ERROR: $USERS_FILE not found"
  echo "  Run 'mise run deploy-authelia' first to generate it"
  exit 1
fi

echo "=== Pushing Authelia users config ==="

kubectl create configmap authelia-users \
  --namespace authelia --dry-run=client -o yaml \
  --from-file=users.yml="$USERS_FILE" | kubectl apply -f - > /dev/null

echo "  ConfigMap 'authelia-users' updated from $USERS_FILE"
