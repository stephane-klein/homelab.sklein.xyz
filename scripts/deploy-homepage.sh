#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="homepage"

echo "=== Deploying Homepage ==="

helm repo add jameswynn https://jameswynn.github.io/helm-charts --force-update > /dev/null
helm upgrade --install homepage jameswynn/homepage \
  --namespace "$NAMESPACE" --create-namespace \
  -f config/homepage/values.yaml > /dev/null

echo "  Patching deployment to mount host /var for disk gauge..."
if kubectl get deployment homepage -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.volumes[*].name}' | grep -q host-var; then
  echo "  Volume host-var already exists, skipping patch."
else
  kubectl patch deployment homepage -n "$NAMESPACE" --type json -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/volumeMounts/-",
      "value": {
        "name": "host-var",
        "mountPath": "/host/var",
        "readOnly": true
      }
    },
    {
      "op": "add",
      "path": "/spec/template/spec/volumes/-",
      "value": {
        "name": "host-var",
        "hostPath": {
          "path": "/var"
        }
      }
    }
  ]' > /dev/null
fi

echo "  Waiting for Homepage to be ready..."
sleep 2
kubectl rollout status deployment homepage \
  -n "$NAMESPACE" --timeout=180s > /dev/null

echo ""
echo "=== Done ==="
echo "  https://homepage.sklein.internal"
