#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying private container registry ==="

# Extend this list to add more registry users. Each user must have a Gopass
# entry homelab/registry/<user>/htpasswd (bcrypt line, e.g. "user:$2y$...").
REGISTRY_USERS=("stephane")

echo "  Reading htpasswd entries from Gopass for users: ${REGISTRY_USERS[*]}"
htpasswd_lines=()
for user in "${REGISTRY_USERS[@]}"; do
  entry="$(gopass show -o "homelab/registry/${user}/htpasswd")"
  if [ -z "$entry" ]; then
    echo "Error: empty gopass entry homelab/registry/${user}/htpasswd" >&2
    exit 1
  fi
  htpasswd_lines+=("$entry")
done

export REGISTRY_HTPASSWD
REGISTRY_HTPASSWD="$(printf '%s\n' "${htpasswd_lines[@]}")"

echo "  Applying helmfile..."
helmfile -f helmfile.yaml.gotmpl apply

echo ""
echo "=== Done ==="
echo "  Registry: https://registry.sklein.internal (HTTP basic auth)"
echo "  Next steps (run manually):"
echo "    1. ./scripts/configure-k3s-registry.sh   # node pull auth (containerd)"
echo "    2. podman login registry.sklein.internal"
echo "    3. podman push registry.sklein.internal/<image>:<tag>"
