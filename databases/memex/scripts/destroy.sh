#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

helmfile -f helmfile.yaml destroy