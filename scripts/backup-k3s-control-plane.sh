#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

# Optional env with defaults: SSH_USER
# Requires SSH access to the k3s control-plane node (via Netbird)

SSH_USER="${SSH_USER:-stephane}"
SERVER_HOST="nuc-i7-gen11.homelab.stephane-klein.info"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="backups/k3s-control-plane/${TIMESTAMP}"
REMOTE_TARBALL="/tmp/k3s-control-plane-backup-${TIMESTAMP}.tgz"

# Always restart k3s on exit, even if the backup fails between stop and start.
trap 'ssh "$SSH_USER@$SERVER_HOST" "sudo systemctl start k3s.service" || true' EXIT

mkdir -p "$BACKUP_DIR"

echo "=== k3s control-plane backup ==="
echo "  Server: $SERVER_HOST"
echo ""

# ============================================================
# Step 1: Stop k3s and create a consistent tarball
# ============================================================
echo "--- Step 1: Stopping k3s and creating consistent tarball ---"
ssh "$SSH_USER@$SERVER_HOST" "sudo systemctl stop k3s.service"
ssh "$SSH_USER@$SERVER_HOST" "sudo bash -c 'tar czf $REMOTE_TARBALL /var/lib/rancher/k3s/server/db/state.db* /var/lib/rancher/k3s/server/cred/ /var/lib/rancher/k3s/server/tls/'"
ssh "$SSH_USER@$SERVER_HOST" "sudo systemctl start k3s.service"
echo "  k3s stopped, tarball created, k3s restarted"
echo ""

# ============================================================
# Step 2: Fetch tarball locally
# ============================================================
echo "--- Step 2: Fetching tarball locally ---"
scp "$SSH_USER@$SERVER_HOST:$REMOTE_TARBALL" "$BACKUP_DIR/"
echo "  Tarball saved to: $BACKUP_DIR/"
echo ""

# ============================================================
# Step 3: Clean up remote tarball
# ============================================================
echo "--- Step 3: Cleaning up remote tarball ---"
ssh "$SSH_USER@$SERVER_HOST" "sudo rm -f '$REMOTE_TARBALL'"
echo "  Remote tarball removed"
echo ""

echo "=== Done ==="
echo "  Backup written to: $BACKUP_DIR/"
echo "  Restore with: ./scripts/restore-k3s-control-plane.sh"