#!/usr/bin/env bash
set -euo pipefail

# Provisioning script for the Forgejo Actions runner LXC instance.
# Runs INSIDE the instance as root (pushed and executed by scripts/provision.sh).
#
# Sets up, following the official Forgejo docs (installation from binary +
# Podman socket + systemd + offline registration):
#   - a dedicated `runner` system user with linger enabled;
#   - the user-level podman.socket (docker-compatible API) for the runner;
#   - the forgejo-runner binary;
#   - the runner configuration pushed at /root/runner-config.yml (uuid + token
#     come from the offline registration done by scripts/provision.sh);
#   - a forgejo-runner systemd service.

RUNNER_USER="runner"
RUNNER_VERSION="13.1.0"
ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
RUNNER_HOME="/home/${RUNNER_USER}"
CONFIG="/root/runner-config.yml"
BIN_URL="https://code.forgejo.org/forgejo/runner/releases/download/v${RUNNER_VERSION}/forgejo-runner-${RUNNER_VERSION}-linux-${ARCH}"

echo "=== forgejo-runner provisioning on $(hostname) ==="

if [ ! -s "${CONFIG}" ]; then
  echo "ERROR: missing runner configuration at ${CONFIG}" >&2
  exit 1
fi

echo "  Creating system user '${RUNNER_USER}'..."
id "${RUNNER_USER}" >/dev/null 2>&1 || useradd --create-home "${RUNNER_USER}"
RUNNER_UID="$(id -u "${RUNNER_USER}")"

echo "  Enabling linger for '${RUNNER_USER}'..."
loginctl enable-linger "${RUNNER_USER}"

echo "  Installing forgejo-runner v${RUNNER_VERSION} (${ARCH})..."
if [ ! -x /usr/local/bin/forgejo-runner ]; then
  curl -fsSL -o /usr/local/bin/forgejo-runner "${BIN_URL}"
  chmod +x /usr/local/bin/forgejo-runner
fi
/usr/local/bin/forgejo-runner --version

echo "  Enabling podman.socket for '${RUNNER_USER}'..."
systemctl --user -M "${RUNNER_USER}@" enable --now podman.socket

SOCKET="/run/user/${RUNNER_UID}/podman/podman.sock"
echo "  Podman socket: ${SOCKET}"

echo "  Installing runner configuration..."
install -o "${RUNNER_USER}" -g "${RUNNER_USER}" -m 0600 \
  "${CONFIG}" "${RUNNER_HOME}/runner-config.yml"
CONFIG="${RUNNER_HOME}/runner-config.yml"

echo "  Writing forgejo-runner systemd service..."
cat > /etc/systemd/system/forgejo-runner.service <<EOF
[Unit]
Description=Forgejo Runner (forgejo-runner1)
After=network-online.target
Wants=network-online.target

[Service]
User=${RUNNER_USER}
Group=${RUNNER_USER}
Type=simple
ExecStart=/usr/local/bin/forgejo-runner daemon --config ${CONFIG}
WorkingDirectory=${RUNNER_HOME}
Restart=always
RestartSec=5
Environment=HOME=${RUNNER_HOME}
Environment=XDG_RUNTIME_DIR=/run/user/${RUNNER_UID}
Environment=DOCKER_HOST=unix://${SOCKET}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable forgejo-runner.service
# Always (re)start: `enable --now` would not reload the config on a runner that
# is already running, so a re-provision would silently keep the old settings.
systemctl restart forgejo-runner.service

rm -f /root/runner-config.yml /root/provision-runner.sh

echo ""
echo "=== Done ==="
echo "  Runner 'forgejo-runner1' configured (labels: ubuntu-latest)"
echo "  Logs: journalctl -u forgejo-runner -f"
