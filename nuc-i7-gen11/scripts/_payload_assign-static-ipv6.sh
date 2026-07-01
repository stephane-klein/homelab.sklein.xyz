#!/usr/bin/env bash
set -euo pipefail

PREFIX=$(ip -6 addr show scope global | grep -oP 'inet6 \K[0-9a-f:]+' | grep -v '^fd' | head -1 | cut -d: -f1-4)
STATIC_ADDR="${PREFIX}::1000"

echo "Prefix detected: ${PREFIX}"
echo "Adding static IPv6: ${STATIC_ADDR}"

sudo nmcli con modify "Wired connection 2" ipv6.addresses "${STATIC_ADDR}/64"
sudo nmcli con modify "Wired connection 2" ipv6.method auto
sudo nmcli con down "Wired connection 2" && sudo nmcli con up "Wired connection 2"

echo "Verifying..."
ip -6 addr show dev enp89s0 | grep ::1000
echo "Done."
