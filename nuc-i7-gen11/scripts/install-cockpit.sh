#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Required env: NETBIRD_API_TOKEN (loaded via mise from .secret)
# Optional env with defaults: SERVER, SSH_USER, COCKPIT_DOMAIN

SERVER="${SERVER:-nuc-i7-gen11.homelab.stephane-klein.info}"
SSH_USER="${SSH_USER:-stephane}"
COCKPIT_DOMAIN="${COCKPIT_DOMAIN:-cockpit.nuc-i7-gen11.homelab.stephane-klein.info}"

export SERVER SSH_USER COCKPIT_DOMAIN

if [ -z "${NETBIRD_API_TOKEN:-}" ]; then
  echo "Error: NETBIRD_API_TOKEN is not set" >&2
  echo "Load it via mise: mise x -- $0" >&2
  exit 1
fi

echo "=== Cockpit Installation for $SERVER ==="
echo ""

# ============================================================
# Phase 1: Install and configure before reboot
# ============================================================
echo "--- Phase 1: Installation and configuration ---"
set +e
minijinja-cli --env _payload_install-cockpit-phase1.sh | ssh "$SSH_USER@$SERVER" 'sudo bash -s'
PHASE1_EXIT=$?
set -e

if [ "$PHASE1_EXIT" -eq 0 ]; then
  echo "  No reboot needed."
else
  echo "  Rebooting..."
  echo ""
  echo "--- Phase 2: Post-reboot configuration ---"
  echo "  Waiting for host to come back up..."

  MAX_ATTEMPTS=30
  for i in $(seq 1 "$MAX_ATTEMPTS"); do
    if ssh -o ConnectTimeout=10 "$SSH_USER@$SERVER" "uptime" > /dev/null 2>&1; then
      echo "  Host is back online."
      break
    fi
    echo "    Waiting... attempt $i/$MAX_ATTEMPTS"
    sleep 10

    if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
      echo "Error: Host did not come back after reboot" >&2
      exit 1
    fi
  done

  echo "  Configuring firewall..."
  minijinja-cli --env _payload_install-cockpit-phase2.sh | ssh "$SSH_USER@$SERVER" 'sudo bash -s'
fi

# ============================================================
# Phase 3: Deploy CA-signed certificate
# ============================================================
echo ""
echo "--- Phase 3: TLS certificate ---"

CA_SCRIPT="../../scripts/setup-ca.sh"
CA_DIR="../../certs/ca"

if [ -f "$CA_DIR/ca.crt" ]; then
  echo "  Generating signed certificate for $COCKPIT_DOMAIN..."
  "$CA_SCRIPT" "$COCKPIT_DOMAIN" --san "$SERVER"

  echo "  Deploying to $SERVER..."
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
    "$CA_DIR/$COCKPIT_DOMAIN.crt" "$SSH_USER@$SERVER:/tmp/cockpit.cert"
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
    "$CA_DIR/$COCKPIT_DOMAIN.key" "$SSH_USER@$SERVER:/tmp/cockpit.key"
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
    "$SSH_USER@$SERVER" '
    sudo rm -f /etc/cockpit/ws-certs.d/0-self-signed-*.cert
    sudo cp /tmp/cockpit.cert /etc/cockpit/ws-certs.d/1-cockpit.cert
    sudo cp /tmp/cockpit.key /etc/cockpit/ws-certs.d/1-cockpit.key
    sudo systemctl restart cockpit
  '
  echo "  Certificate deployed."
else
  echo "  No private CA found (certs/ca/)."
  echo "  Run 'setup-ca.sh' first to create one."
fi

# ============================================================
# Phase 4: Create DNS zone + CNAME via Netbird API
# ============================================================
echo ""
echo "--- Phase 3: Netbird DNS configuration ---"

echo "  Cleaning up old DNS routes..."
OLD_ROUTES=$(curl -s -X GET "https://api.netbird.io/api/routes" \
  -H 'Accept: application/json' \
  -H "Authorization: Token $NETBIRD_API_TOKEN")
echo "$OLD_ROUTES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for r in data:
    if '$COCKPIT_DOMAIN' in r.get('domains', []):
        print(r['id'])
