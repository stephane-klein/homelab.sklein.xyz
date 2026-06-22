#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

SSH_USER="${SSH_USER:-stephane}"
SERVER_HOST="${SERVER_HOST:-nuc-i7-gen11.homelab.stephane-klein.info}"
AGENT_HOST="${AGENT_HOST:-nuc-i3-gen5.homelab.stephane-klein.info}"

echo "=== Configuring k3s image GC across cluster ==="
echo "  Server: $SERVER_HOST"
echo "  Agent:  $AGENT_HOST"
echo ""

# Configure server
echo "--- Server: $SERVER_HOST ---"
cat scripts/_payload_configure_k3s_image_prune.sh | \
  ssh "$SSH_USER@$SERVER_HOST" 'sudo bash -s -- server'
echo ""

# Wait for k3s API to be ready before restarting agent
echo "--- Waiting for k3s API to be ready ---"
MAX_ATTEMPTS=30
for i in $(seq 1 "$MAX_ATTEMPTS"); do
  if ssh -o ConnectTimeout=5 "$SSH_USER@$SERVER_HOST" "kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes" > /dev/null 2>&1; then
    echo "  k3s API is ready"
    break
  fi
  echo "    Waiting... attempt $i/$MAX_ATTEMPTS"
  sleep 10

  if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
    echo "  Warning: k3s API did not become ready, proceeding anyway" >&2
  fi
done
echo ""

# Configure agent
echo "--- Agent: $AGENT_HOST ---"
cat scripts/_payload_configure_k3s_image_prune.sh | \
  ssh "$SSH_USER@$AGENT_HOST" 'sudo bash -s -- agent'
echo ""

echo "=== Done ==="
echo "  Kubelet image GC: high=40%, low=30% (via kubelet config drop-in)"
echo "  Image prune timer: k3s-image-prune.timer (daily at ~01:00)"
echo ""
echo "  Verify with:"
echo "    ssh '$SSH_USER@\$HOST' 'systemctl status k3s-image-prune.timer'"
echo "    ssh '$SSH_USER@\$HOST' 'systemctl status k3s-image-prune.service --no-pager'"
