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
bind-address: ${NETBIRD_IP}
advertise-address: ${NETBIRD_IP}
node-ip: ${NETBIRD_IP}
disable:
  - traefik
write-kubeconfig-mode: "0644"
CONFIGEOF

sudo mkdir -p /etc/systemd/system/k3s.service.d
sudo tee /etc/systemd/system/k3s.service.d/override.conf > /dev/null << SERVICEEOF
[Unit]
After=netbird.service
Requires=netbird.service
SERVICEEOF

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION={{ ENV.K3S_VERSION }} \
  sh -s - server \
  --token {{ ENV.K3S_TOKEN }}

sudo systemctl start k3s.service

echo "  k3s server installation complete"
