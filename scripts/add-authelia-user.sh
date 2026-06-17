#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <username> <password> [display_name]"
  echo ""
  echo "  Add or update a user in Authelia's file-based authentication."
  echo "  Updates config/authelia/users.yml and pushes to the ConfigMap."
  exit 1
fi

username="$1"
password="$2"
display_name="${3:-$username}"

USERS_FILE="config/authelia/users.yml"

echo "=== Adding Authelia user: $username ==="

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
  --password "$password" 2>&1)
hash=$(echo "$output" | sed -n 's/^\(Password hash\|Digest\): //p')
if [ -z "$hash" ]; then
  echo "  ERROR: Failed to generate password hash."
  echo "  Raw output:"
  echo "$output"
  exit 1
fi

echo "  Updating $USERS_FILE..."
if [ ! -f "$USERS_FILE" ]; then
  echo "users: {}" > "$USERS_FILE"
fi

python3 -c "
import sys, yaml

with open('$USERS_FILE') as f:
    data = yaml.safe_load(f) or {'users': {}}

data['users']['$username'] = {
    'displayname': '$display_name',
    'password': '$hash',
    'email': '${username}@sklein.internal',
    'groups': ['users'],
}

with open('$USERS_FILE', 'w') as f:
    yaml.dump(data, f, default_flow_style=False)
"

echo "  Pushing to ConfigMap..."
kubectl create configmap authelia-users \
  --namespace authelia --dry-run=client -o yaml \
  --from-file=users.yml="$USERS_FILE" | kubectl apply -f - > /dev/null

echo ""
echo "=== Done ==="
echo "  User '$username' added/updated in $USERS_FILE and pushed to ConfigMap."
echo "  Authelia will reload users automatically (watch: true)."
