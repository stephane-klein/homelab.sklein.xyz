#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deleting Forgejo runner LXC instance from incus1 (destructive) ==="

incus-apply -d -y instance.yaml incus1:
