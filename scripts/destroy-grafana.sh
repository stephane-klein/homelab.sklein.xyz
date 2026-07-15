#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="grafana"

echo "=== Destroying Grafana ==="

helmfile -f helmfile/helmfile.yaml.gotmpl destroy --selector name=grafana

kubectl delete secret grafana-admin -n "$NAMESPACE" --ignore-not-found > /dev/null

echo "=== Done ==="
