#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="the-artifact"

echo "=== Deploying The Artifact ==="

echo "  Ensuring namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

# RustFS root credentials. The chart reads them from this secret, and the
# application reads the same keys as its S3 credentials (values.yaml,
# externalS3.existingSecret). Source of truth: Gopass.
echo "  Ensuring RustFS credentials secret..."
kubectl create secret generic rustfs-credentials \
  -n "$NAMESPACE" \
  --from-literal=RUSTFS_ACCESS_KEY="$(gopass show -o homelab/the-artifact/s3/access-key)" \
  --from-literal=RUSTFS_SECRET_KEY="$(gopass show -o homelab/the-artifact/s3/secret-key)" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

# Application settings. The chart imports the whole secret with envFrom, so the
# keys keep their setting names.
#   ENCRYPTION_KEY  encrypts the keys the server keeps in its database
#   SETUP_CODE      code needed to create the first account (the instance admin)
#   SMTP_PASS       Fastmail app password
echo "  Ensuring application settings secret..."
kubectl create secret generic the-artifact-settings \
  -n "$NAMESPACE" \
  --from-literal=ENCRYPTION_KEY="$(gopass show -o homelab/the-artifact/encryption-key)" \
  --from-literal=SETUP_CODE="$(gopass show -o homelab/the-artifact/setup-code)" \
  --from-literal=SMTP_PASS="$(gopass show -o homelab/the-artifact/smtp-password)" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

# CNPG backups go to the shared Scaleway bucket.
echo "  Ensuring CNPG backup credentials secret..."
kubectl create secret generic the-artifact-cluster-backup-s3-creds \
  -n "$NAMESPACE" \
  --from-literal=ACCESS_KEY_ID="$(gopass show -o homelab/scaleway/CNPG_BACKUPS_ACCESS_KEY)" \
  --from-literal=ACCESS_SECRET_KEY="$(gopass show -o homelab/scaleway/CNPG_BACKUPS_SECRET_KEY)" \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Installing the Chromium seccomp profile on the nodes..."
./scripts/install-seccomp-profile.sh

echo "  Applying Helmfile (CNPG cluster, RustFS, The Artifact)..."
helmfile -f helmfile.yaml apply

echo "  Waiting for the application pod..."
kubectl -n "$NAMESPACE" rollout status deploy/the-artifact --timeout=600s

echo ""
echo "=== Done ==="
echo "  App:      https://artifact.stephane-klein.info"
echo "  Content:  https://artifact-content.stephane-klein.info"
echo "  Setup code: gopass show -o homelab/the-artifact/setup-code"
echo ""
echo "  Next: open the app and create the first account with the setup code."
echo "  It becomes the instance admin. Then, in Server admin, set the sign-up"
echo "  policy to 'invited only' and add a passkey to that account."
