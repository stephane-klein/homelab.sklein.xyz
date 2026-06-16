#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SSH_USER="${SSH_USER:-stephane}"
SERVER_HOSTNAME="nuc-i7-gen11.homelab.stephane-klein.info"

echo "=== Disabling k3s ServiceLB on $SERVER_HOSTNAME ==="

ssh "$SSH_USER@$SERVER_HOSTNAME" sudo tee /etc/rancher/k3s/config.yaml > /dev/null << 'CONFIGEOF'
bind-address: 100.91.106.71
advertise-address: 100.91.106.71
node-ip: 100.91.106.71
disable:
  - traefik
  - servicelb
write-kubeconfig-mode: "0644"
CONFIGEOF

echo "  Config updated, restarting k3s..."
ssh "$SSH_USER@$SERVER_HOSTNAME" sudo systemctl restart k3s.service

echo "  Waiting for API to be ready..."
sleep 10
kubectl wait --for=condition=Available deployment \
  -n kube-system coredns --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  ServiceLB disabled on $SERVER_HOSTNAME"
