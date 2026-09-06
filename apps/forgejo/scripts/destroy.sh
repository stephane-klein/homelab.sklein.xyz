#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "  Deleting weekly data-backup CronJob..."
kubectl delete cronjob forgejo-data-backup -n forgejo --ignore-not-found

echo "  Deleting SSH IngressRouteTCP..."
kubectl delete -f ssh/ingress-route-tcp.yaml --ignore-not-found

helmfile -f helmfile.yaml destroy
