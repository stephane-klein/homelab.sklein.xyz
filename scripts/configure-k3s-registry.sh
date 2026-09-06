#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

SERVER_HOST="nuc-i7-gen11.homelab.stephane-klein.info"
AGENT_HOST="nuc-i3-gen5.homelab.stephane-klein.info"
SSH_USER="${SSH_USER:-stephane}"
REGISTRY_HOST="forgejo.sklein.internal"
REGISTRY_USER="${REGISTRY_USER:-stephane-klein}"

CA_SRC="certs/ca/ca.crt"
CA_DST="/etc/rancher/k3s/registry-ca.crt"
REGISTRIES_YAML="/etc/rancher/k3s/registries.yaml"

if [ ! -f "$CA_SRC" ]; then
  echo "Error: $CA_SRC not found (run 'mise run setup-secret' first)" >&2
  exit 1
fi

# Forgejo container-registry token (scopes: read:package,write:package).
# Created for REGISTRY_USER with:
#   kubectl exec -n forgejo deploy/forgejo -- forgejo admin user generate-access-token \
#     -u "$REGISTRY_USER" -t container-registry --scopes "read:package,write:package" --raw
REGISTRY_PASSWORD="$(gopass show -o "homelab/forgejo/container-registry-token")"
if [ -z "$REGISTRY_PASSWORD" ]; then
  echo "Error: empty gopass entry homelab/forgejo/container-registry-token" >&2
  echo "Generate the token and store it first (see apps/forgejo/README.md, Container Registry section)." >&2
  exit 1
fi

echo "=== Configuring containerd registry auth for ${REGISTRY_HOST} ==="
echo "  Detecting server Netbird IP..."
SERVER_IP="$(ssh "$SSH_USER@$SERVER_HOST" 'ip -4 addr show wt0 | grep -oP "(?<=inet\s)\d+(\.\d+){3}"')"
echo "  Server Netbird IP: $SERVER_IP"
echo "  Registry user:     $REGISTRY_USER"

configure_node() {
  local host="$1"
  local svc="$2"

  echo ""
  echo "--- Configuring $host ---"

  echo "  Installing homelab CA certificate..."
  cat "$CA_SRC" | ssh "$SSH_USER@$host" "sudo tee $CA_DST > /dev/null"

  echo "  Writing $REGISTRIES_YAML..."
  ssh "$SSH_USER@$host" "sudo tee $REGISTRIES_YAML > /dev/null" > /dev/null <<YAML
configs:
  "${REGISTRY_HOST}":
    auth:
      username: ${REGISTRY_USER}
      password: "${REGISTRY_PASSWORD}"
    tls:
      ca_file: ${CA_DST}
YAML

  echo "  Ensuring ${REGISTRY_HOST} resolves..."
  if ! ssh "$SSH_USER@$host" "getent hosts $REGISTRY_HOST" > /dev/null 2>&1; then
    echo "  ${REGISTRY_HOST} not resolvable on $host — adding /etc/hosts entry"
    ssh "$SSH_USER@$host" \
      "grep -q '${REGISTRY_HOST}' /etc/hosts || echo '${SERVER_IP} ${REGISTRY_HOST}' | sudo tee -a /etc/hosts > /dev/null"
  fi

  echo "  Restarting $svc (short downtime)..."
  ssh "$SSH_USER@$host" "sudo systemctl restart $svc"
}

configure_node "$SERVER_HOST" "k3s.service"

echo ""
echo "  Waiting for the k3s API to be ready..."
MAX_ATTEMPTS=30
for i in $(seq 1 "$MAX_ATTEMPTS"); do
  if ssh -o ConnectTimeout=5 "$SSH_USER@$SERVER_HOST" \
    "kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes" > /dev/null 2>&1; then
    echo "  k3s API is ready"
    break
  fi
  if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
    echo "Warning: k3s API did not become ready within timeout" >&2
  fi
  sleep 5
done

configure_node "$AGENT_HOST" "k3s-agent.service"

echo ""
echo "=== Done ==="
echo "  containerd on both nodes can now pull from ${REGISTRY_HOST}"
echo "  Test: podman pull forgejo.sklein.internal/stephane-klein/<image>:<tag> (from a Netbird peer)"
