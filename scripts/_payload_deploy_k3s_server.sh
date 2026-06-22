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

# Kubelet image GC thresholds via drop-in config
sudo mkdir -p /var/lib/rancher/k3s/agent/etc/kubelet.conf.d
sudo tee /var/lib/rancher/k3s/agent/etc/kubelet.conf.d/10-image-gc.conf > /dev/null << KUBELETEOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
imageGCHighThresholdPercent: 40
imageGCLowThresholdPercent: 30
KUBELETEOF

sudo mkdir -p /etc/systemd/system/k3s.service.d
sudo tee /etc/systemd/system/k3s.service.d/override.conf > /dev/null << SERVICEEOF
[Unit]
After=netbird.service
Requires=netbird.service
SERVICEEOF

# Deploy systemd service for nightly image pruning
sudo tee /etc/systemd/system/k3s-image-prune.service > /dev/null << SERVICEEOF
[Unit]
Description=Prune unused container images from k3s
After=k3s.service

[Service]
Type=oneshot
ExecStart=k3s crictl rmi --prune
SERVICEEOF

sudo tee /etc/systemd/system/k3s-image-prune.timer > /dev/null << TIMEREOF
[Unit]
Description=Daily prune of unused container images

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
TIMEREOF

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION={{ ENV.K3S_VERSION }} \
  sh -s - server \
  --token {{ ENV.K3S_TOKEN }}

sudo systemctl start k3s.service

sudo systemctl enable --now k3s-image-prune.timer

echo "  k3s server installation complete"
