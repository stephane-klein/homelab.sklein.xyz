#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="grafana"
LOCAL_PORT=8080
SERVICE="svc/grafana"
SERVICE_PORT=80

cleanup() {
  kill "$PF_PID" 2>/dev/null || true
  wait "$PF_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "  Getting Grafana admin password..."
ADMIN_PASSWORD=$(kubectl get secret grafana-admin -n "$NAMESPACE" \
  -o jsonpath='{.data.admin-password}' | base64 -d)

echo "  Starting port-forward..."
kubectl port-forward -n "$NAMESPACE" "$SERVICE" "$LOCAL_PORT:$SERVICE_PORT" &>/dev/null &
PF_PID=$!
sleep 3

if ! kill -0 "$PF_PID" 2>/dev/null; then
  echo "  WARNING: port-forward failed, skipping admin profile configuration"
  exit 0
fi

echo "  Setting admin name..."
curl -s -u "admin:$ADMIN_PASSWORD" \
  -X PUT "http://localhost:$LOCAL_PORT/api/user" \
  -H "Content-Type: application/json" \
  -d '{"name":"St\u00e9phane Klein","login":"admin","email":"admin@localhost"}' > /dev/null

echo "  Setting admin preferences..."
curl -s -u "admin:$ADMIN_PASSWORD" \
  -X PUT "http://localhost:$LOCAL_PORT/api/user/preferences" \
  -H "Content-Type: application/json" \
  -d '{"timezone":"Europe/Paris","weekStart":"monday"}' > /dev/null

echo "  Admin profile configured"
