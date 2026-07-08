#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Destroying public Traefik ==="
helm uninstall traefik-public --namespace traefik 2>/dev/null || true

echo "=== Done ==="
