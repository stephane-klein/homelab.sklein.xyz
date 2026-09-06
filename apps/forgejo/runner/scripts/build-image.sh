#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../build-images"

IMAGE_NAME="forgejo-runner"

# The local incus client talks to the daemon as the current user (no sudo).
# distrobuilder, on the other hand, must run as root and through systemd-run,
# where PATH is reset (secure_path): resolve its absolute path up-front.
INCUS_BIN="$(mise which incus)"
DISTROBUILDER_BIN="$(mise which distrobuilder)"
test -x "${INCUS_BIN}" || { echo "ERROR: incus binary not found: ${INCUS_BIN}" >&2; exit 1; }
test -x "${DISTROBUILDER_BIN}" || { echo "ERROR: distrobuilder binary not found: ${DISTROBUILDER_BIN}" >&2; exit 1; }

echo "=== Building Fedora LXC image '${IMAGE_NAME}' with distrobuilder ==="

"${INCUS_BIN}" image delete "${IMAGE_NAME}-container" >/dev/null 2>&1 || true

sudo systemd-run --scope --quiet \
  -p CPUQuota=200% \
  -p MemoryHigh=6G \
  -p MemoryMax=10G \
  -p IOWeight=1 \
  -- "${DISTROBUILDER_BIN}" build-incus fedora.yaml dist-fedora-lxc \
  --sources-dir .distrobuilder-sources \
  --import-into-incus="${IMAGE_NAME}-container"

sudo chown -R "$USER:$USER" dist-fedora-lxc

echo ""
echo "=== Done ==="
echo "  Image alias: ${IMAGE_NAME}-container (local Incus daemon)"
echo "  Next:        mise run //apps/forgejo/runner:upload-image"
ls -lha dist-fedora-lxc/
