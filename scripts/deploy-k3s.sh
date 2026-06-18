#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

# Required env: K3S_TOKEN (loaded via mise from .secret)
# Optional env with defaults: SSH_USER, K3S_VERSION

SSH_USER="${SSH_USER:-stephane}"
K3S_VERSION="${K3S_VERSION:-v1.36.1+k3s1}"

SERVER_HOST="nuc-i7-gen11.homelab.stephane-klein.info"
AGENT_HOST="nuc-i3-gen5.homelab.stephane-klein.info"

export K3S_VERSION

if [ -z "${K3S_TOKEN:-}" ]; then
  echo "Error: K3S_TOKEN is not set" >&2
  echo "Generate one: mise run generate-k3s-token" >&2
  exit 1
fi

echo "=== k3s Cluster Deployment ==="
echo "  Server (control-plane): $SERVER_HOST"
echo "  Agent (worker):         $AGENT_HOST"
echo ""

# ============================================================
# Step 1: Detect Netbird IP of the server
# ============================================================
echo "--- Step 1: Detecting Netbird IP of server ---"
K3S_SERVER_IP=$(ssh "$SSH_USER@$SERVER_HOST" 'ip -4 addr show wt0 | grep -oP "(?<=inet\s)\d+(\.\d+){3}"')
if [ -z "$K3S_SERVER_IP" ]; then
  echo "Error: Could not detect Netbird IP on $SERVER_HOST" >&2
  exit 1
fi
echo "  Server Netbird IP: $K3S_SERVER_IP"
export K3S_SERVER_IP
echo ""

# ============================================================
# Step 2: Deploy k3s server
# ============================================================
echo "--- Step 2: Deploying k3s server on $SERVER_HOST ---"
minijinja-cli --env scripts/_payload_deploy_k3s_server.sh | ssh "$SSH_USER@$SERVER_HOST" 'sudo bash -s'
echo "  k3s server deployed"
echo ""

# ============================================================
# Step 3: Wait for k3s API to be ready
# ============================================================
echo "--- Step 3: Waiting for k3s API to be ready ---"
MAX_ATTEMPTS=30
for i in $(seq 1 "$MAX_ATTEMPTS"); do
  if ssh -o ConnectTimeout=5 "$SSH_USER@$SERVER_HOST" "kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes" > /dev/null 2>&1; then
    echo "  k3s API is ready"
    break
  fi
  echo "    Waiting... attempt $i/$MAX_ATTEMPTS"
  sleep 10

  if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
    echo "Error: k3s API did not become ready" >&2
    exit 1
  fi
done
echo ""

# ============================================================
# Step 4: Deploy k3s agent
# ============================================================
echo "--- Step 4: Deploying k3s agent on $AGENT_HOST ---"
set +e
minijinja-cli --env scripts/_payload_deploy_k3s_agent.sh | ssh "$SSH_USER@$AGENT_HOST" 'sudo bash -s'
PAYLOAD_EXIT=$?
set -e

echo "  Waiting for agent to become active..."
MAX_ATTEMPTS=30
for i in $(seq 1 "$MAX_ATTEMPTS"); do
  if ssh -o ConnectTimeout=5 "$SSH_USER@$AGENT_HOST" "systemctl is-active k3s-agent.service" 2>/dev/null | grep -q "^active$"; then
    echo "  k3s agent is active"
    break
  fi
  echo "    Waiting... attempt $i/$MAX_ATTEMPTS"
  sleep 10

  if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
    echo "Warning: k3s agent did not become active within timeout" >&2
  fi
done
echo ""

# ============================================================
# Step 5: Verify cluster
# ============================================================
echo "--- Step 5: Verifying cluster ---"
ssh "$SSH_USER@$SERVER_HOST" "kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes -o wide"
echo ""

# ============================================================
# Step 6: Retrieve kubeconfig
# ============================================================
echo "--- Step 6: Retrieving kubeconfig ---"
KUBECONFIG_DEST="k3s.kubeconfig"
scp "$SSH_USER@$SERVER_HOST:/etc/rancher/k3s/k3s.yaml" "$KUBECONFIG_DEST"
sed -i "s/127.0.0.1/${K3S_SERVER_IP}/g" "$KUBECONFIG_DEST"
sed -i "s/localhost/${K3S_SERVER_IP}/g" "$KUBECONFIG_DEST"
echo "  Kubeconfig written to: $KUBECONFIG_DEST"
echo ""

echo ""
echo "=== Done ==="
echo "  Cluster is ready."
echo "  kubectl --kubeconfig k3s.kubeconfig get nodes"
