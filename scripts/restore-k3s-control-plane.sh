#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

# Disaster recovery: restore the k3s control-plane state (state.db + cred/ + tls/)
# on a (re)provisioned node, from the latest backup in backups/k3s-control-plane/.
#
# Prerequisites:
#   - k3s must be installed on the target but NOT started
#     (e.g. INSTALL_K3S_SKIP_START=true on a fresh node)
#   - SSH access to the node (via Netbird)
#
# Required env: K3S_TOKEN (the cluster token used to encrypt/decrypt the
#   bootstrap data inside state.db — it MUST match the token of the backup)
# Optional env with defaults: SSH_USER

SSH_USER="${SSH_USER:-stephane}"
SERVER_HOST="nuc-i7-gen11.homelab.stephane-klein.info"
BACKUP_ROOT="backups/k3s-control-plane"
REMOTE_TARBALL="/tmp/k3s-restore.tgz"

if [ -z "${K3S_TOKEN:-}" ]; then
  echo "Error: K3S_TOKEN is not set" >&2
  echo "It must match the cluster token used when the backup was created." >&2
  exit 1
fi

LATEST_DIR=$(ls -1dt "$BACKUP_ROOT"/*/ 2>/dev/null | head -1)
if [ -z "$LATEST_DIR" ]; then
  echo "Error: no backup found in $BACKUP_ROOT" >&2
  exit 1
fi

TARBALL=$(ls "$LATEST_DIR"*.tgz 2>/dev/null | head -1)
if [ -z "$TARBALL" ]; then
  echo "Error: no tarball found in $LATEST_DIR" >&2
  exit 1
fi

echo "=== k3s control-plane restore ==="
echo "  Backup: $TARBALL"
echo "  Target: $SERVER_HOST"
echo ""
echo "  WARNING: destructive disaster-recovery operation."
echo "  It will stop k3s and replace the whole server state"
echo "  (state.db, credentials, TLS certificates)."
read -r -p "  Type YES to confirm: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
  echo "  Aborted."
  exit 1
fi
echo ""

# ============================================================
# Step 1: Detect Netbird IP of the server
# ============================================================
echo "--- Step 1: Detecting Netbird IP of server ---"
NETBIRD_IP=$(ssh "$SSH_USER@$SERVER_HOST" 'ip -4 addr show wt0 | grep -oP "(?<=inet\s)\d+(\.\d+){3}"')
if [ -z "$NETBIRD_IP" ]; then
  echo "Error: Could not detect Netbird IP on $SERVER_HOST" >&2
  exit 1
fi
echo "  Server Netbird IP: $NETBIRD_IP"
echo ""

# ============================================================
# Step 2: Write k3s config.yaml
# ============================================================
echo "--- Step 2: Writing /etc/rancher/k3s/config.yaml ---"
ssh "$SSH_USER@$SERVER_HOST" "sudo mkdir -p /etc/rancher/k3s"
ssh "$SSH_USER@$SERVER_HOST" "sudo tee /etc/rancher/k3s/config.yaml > /dev/null" <<CONFIGEOF
bind-address: ${NETBIRD_IP}
advertise-address: ${NETBIRD_IP}
node-ip: ${NETBIRD_IP}
secrets-encryption: true
disable:
  - traefik
write-kubeconfig-mode: "0644"
token: ${K3S_TOKEN}
CONFIGEOF
echo "  config.yaml written"
echo ""

# ============================================================
# Step 3: Upload backup tarball
# ============================================================
echo "--- Step 3: Uploading backup tarball ---"
scp "$TARBALL" "$SSH_USER@$SERVER_HOST:$REMOTE_TARBALL"
echo "  Tarball uploaded"
echo ""

# ============================================================
# Step 4: Restore server state and start k3s
# ============================================================
echo "--- Step 4: Restoring server state and starting k3s ---"
ssh "$SSH_USER@$SERVER_HOST" 'sudo bash -s' <<'REMOTE_EOF'
set -euo pipefail

systemctl stop k3s.service || true

rm -rf /var/lib/rancher/k3s/server/db
rm -rf /var/lib/rancher/k3s/server/cred
rm -rf /var/lib/rancher/k3s/server/tls
mkdir -p /var/lib/rancher/k3s/server

tar xzf /tmp/k3s-restore.tgz -C /

systemctl start k3s.service
REMOTE_EOF
echo "  k3s started"
echo ""

# ============================================================
# Step 5: Wait for k3s API to be ready
# ============================================================
echo "--- Step 5: Waiting for k3s API to be ready ---"
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

echo "=== Done ==="
echo "  Cluster restored from: $TARBALL"
echo "  Rejoin the agent node: ./scripts/deploy-k3s.sh (or re-join the agent manually)"