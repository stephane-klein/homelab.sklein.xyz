#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

INSTANCE="forgejo-runner1"
REMOTE="incus1"
NAMESPACE="forgejo"
FORGEJO_URL="https://forgejo.sklein.internal/"
SECRET_PATH="homelab/forgejo/actions/runner-secret"
UUID_PATH="homelab/forgejo/actions/runner-uuid"

TMP_CONFIG="$(mktemp)"
trap 'rm -f "${TMP_CONFIG}"' EXIT

echo "=== Provisioning forgejo-runner in ${REMOTE}:${INSTANCE} ==="

# Offline registration secret (40 hex chars, stable across re-provisioning).
if ! SECRET="$(gopass show -o "${SECRET_PATH}" 2>/dev/null)"; then
  echo "  Generating runner secret (40 hex)..."
  SECRET="$(openssl rand -hex 20)"
  printf '%s' "${SECRET}" | gopass insert -f "${SECRET_PATH}"
else
  echo "  Using existing runner secret from Gopass"
fi

# Runner UUID, obtained once via Forgejo's offline registration CLI. Stored in
# Gopass so later provisions reuse it (idempotent).
if ! UUID="$(gopass show -o "${UUID_PATH}" 2>/dev/null)"; then
  echo "  Registering runner offline with Forgejo..."
  UUID="$(kubectl exec -n "${NAMESPACE}" deploy/forgejo -- \
    forgejo forgejo-cli actions register \
    --name "${INSTANCE}" \
    --secret "${SECRET}" 2>/dev/null | tail -1)"
  if [ -z "${UUID}" ]; then
    echo "ERROR: forgejo-cli actions register returned no UUID" >&2
    exit 1
  fi
  printf '%s' "${UUID}" | gopass insert -f "${UUID_PATH}"
else
  echo "  Using existing runner UUID from Gopass"
fi

echo "  Rendering runner-config.yml..."
export FORGEJO_URL RUNNER_UUID="${UUID}" RUNNER_TOKEN="${SECRET}"
minijinja-cli -a none --env config/runner-config.yml.j2 > "${TMP_CONFIG}"

echo "  Pushing files to ${REMOTE}:${INSTANCE}..."
incus file push --mode 0600 "${TMP_CONFIG}" "${REMOTE}:${INSTANCE}/root/runner-config.yml"
incus file push scripts/provision-runner.sh "${REMOTE}:${INSTANCE}/root/provision-runner.sh"

echo "  Running provision-runner.sh inside the instance..."
incus exec "${REMOTE}:${INSTANCE}" -- /bin/bash /root/provision-runner.sh

echo ""
echo "=== Done ==="
echo "  Watch:  mise run //apps/forgejo/runner:logs"
echo "  Verify: https://forgejo.sklein.internal/admin/actions/runners"
