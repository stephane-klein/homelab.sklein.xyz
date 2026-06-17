#!/bin/bash

set -euo pipefail

echo "Running gitleaks to check for secrets leaks..."
gitleaks dir --no-banner -v "$(cd "$(dirname "$0")/.." && pwd)"
echo "No leaks detected by gitleaks."
