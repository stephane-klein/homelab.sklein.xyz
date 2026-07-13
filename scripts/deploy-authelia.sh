#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

echo "=== Deploying Authelia ==="

USERS_FILE="config/authelia/users.yml"

if [ -f "$USERS_FILE" ]; then
  echo "  Using existing users file: $USERS_FILE"
else
  echo "  $USERS_FILE not found, generating from AUTHELIA_PASSWORD..."

  echo "  Loading AUTHELIA_PASSWORD..."
  if [ -z "${AUTHELIA_PASSWORD:-}" ]; then
    if [ -f ".secret" ]; then
      AUTHELIA_PASSWORD=$(grep '^AUTHELIA_PASSWORD=' ".secret" | cut -d'"' -f2)
    fi
  fi
  if [ -z "${AUTHELIA_PASSWORD:-}" ]; then
    echo "  ERROR: AUTHELIA_PASSWORD is not set and not found in .secret"
    echo "  Create $USERS_FILE manually or set AUTHELIA_PASSWORD in .secret"
    exit 1
  fi

  echo "  Hashing password with Argon2..."
  if command -v podman &>/dev/null; then
    runner="podman"
  elif command -v docker &>/dev/null; then
    runner="docker"
  else
    echo "  ERROR: Neither podman nor docker found"
    exit 1
  fi

  $runner pull authelia/authelia:4.38 > /dev/null 2>&1 || true
  output=$($runner run --rm authelia/authelia:4.38 authelia crypto hash generate \
    --password "$AUTHELIA_PASSWORD" 2>&1)
  hash=$(echo "$output" | sed -n 's/^\(Password hash\|Digest\): //p')
  if [ -z "$hash" ]; then
    echo "  ERROR: Failed to generate password hash."
    exit 1
  fi

  cat > "$USERS_FILE" <<USERS_EOF
users:
  stephane:
    disabled: false
    displayname: "Stephane Klein"
    password: "$hash"
    email: contact@stephane-klein.info
    groups:
      - admins
    given_name: "Stephane"
    family_name: "Klein"
    gender: male
    locale: fr-FR
    zoneinfo: Europe/Paris
USERS_EOF
  echo "  Generated $USERS_FILE (gitignored)"
fi

echo "  Creating users ConfigMap..."
kubectl create configmap authelia-users \
  --namespace authelia --dry-run=client -o yaml \
  --from-file=users.yml="$USERS_FILE" | kubectl apply -f - > /dev/null

echo "  Creating namespace..."
kubectl create namespace authelia --dry-run=client -o yaml | kubectl apply -f - > /dev/null

echo "  Installing Authelia with Helm..."
JWKS_TMP=$(mktemp)
trap "rm -f '$JWKS_TMP'" EXIT
echo "$AUTHELIA_JWKS_PRIVATE_KEY" | base64 -d > "$JWKS_TMP"

helm repo add authelia https://charts.authelia.com --force-update > /dev/null
helm upgrade --install authelia authelia/authelia \
  --namespace authelia --create-namespace \
  -f config/authelia/values.yaml \
  --set configMap.identity_providers.oidc.hmac_secret.value="$AUTHELIA_OIDC_HMAC_SECRET" \
  --set-file configMap.identity_providers.oidc.jwks[0].key.value="$JWKS_TMP" \
  > /dev/null

echo "  Waiting for Authelia to be ready..."
kubectl wait --for=condition=Ready pod \
  -n authelia -l app.kubernetes.io/instance=authelia \
  --timeout=180s > /dev/null

echo "  Creating Traefik ForwardAuth Middleware..."
kubectl apply -f - > /dev/null <<'EOF'
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: forwardauth-authelia
  namespace: traefik
spec:
  forwardAuth:
    address: http://authelia.authelia.svc.cluster.local/api/authz/forward-auth
    trustForwardHeader: true
    authResponseHeaders:
      - Remote-User
      - Remote-Groups
      - Remote-Email
      - Remote-Name
EOF

echo ""
echo "=== Done ==="
echo "  https://auth.sklein.internal"
echo ""
echo "  Users file: $USERS_FILE (edit and re-run deploy to update)"
echo "  To protect an app, add this annotation to its Ingress:"
echo "    traefik.ingress.kubernetes.io/router.middlewares: traefik-forwardauth-authelia@kubernetescrd"
