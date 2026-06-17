#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying whoami (Authelia demo) ==="

kubectl create deployment whoami-authelia-demo --image=traefik/whoami --port=80 --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl expose deployment whoami-authelia-demo --port=80 --dry-run=client -o yaml | kubectl apply -f - > /dev/null

cat <<EOF | kubectl apply -f - > /dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami-authelia-demo
  annotations:
    cert-manager.io/cluster-issuer: homelab-ca
    traefik.ingress.kubernetes.io/router.middlewares: traefik-forwardauth-authelia@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - whoami-authelia-demo.sklein.internal
    secretName: whoami-authelia-demo-tls
  rules:
  - host: whoami-authelia-demo.sklein.internal
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: whoami-authelia-demo
            port:
              number: 80
EOF

echo "  Waiting for certificate..."
kubectl wait --for=condition=Ready certificate whoami-authelia-demo-tls --timeout=60s > /dev/null 2>&1 || true

echo ""
echo "=== Done ==="
echo "  https://whoami-authelia-demo.sklein.internal"
echo ""
echo "  This app is protected by Authelia."
echo "  Access it and you should be redirected to https://auth.sklein.internal for login."
