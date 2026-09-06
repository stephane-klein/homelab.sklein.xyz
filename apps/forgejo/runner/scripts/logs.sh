#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

INSTANCE="forgejo-runner1"

echo "=== forgejo-runner logs (${INSTANCE}) ==="

incus exec "incus1:${INSTANCE}" -- journalctl -u forgejo-runner -f
