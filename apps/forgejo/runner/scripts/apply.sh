#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Applying Forgejo runner LXC instance on incus1 ==="

incus-apply -y instance.yaml incus1:
