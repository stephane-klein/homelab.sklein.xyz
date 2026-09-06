#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

REMOTE_SOURCE="sklein"   # simplestreams remote over the Scaleway S3 bucket incus-images
REMOTE_SOURCE_URL="https://incus-images.s3.fr-par.scw.cloud"
REMOTE_TARGET="incus1"   # incus-server1.homelab.stephane-klein.info
ALIAS="forgejo-runner"

echo "=== Ensuring image '${ALIAS}' exists on '${REMOTE_TARGET}' ==="

# incus-apply targets the remote server (incus1:) but passes the image name
# verbatim, so the image must be available *on that server*, not on this host.
# We copy it from the public simplestreams remote 'sklein' (Scaleway S3) into
# incus1 under a stable alias.

# Ensure the 'sklein' simplestreams remote exists on this workstation
# (idempotent).
if ! incus remote list --format csv 2>/dev/null | cut -d, -f1 | grep -qx "${REMOTE_SOURCE}"; then
  echo "  Adding missing remote '${REMOTE_SOURCE}' (simplestreams)..."
  incus remote add "${REMOTE_SOURCE}" "${REMOTE_SOURCE_URL}" --protocol=simplestreams
fi

if incus image list "${REMOTE_TARGET}:" --format csv --columns l 2>/dev/null | grep -qx "${ALIAS}"; then
  echo "  Image '${ALIAS}' already present on ${REMOTE_TARGET}"
  exit 0
fi

echo "  Copying ${REMOTE_SOURCE}:${ALIAS} -> ${REMOTE_TARGET}:${ALIAS} ..."
incus image copy "${REMOTE_SOURCE}:${ALIAS}" "${REMOTE_TARGET}:" \
  --alias "${ALIAS}" --auto-update=false

echo "  Image '${ALIAS}' copied to ${REMOTE_TARGET}"
