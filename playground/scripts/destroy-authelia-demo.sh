#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

kubectl delete ingress whoami-authelia-demo --ignore-not-found > /dev/null
kubectl delete service whoami-authelia-demo --ignore-not-found > /dev/null
kubectl delete deployment whoami-authelia-demo --ignore-not-found > /dev/null
kubectl delete secret whoami-authelia-demo-tls --ignore-not-found > /dev/null

echo "=== whoami-authelia-demo destroyed ==="
