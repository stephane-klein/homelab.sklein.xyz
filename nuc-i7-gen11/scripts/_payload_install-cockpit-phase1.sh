#!/usr/bin/env bash
set -euo pipefail

set +e
OUTPUT=$(sudo rpm-ostree install -y --allow-inactive cockpit 2>&1)
EXIT_CODE=$?
set -e

if echo "$OUTPUT" | grep -q "already requested"; then
  echo "  cockpit already requested, skipping"
  REBOOT_NEEDED=false
elif [ "$EXIT_CODE" -eq 0 ] && echo "$OUTPUT" | grep -q "Changes queued"; then
  echo "  cockpit installed, reboot needed"
  REBOOT_NEEDED=true
else
  echo "  Unexpected rpm-ostree output: $OUTPUT"
  REBOOT_NEEDED=false
fi

sudo mkdir -p /etc/cockpit
sudo tee /etc/cockpit/cockpit.conf > /dev/null << 'CONFFEOF'
[WebService]
Origins = https://{{ ENV.COCKPIT_DOMAIN }}:9090
CONFFEOF

if [ "$REBOOT_NEEDED" = true ]; then
  sudo systemctl reboot
fi
