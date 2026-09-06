#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

export NETBIRD_SETUP_KEY="$(gopass show -o netbird/setup-keys/incus-auto-group)"
export HOMELAB_CA_B64="$(gopass cat homelab/certs/ca/ca.crt | base64 -w0)"

minijinja-cli -a none --env instance.yaml.j2 > instance.yaml

echo "Generated instance.yaml"
