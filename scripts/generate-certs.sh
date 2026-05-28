#!/usr/bin/env bash
# Generate a self-signed CA + broker cert for the SASL_SSL listener
# on port 9095. Invoked automatically by `kafka-up --auth` when the
# cert is missing or within 7 days of expiry.
#
# Idempotent: re-running is a no-op if the broker cert exists and is
# valid for more than 7 days. Use --force to regenerate from scratch
# (kafka-reset --force-certs does this too).
#
# Outputs in ../certs/:
#   ca.key                CA private key
#   ca.pem                CA certificate (also doubles as truststore)
#   server.key            broker private key
#   server.crt            broker certificate (signed by ca.pem)
#   server.pem            broker cert + key combined (Kafka PEM keystore)
#   server.p12            PKCS12 bundle for tools that need it
#
# The CA fingerprint is printed so it can be pinned by clients.

set -euo pipefail

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../certs" && pwd)"
DAYS_VALID=3650 # 10 years; we don't want certs to expire mid-demo

force=0
quiet=0
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    --quiet) quiet=1 ;;
    *) echo "usage: $0 [--force] [--quiet]" >&2; exit 2 ;;
  esac
done

log() { [ "$quiet" -eq 1 ] || echo "$@"; }

# Skip regeneration if the broker cert is healthy.
if [ "$force" -eq 0 ] && [ -f "$CERT_DIR/server.crt" ]; then
  if openssl x509 -in "$CERT_DIR/server.crt" -checkend $((7 * 24 * 3600)) -noout >/dev/null 2>&1; then
    log "→ certs already valid (>7 days remaining); skipping. Use --force to regenerate."
    exit 0
  fi
fi

log "→ generating new CA + broker cert (valid ${DAYS_VALID} days)"
cd "$CERT_DIR"

# Clean up any previous artifacts so we don't mix old + new files.
rm -f ca.key ca.pem ca.srl server.key server.crt server.csr server.pem server.p12 server.ext

# ---- CA ----
openssl req -x509 -newkey rsa:4096 -sha256 -days "$DAYS_VALID" -nodes \
  -keyout ca.key \
  -out ca.pem \
  -subj "/CN=kafka-up Dev CA/O=kafka-up/OU=dev-cluster" 2>/dev/null

# ---- Broker key + CSR + signed cert ----
openssl req -new -newkey rsa:4096 -sha256 -nodes \
  -keyout server.key \
  -out server.csr \
  -subj "/CN=localhost/O=kafka-up/OU=dev-cluster" 2>/dev/null

cat > server.ext <<'EXT'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt
[alt]
DNS.1 = localhost
DNS.2 = kafka0
DNS.3 = kafka-up-kafka0
IP.1  = 127.0.0.1
EXT

openssl x509 -req -sha256 -days "$DAYS_VALID" \
  -in server.csr \
  -CA ca.pem -CAkey ca.key -CAcreateserial \
  -extfile server.ext \
  -out server.crt 2>/dev/null

# Combined PEM keystore for Kafka's `ssl.keystore.type=PEM`.
cat server.crt server.key > server.pem

# PKCS12, occasionally useful for tools that won't take PEM.
openssl pkcs12 -export \
  -in server.crt \
  -inkey server.key \
  -name kafka-broker \
  -out server.p12 \
  -passout pass:changeit 2>/dev/null

rm -f server.csr server.ext

# Keep permissions tight on the key files. The compose mount is
# read-only into the broker container, but we still don't want
# anyone else on the host reading them.
chmod 600 ca.key server.key server.pem server.p12

CA_FP=$(openssl x509 -in ca.pem -noout -fingerprint -sha256 | sed 's/^.*=//')
log "→ done. CA fingerprint (sha256): $CA_FP"
log "   Pin this from clients connecting over SASL_SSL on port 9095."
