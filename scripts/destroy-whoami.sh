#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

kubectl delete ingress whoami --ignore-not-found > /dev/null
kubectl delete service whoami --ignore-not-found > /dev/null
kubectl delete deployment whoami --ignore-not-found > /dev/null
kubectl delete secret whoami-tls --ignore-not-found > /dev/null

echo "=== whoami destroyed ==="
