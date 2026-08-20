#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

set +e
helmfile -f helmfile.yaml diff --detailed-exitcode
code=$?
set -e

if [ $code -eq 0 ]; then
  echo "No drift: deployed release matches chart/values."
elif [ $code -eq 2 ]; then
  echo "Drift detected: see the diff above."
fi

exit $code
