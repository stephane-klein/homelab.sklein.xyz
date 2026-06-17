#!/bin/bash

set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)/git-hooks"

echo "Setting up git hooks path..."
git config core.hooksPath git-hooks
echo "  -> git config core.hooksPath = $HOOKS_DIR"

echo ""
echo "Done. Git hook is active."
