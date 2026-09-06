#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../build-images"

ALIAS="forgejo-runner"

for f in \
  dist-fedora-lxc/incus.tar.xz \
  dist-fedora-lxc/rootfs.squashfs; do
  test -f "$f" || { echo "ERROR: missing $f (run build-image first)" >&2; exit 1; }
done

echo "=== Generating simplestreams index and publishing to incus-images bucket ==="

rm -rf .simplestreams && mkdir -p .simplestreams
(
  cd .simplestreams
  incus-simplestreams add --alias "${ALIAS}" ../dist-fedora-lxc/incus.tar.xz ../dist-fedora-lxc/rootfs.squashfs
)

export RCLONE_S3_ACCESS_KEY_ID="$(gopass show -o homelab/incus-images/SCW_ACCESS_KEY)"
export RCLONE_S3_SECRET_ACCESS_KEY="$(gopass show -o homelab/incus-images/SCW_SECRET_KEY)"

rclone sync .simplestreams/ :s3:incus-images \
  --s3-provider Scaleway \
  --s3-endpoint https://s3.fr-par.scw.cloud \
  --s3-region fr-par \
  --s3-acl public-read \
  --log-level ERROR \
  --progress

echo ""
echo "=== Done ==="
echo "  Image published: https://incus-images.s3.fr-par.scw.cloud (alias: ${ALIAS})"
