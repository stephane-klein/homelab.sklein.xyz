#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SERVER="${SERVER:-nuc-i7-gen11.homelab.stephane-klein.info}"
SSH_USER="${SSH_USER:-stephane}"
export SERVER SSH_USER

echo "=== Assign static IPv6 ::1000 to $SERVER ==="

ssh "$SSH_USER@$SERVER" 'sudo bash -s' < _payload_assign-static-ipv6.sh

echo "=== Done ==="
