#!/usr/bin/env bash
set -euo pipefail

# Provisioning script for the Forgejo Actions runner LXC instance.
# Runs INSIDE the instance as root (pushed and executed by scripts/provision.sh).
#
# Sets up, following the official Forgejo docs (installation from binary +
# Podman socket + systemd + offline registration):
#   - a dedicated `runner` system user;
#   - the system (rootful) podman.socket, made accessible to the runner user;
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

echo "  Installing forgejo-runner v${RUNNER_VERSION} (${ARCH})..."
if [ ! -x /usr/local/bin/forgejo-runner ]; then
  curl -fsSL -o /usr/local/bin/forgejo-runner "${BIN_URL}"
  chmod +x /usr/local/bin/forgejo-runner
fi
/usr/local/bin/forgejo-runner --version

# Rootful podman: distrobuilder (image build) needs mount/mknod, which are
# impossible with the rootless per-user podman. Expose the system socket to the
# runner user instead.
echo "  Enabling the system podman.socket (rootful)..."
mkdir -p /etc/systemd/system/podman.socket.d
cat > /etc/systemd/system/podman.socket.d/override.conf <<EOF
[Socket]
SocketGroup=${RUNNER_USER}
EOF

# /run/podman is created 0700 root:root by /usr/lib/tmpfiles.d/podman.conf,
# which blocks the runner user from reaching the socket. This override runs
# after (zzz- prefix) and makes the directory traversable by the runner group.
cat > /etc/tmpfiles.d/zzz-podman-runner.conf <<EOF
d /run/podman 0750 root ${RUNNER_USER} -
EOF
systemd-tmpfiles --create /etc/tmpfiles.d/zzz-podman-runner.conf

systemctl daemon-reload
systemctl enable podman.socket
systemctl restart podman.socket

SOCKET="/run/podman/podman.sock"
echo "  Podman socket: ${SOCKET}"

echo "  Installing runner configuration..."
install -o "${RUNNER_USER}" -g "${RUNNER_USER}" -m 0600 \
  "${CONFIG}" "${RUNNER_HOME}/runner-config.yml"
CONFIG="${RUNNER_HOME}/runner-config.yml"

echo "  Writing forgejo-runner systemd service..."
cat > /etc/systemd/system/forgejo-runner.service <<EOF
[Unit]
Description=Forgejo Runner (forgejo-runner1)
After=network-online.target podman.socket
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
