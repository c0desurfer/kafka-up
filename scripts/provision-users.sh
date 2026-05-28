#!/usr/bin/env bash
# Provision SCRAM users on the running broker. Invoked automatically by
# `kafka-up --auth` after the broker is healthy.
#
# Uses kafka-configs over the PLAINTEXT listener at localhost:9092
# (which doesn't require auth) to write SCRAM credentials. The user
# records are stored in the KRaft metadata log, so they survive
# restarts and propagate across brokers in cluster mode.
#
# Idempotent: kafka-configs --alter --add-config overwrites existing
# entries, so rerunning is safe.
#
# Credentials are sourced from .env if present, falling back to the
# defaults in .env.example. Override per-call via env vars, e.g.:
#
#   KAFKA_UP_USER=alice KAFKA_UP_PASSWORD_512=secret \
#     ./scripts/provision-users.sh

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_common.sh
. "$HERE/_common.sh"

# Load credentials from .env if present.
if [ -f "$KAFKA_UP_DIR/.env" ]; then
  # shellcheck disable=SC1091
  set -a; . "$KAFKA_UP_DIR/.env"; set +a
fi

# Defaults track .env.example so a fresh checkout works without copying.
: "${KAFKA_UP_USER:=kafkaup}"
: "${KAFKA_UP_PASSWORD_256:=kafkaup-dev-256}"
: "${KAFKA_UP_PASSWORD_512:=kafkaup-dev-512}"
: "${KAFKA_UP_ADMIN_USER:=admin}"
: "${KAFKA_UP_ADMIN_PASSWORD:=admin-secret}"
: "${KAFKA_UP_READONLY_USER:=readonly}"
: "${KAFKA_UP_READONLY_PASSWORD:=readonly-secret}"

# Wait for the broker to accept admin commands. The caller already
# waited for healthcheck, but kafka-configs is slightly stricter and
# can race the controller election window.
i=0
while (( i < 30 )); do
  if in_container kafka0 /opt/kafka/bin/kafka-broker-api-versions.sh \
      --bootstrap-server localhost:9092 >/dev/null 2>&1; then
    break
  fi
  sleep 1
  i=$((i+1))
done
if (( i == 30 )); then
  echo "✗ broker not ready after 30s — cannot provision SCRAM users" >&2
  exit 1
fi

create_scram() {
  local user="$1" mech="$2" password="$3"
  in_container kafka0 /opt/kafka/bin/kafka-configs.sh \
    --bootstrap-server localhost:9092 \
    --alter \
    --add-config "${mech}=[iterations=4096,password=${password}]" \
    --entity-type users --entity-name "$user" >/dev/null
  echo "  ✓ $user / $mech"
}

echo "→ creating SCRAM users"
create_scram "$KAFKA_UP_USER"          SCRAM-SHA-256 "$KAFKA_UP_PASSWORD_256"
create_scram "$KAFKA_UP_USER"          SCRAM-SHA-512 "$KAFKA_UP_PASSWORD_512"
create_scram "$KAFKA_UP_ADMIN_USER"    SCRAM-SHA-512 "$KAFKA_UP_ADMIN_PASSWORD"
create_scram "$KAFKA_UP_READONLY_USER" SCRAM-SHA-512 "$KAFKA_UP_READONLY_PASSWORD"
echo "→ SCRAM users ready"
