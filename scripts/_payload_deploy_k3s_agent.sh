#!/usr/bin/env bash
set -euo pipefail

NETBIRD_IP=$(ip -4 addr show wt0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$NETBIRD_IP" ]; then
  echo "Error: Netbird interface wt0 not found or has no IP" >&2
  exit 1
fi

echo "  Netbird IP: $NETBIRD_IP"

sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml > /dev/null << CONFIGEOF
server: https://{{ ENV.K3S_SERVER_IP }}:6443
token: {{ ENV.K3S_TOKEN }}
node-ip: ${NETBIRD_IP}
CONFIGEOF

sudo mkdir -p /etc/systemd/system/k3s-agent.service.d
sudo tee /etc/systemd/system/k3s-agent.service.d/override.conf > /dev/null << SERVICEEOF
[Unit]
After=netbird.service
Requires=netbird.service
SERVICEEOF

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION={{ ENV.K3S_VERSION }} \
  sh -s - agent

if rpm-ostree status | grep -q "Staged:"; then
  sudo systemctl reboot
fi

timeout 120 sudo systemctl start k3s-agent.service || true

echo "  k3s agent installation complete"
