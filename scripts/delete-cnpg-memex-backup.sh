#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <backup-name>"
  echo ""
  echo "Available backups:"
  kubectl get backup -n memex
  exit 1
fi

kubectl delete backup "$1" -n memex
