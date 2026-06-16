#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

K3S_TOKEN=$(openssl rand -base64 48)

if grep -q "^K3S_TOKEN=" .secret 2>/dev/null; then
  sed -i "s/^K3S_TOKEN=.*/K3S_TOKEN=\"${K3S_TOKEN}\"/" .secret
else
  echo "K3S_TOKEN=\"${K3S_TOKEN}\"" >> .secret
fi

echo "K3S_TOKEN written to .secret"
