#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CA_DIR="certs/ca"
CA_KEY="$CA_DIR/ca.key"
CA_CERT="$CA_DIR/ca.crt"
CA_DAYS=3650
CERT_DAYS=365

mkdir -p "$CA_DIR"

usage() {
  echo "Usage: $0 [hostname] [--san <san>...]" >&2
  echo "" >&2
  echo "Without arguments: create (or check) the private CA." >&2
  echo "With hostname:     generate a certificate for that hostname, signed by the CA." >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0                              # create CA (idempotent)" >&2
  echo "  $0 cockpit.nuc-i7...            # cert with one SAN" >&2
  echo "  $0 cockpit.nuc-i7... --san nuc-i7...  # cert with extra SAN" >&2
  exit 1
}

# ============================================================
# Phase 1: Create CA (once, idempotent)
# ============================================================
create_ca() {
  if [ -f "$CA_KEY" ]; then
    echo "  CA already exists: $CA_KEY"
    return
  fi

  echo "  Generating CA key..."
  openssl genrsa -out "$CA_KEY" 4096
  echo "  Generating CA certificate..."
  openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days "$CA_DAYS" \
    -out "$CA_CERT" \
    -subj "/C=FR/O=Homelab/CN=Homelab Private CA"
  echo "  CA created: $CA_CERT"
}

# ============================================================
# Phase 2: Generate a signed certificate for a hostname
# ============================================================
generate_cert() {
  local HOSTNAME="$1"
  shift
  local SANS=("$HOSTNAME")

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --san) SANS+=("$2"); shift 2 ;;
      *) echo "Error: Unknown option: $1" >&2; usage ;;
    esac
  done

  if [ ! -f "$CA_KEY" ]; then
    echo "Error: CA not found. Run '$0' first to create the CA." >&2
    exit 1
  fi

  local CERT_KEY="$CA_DIR/$HOSTNAME.key"
  local CERT_CSR="$CA_DIR/$HOSTNAME.csr"
  local CERT_CRT="$CA_DIR/$HOSTNAME.crt"
  local CERT_EXT="$CA_DIR/$HOSTNAME.ext"

  if [ -f "$CERT_KEY" ] && [ -f "$CERT_CRT" ]; then
    echo "  Certificate already exists: $CERT_CRT"
    return
  fi

  echo "  Generating key for $HOSTNAME..."
  openssl genrsa -out "$CERT_KEY" 2048

  echo "  Generating CSR..."
  openssl req -new -key "$CERT_KEY" -out "$CERT_CSR" \
    -subj "/CN=$HOSTNAME"

  echo "  Creating SAN config..."
  {
    echo "authorityKeyIdentifier=keyid,issuer"
    echo "basicConstraints=CA:FALSE"
    echo "keyUsage=digitalSignature,keyEncipherment"
    echo "extendedKeyUsage=serverAuth"
    echo "subjectAltName=@alt_names"
    echo ""
    echo "[alt_names]"
    for i in "${!SANS[@]}"; do
      echo "DNS.$((i+1)) = ${SANS[$i]}"
    done
  } > "$CERT_EXT"

  echo "  Signing certificate..."
  openssl x509 -req -in "$CERT_CSR" -CA "$CA_CERT" -CAkey "$CA_KEY" \
    -CAcreateserial -out "$CERT_CRT" -days "$CERT_DAYS" \
    -sha256 -extfile "$CERT_EXT"

  echo "  Certificate created: $CERT_CRT"
  echo ""
  echo "  To deploy on a server:"
  echo "    scp $CERT_CRT stephane@${HOSTNAME#cockpit.}:/tmp/cockpit.cert"
  echo "    scp $CERT_KEY stephane@${HOSTNAME#cockpit.}:/tmp/cockpit.key"
  echo "    ssh stephane@${HOSTNAME#cockpit.} '"
  echo "      sudo rm -f /etc/cockpit/ws-certs.d/0-self-signed-*.cert"
  echo "      sudo cp /tmp/cockpit.cert /etc/cockpit/ws-certs.d/1-cockpit.cert"
  echo "      sudo cp /tmp/cockpit.key /etc/cockpit/ws-certs.d/1-cockpit.key"
  echo "      sudo systemctl restart cockpit"
  echo "    '"
}

# ============================================================
# Main
# ============================================================
if [ $# -eq 0 ]; then
  create_ca
  echo ""
  echo "To trust this CA on Fedora:"
  echo "  sudo cp $CA_CERT /etc/pki/ca-trust/source/anchors/homelab-ca.crt"
  echo "  sudo update-ca-trust"
  echo ""
  echo "To generate a certificate for a hostname:"
  echo "  $0 <hostname> [--san <san>...]"
  exit 0
fi

case "$1" in
  --help|-h) usage ;;
  *) generate_cert "$@" ;;
esac
