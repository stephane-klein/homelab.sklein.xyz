#!/usr/bin/env bash
set -euo pipefail

ROLE="${1:-server}"

if [ "$ROLE" = "server" ]; then
  K3S_SERVICE="k3s.service"
else
  K3S_SERVICE="k3s-agent.service"
fi

# Deploy kubelet config drop-in for image GC thresholds
mkdir -p /var/lib/rancher/k3s/agent/etc/kubelet.conf.d
if [ -f /var/lib/rancher/k3s/agent/etc/kubelet.conf.d/10-image-gc.conf ]; then
  echo "  Kubelet image GC drop-in already present"
else
  echo "  Creating kubelet image GC drop-in"
  printf '%s\n' \
    'apiVersion: kubelet.config.k8s.io/v1beta1' \
    'kind: KubeletConfiguration' \
    'imageGCHighThresholdPercent: 40' \
    'imageGCLowThresholdPercent: 30' \
    > /var/lib/rancher/k3s/agent/etc/kubelet.conf.d/10-image-gc.conf
fi

# Deploy systemd service for image pruning
printf '%s\n' \
  '[Unit]' \
  'Description=Prune unused container images from k3s' \
  "After=${K3S_SERVICE}" \
  '' \
  '[Service]' \
  'Type=oneshot' \
  'ExecStart=k3s crictl rmi --prune' \
  > /etc/systemd/system/k3s-image-prune.service

# Deploy systemd timer
printf '%s\n' \
  '[Unit]' \
  'Description=Daily prune of unused container images' \
  '' \
  '[Timer]' \
  'OnCalendar=daily' \
  'RandomizedDelaySec=1h' \
  'Persistent=true' \
  '' \
  '[Install]' \
  'WantedBy=timers.target' \
  > /etc/systemd/system/k3s-image-prune.timer

# Enable and start timer
systemctl daemon-reload
systemctl enable --now k3s-image-prune.timer

# Restart k3s via stop+start (restart can cause crash loop)
echo "  Stopping ${K3S_SERVICE}..."
systemctl stop "${K3S_SERVICE}"
sleep 5
echo "  Starting ${K3S_SERVICE}..."
systemctl start "${K3S_SERVICE}"

echo "  Done"
