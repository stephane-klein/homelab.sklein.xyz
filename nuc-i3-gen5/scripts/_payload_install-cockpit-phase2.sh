#!/usr/bin/env bash
set -euo pipefail

NETBIRD_IP=$(ip -4 addr show wt0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -n "$NETBIRD_IP" ]; then
  sudo mkdir -p /etc/systemd/system/cockpit.socket.d
  sudo tee /etc/systemd/system/cockpit.socket.d/listen.conf > /dev/null << EOF
[Socket]
ListenStream=
ListenStream=${NETBIRD_IP}:9090
EOF
  sudo systemctl daemon-reload
fi

sudo systemctl enable --now cockpit.socket || true
