#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

# The kubelet reads `seccompProfile.localhostProfile` from
# <kubelet root directory>/seccomp. On k3s the kubelet root is
# /var/lib/kubelet, and the chart asks for `profiles/the-artifact-chromium.json`.
#
# The file extends the container runtime's default seccomp profile with
# `clone`, `unshare` and `setns`, the three system calls Chromium's namespace
# sandbox needs. Without it the pod does not start at all
# (`CreateContainerConfigError`, "failed to load seccomp profile").
#
# On Fedora CoreOS /var survives OS updates but not a reinstall, so run this
# again after provisioning a node.

PROFILE="../../config/seccomp/the-artifact-chromium.json"
REMOTE_PROFILE="/var/lib/kubelet/seccomp/profiles/the-artifact-chromium.json"
REMOTE_DIR="$(dirname "$REMOTE_PROFILE")"
NODES=(
  "nuc-i7-gen11.homelab.stephane-klein.info"
  "nuc-i3-gen5.homelab.stephane-klein.info"
)
SSH_USER="${SSH_USER:-stephane}"

if [ ! -f "$PROFILE" ]; then
  echo "Error: $PROFILE not found" >&2
  exit 1
fi

LOCAL_SUM="$(sha256sum "$PROFILE" | cut -d' ' -f1)"

echo "=== Installing the Chromium seccomp profile ==="
echo "  source: $PROFILE"
echo "  target: $REMOTE_PROFILE"

for NODE in "${NODES[@]}"; do
  echo "  $NODE"
  ssh "$SSH_USER@$NODE" \
    "sudo mkdir -p $REMOTE_DIR && sudo tee $REMOTE_PROFILE > /dev/null" \
    < "$PROFILE"
  # The kubelet directories are root-only, so the check runs under sudo too.
  REMOTE_SUM="$(ssh "$SSH_USER@$NODE" "sudo sha256sum $REMOTE_PROFILE" | cut -d' ' -f1)"
  if [ "$REMOTE_SUM" != "$LOCAL_SUM" ]; then
    echo "  Error: checksum mismatch ($REMOTE_SUM != $LOCAL_SUM)" >&2
    exit 1
  fi
  ssh "$SSH_USER@$NODE" "sudo stat -c '  %a %U:%G %n' $REMOTE_PROFILE"
done

echo "=== Done ==="