" 2>/dev/null | while read -r RID; do
  curl -s -X DELETE "https://api.netbird.io/api/routes/$RID" \
    -H "Authorization: Token $NETBIRD_API_TOKEN" > /dev/null
  echo "  Deleted old route: $RID"
done

echo "  Getting groups..."
GROUPS_RESPONSE=$(curl -s -X GET "https://api.netbird.io/api/groups" \
  -H 'Accept: application/json' \
  -H "Authorization: Token $NETBIRD_API_TOKEN")
ALL_GROUP_IDS=$(echo "$GROUPS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ids = [g['id'] for g in data]
print(json.dumps(ids))
" 2>/dev/null || echo "[]")

echo "  Creating DNS zone for '$SERVER'..."
ZONE_RESPONSE=$(curl -s -X GET "https://api.netbird.io/api/dns/zones" \
  -H 'Accept: application/json' \
  -H "Authorization: Token $NETBIRD_API_TOKEN")
ZONE_ID=$(echo "$ZONE_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for z in data:
    if z.get('domain') == '$SERVER':
        print(z['id'])
        break
" 2>/dev/null || echo "")

if [ -z "$ZONE_ID" ]; then
  CREATE_ZONE_RESPONSE=$(curl -s -X POST "https://api.netbird.io/api/dns/zones" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Token $NETBIRD_API_TOKEN" \
    -d "$(cat <<EOF
{
  "name": "${SERVER%%.*}",
  "domain": "$SERVER",
  "enabled": true,
  "enable_search_domain": false,
  "distribution_groups": $ALL_GROUP_IDS
}
EOF
)")
  ZONE_ID=$(echo "$CREATE_ZONE_RESPONSE" | python3 -c "
import sys, json
print(json.load(sys.stdin).get('id', ''))
" 2>/dev/null || echo "")
  if [ -z "$ZONE_ID" ]; then
    echo "  Error: Failed to create DNS zone." >&2
    echo "  Response: $CREATE_ZONE_RESPONSE" >&2
    exit 1
  fi
  echo "  Zone created: $ZONE_ID"
else
  echo "  Zone found: $ZONE_ID"
fi

echo "  Checking if CNAME record already exists..."
EXISTING_RECORDS=$(curl -s -X GET "https://api.netbird.io/api/dns/zones/${ZONE_ID}/records" \
  -H 'Accept: application/json' \
  -H "Authorization: Token $NETBIRD_API_TOKEN")
EXISTING_RECORD_ID=$(echo "$EXISTING_RECORDS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for r in data:
    if r.get('name') == '$COCKPIT_DOMAIN':
        print(r['id'])
        break
" 2>/dev/null || echo "")

if [ -n "$EXISTING_RECORD_ID" ]; then
  echo "  Updating existing CNAME record..."
  curl -s -X PUT "https://api.netbird.io/api/dns/zones/${ZONE_ID}/records/${EXISTING_RECORD_ID}" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Token $NETBIRD_API_TOKEN" \
    -d "$(cat <<EOF
{
  "name": "$COCKPIT_DOMAIN",
  "type": "CNAME",
  "content": "$SERVER",
  "ttl": 300
}
EOF
)" > /dev/null
  echo "  CNAME record updated."
else
  echo "  Creating CNAME record: $COCKPIT_DOMAIN -> $SERVER..."
  CREATE_RECORD_RESPONSE=$(curl -s -X POST "https://api.netbird.io/api/dns/zones/${ZONE_ID}/records" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Token $NETBIRD_API_TOKEN" \
    -d "$(cat <<EOF
{
  "name": "$COCKPIT_DOMAIN",
  "type": "CNAME",
  "content": "$SERVER",
  "ttl": 300
}
EOF
)")
  RECORD_ID=$(echo "$CREATE_RECORD_RESPONSE" | python3 -c "
import sys, json
print(json.load(sys.stdin).get('id', ''))
" 2>/dev/null || echo "")
  if [ -n "$RECORD_ID" ]; then
    echo "  CNAME record created: $RECORD_ID"
  else
    echo "  Error: Failed to create CNAME record." >&2
    echo "  Response: $CREATE_RECORD_RESPONSE" >&2
    exit 1
  fi
fi

echo ""
echo "=== Done ==="
echo "  Access Cockpit at: https://$COCKPIT_DOMAIN:9090"
echo "  (only reachable via Netbird VPN)"
