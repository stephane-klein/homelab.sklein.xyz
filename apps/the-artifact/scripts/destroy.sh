#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

# Destructive: removing the CNPG cluster deletes its PersistentVolumeClaims and
# the database with them. The RustFS data PVC is annotated
# `helm.sh/resource-policy: keep`, so the published pages stay on disk; delete
# `pvc/rustfs-data` by hand to start over with an empty bucket.
helmfile -f helmfile.yaml destroy
