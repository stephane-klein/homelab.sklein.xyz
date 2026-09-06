#!/usr/bin/env bash
set -euo pipefail

# Create (or refresh) a Forgejo personal access token with the scopes needed
# by the container registry, and store it in Gopass at
# `homelab/forgejo/container-registry-token`.
#
# This token is used by:
#   - k3s nodes pull auth: ./scripts/configure-k3s-registry.sh
#   - manual podman/docker push/pull on forgejo.sklein.internal
#
# Usage: $0 [--username stephane-klein]

FORGEJO_USERNAME="${FORGEJO_USERNAME:-stephane-klein}"

# Existing token: rotate only if explicitly requested with --force.
if [ "${1:-}" != "--force" ] && gopass show -o homelab/forgejo/container-registry-token > /dev/null 2>&1; then
  echo "A token already exists in Gopass (homelab/forgejo/container-registry-token)."
  echo "Re-run with --force to rotate it (workloads pulling images will need a"
  echo "re-run of ./scripts/configure-k3s-registry.sh afterwards)."
  exit 0
fi

echo "=== Generating container-registry token for ${FORGEJO_USERNAME} ==="
TOKEN="$(kubectl exec -n forgejo deploy/forgejo -- forgejo admin user generate-access-token \
  -u "${FORGEJO_USERNAME}" \
  -t container-registry \
  --scopes "read:package,write:package" \
  --raw 2>/dev/null | tail -1)"

if [ -z "${TOKEN}" ]; then
  echo "Error: failed to generate the token. Check the Forgejo admin username." >&2
  exit 1
fi

echo "  Storing in Gopass (homelab/forgejo/container-registry-token)..."
printf '%s' "${TOKEN}" | gopass insert -f homelab/forgejo/container-registry-token

echo ""
echo "=== Done ==="
echo "  Token stored. Configure k3s node pull auth with:"
echo "    ./scripts/configure-k3s-registry.sh"
