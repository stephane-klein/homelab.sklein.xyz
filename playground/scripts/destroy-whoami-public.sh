#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

kubectl delete ingress whoami-public --ignore-not-found > /dev/null
kubectl delete service whoami-public --ignore-not-found > /dev/null
kubectl delete deployment whoami-public --ignore-not-found > /dev/null
kubectl delete secret whoami-public-tls --ignore-not-found > /dev/null

echo "=== whoami-public destroyed ==="
