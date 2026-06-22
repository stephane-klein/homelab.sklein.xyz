#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying whoami ==="

kubectl create deployment whoami --image=traefik/whoami --port=80 --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl expose deployment whoami --port=80 --dry-run=client -o yaml | kubectl apply -f - > /dev/null

cat <<EOF | kubectl apply -f - > /dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami
  annotations:
    cert-manager.io/cluster-issuer: homelab-ca
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - whoami.sklein.internal
    secretName: whoami-tls
  rules:
  - host: whoami.sklein.internal
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: whoami
            port:
              number: 80
EOF

echo "  Waiting for certificate..."
kubectl wait --for=condition=Ready certificate whoami-tls --timeout=60s > /dev/null 2>&1 || true

echo ""
echo "=== Done ==="
echo "  https://whoami.sklein.internal"
