#!/bin/bash

set -euo pipefail

JJ_REPO_CONFIG="$(cd "$(dirname "$0")/.." && pwd)/.jj/repo/config.toml"

if [ ! -d "$(dirname "$JJ_REPO_CONFIG")" ]; then
    echo "Error: .jj/repo directory not found"
    exit 1
fi

echo "Setting up jj publish alias..."

jj config set --repo aliases.publish '["util", "exec", "--", "bash", "-c", "jj bookmark set main -r @- && cd \"$(jj root)\" && scripts/gitleaks-check-push.sh && jj git push"]'

echo "  -> jj publish alias written to $JJ_REPO_CONFIG"
echo ""
echo "Done."
