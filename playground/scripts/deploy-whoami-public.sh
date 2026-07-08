#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying whoami-public ==="

kubectl create deployment whoami-public --image=traefik/whoami --port=80 --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl expose deployment whoami-public --port=80 --dry-run=client -o yaml | kubectl apply -f - > /dev/null

cat <<EOF | kubectl apply -f - > /dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami-public
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-public
spec:
  ingressClassName: traefik-public
  tls:
  - hosts:
    - whoami.ipv6.ingress.homelab.public.stephane-klein.info
    secretName: whoami-public-tls
  rules:
  - host: whoami.ipv6.ingress.homelab.public.stephane-klein.info
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: whoami-public
            port:
              number: 80
EOF

echo "  Waiting for certificate..."
kubectl wait --for=condition=Ready certificate whoami-public-tls --timeout=120s > /dev/null 2>&1 || true

echo ""
echo "=== Done ==="
echo "  https://whoami.ipv6.ingress.homelab.public.stephane-klein.info"
