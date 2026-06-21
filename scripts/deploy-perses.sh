#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="perses"

echo "=== Deploying Perses ==="

helm repo add perses https://perses.github.io/helm-charts --force-update > /dev/null
helm upgrade --install perses perses/perses \
  --namespace "$NAMESPACE" --create-namespace \
  -f config/perses/values.yaml > /dev/null

echo "  Waiting for Perses to be ready..."
kubectl wait --for=condition=Ready pod \
  -n "$NAMESPACE" -l app.kubernetes.io/instance=perses \
  --timeout=180s > /dev/null

echo ""
echo "=== Fixing config leading newline (Helm chart workaround) ==="
kubectl get configmap -n "$NAMESPACE" perses -o json | python3 -c "
import json, sys
cm = json.load(sys.stdin)
raw = cm['data']['config.yaml']
cm['data']['config.yaml'] = raw.lstrip('\n')
json.dump(cm, sys.stdout)
" | kubectl apply -f - > /dev/null
kubectl rollout restart statefulset -n "$NAMESPACE" perses > /dev/null 2>&1
echo "  Restarting Perses..."
kubectl wait --for=condition=Ready pod \
  -n "$NAMESPACE" -l app.kubernetes.io/instance=perses \
  --timeout=180s > /dev/null

echo ""
echo "=== Creating datasource ==="
kubectl apply -f - > /dev/null <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: perses-datasource
  namespace: perses
  labels:
    perses.dev/resource: "true"
data:
  datasource.yaml: |
    kind: GlobalDatasource
    metadata:
      name: prometheus-datasource
    spec:
      default: true
      plugin:
        kind: PrometheusDatasource
        spec:
          proxy:
            kind: HTTPProxy
            spec:
              url: http://victoria-metrics-victoria-metrics-single-server.victoria-metrics.svc:8428
EOF

echo ""
echo "=== Creating homelab project ==="
kubectl apply -f - > /dev/null <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: perses-project-dev
  namespace: perses
  labels:
    perses.dev/resource: "true"
data:
  project.yaml: |
    kind: Project
    metadata:
      name: homelab
EOF

echo ""
./scripts/deploy-custom-dashboards.sh

echo ""
echo "=== Done ==="
echo "  https://perses.sklein.internal"
