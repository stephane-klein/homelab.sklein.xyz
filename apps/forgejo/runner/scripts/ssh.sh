#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

INSTANCE="forgejo-runner1"

echo "=== SSH into ${INSTANCE} ==="

incus exec "incus1:${INSTANCE}" -- su - fedora
