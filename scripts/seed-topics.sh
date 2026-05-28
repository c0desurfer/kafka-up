#!/usr/bin/env bash
# Create a small set of example topics so kafka-up users see something
# useful in the UI immediately. Uses --if-not-exists so reruns are
# idempotent. Replication factor follows the broker count.
#
# Two topic sets:
#   default    five topics, the original kafka-up baseline.
#   full       twelve topics with retention/policy variety (delete + compact),
#              keyed topics, an internal __kafkaup_test_internal probe.
#
# Selected via KAFKA_UP_SEED_SET=default|full, which the kafka-up
# script sets based on the --full-seed flag.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_common.sh
. "$HERE/_common.sh"

RF="${KAFKA_UP_RF:-1}"
SEED_SET="${KAFKA_UP_SEED_SET:-default}"

# name : partitions : retention_ms : cleanup_policy
# retention_ms=-1 means infinite (compacted only).
if [ "$SEED_SET" = "full" ]; then
  TOPICS=(
    "orders.v1.created:12:604800000:delete"
    "orders.v1.updated:12:604800000:delete"
    "orders.v1.cancelled:6:604800000:delete"
    "payments.transactions:6:1209600000:delete"
    "users.sessions:4:259200000:delete"
    "analytics.pageview:8:172800000:delete"
    "notifications.outbox:2:86400000:delete"
    "notifications.dlq:2:2592000000:delete"
    "cdc.postgres.public.orders:8:604800000:compact"
    "inventory.stock-delta:4:604800000:delete"
    "users.profile.changelog:4:-1:compact"
    "__kafkaup_test_internal:1:604800000:delete"
  )
else
  TOPICS=(
    "orders.created:6:604800000:delete"
    "orders.updated:6:604800000:delete"
    "payments.transactions:6:1209600000:delete"
    "users.profile.changelog:3:-1:compact"
    "analytics.pageview:8:172800000:delete"
  )
fi

for row in "${TOPICS[@]}"; do
  IFS=':' read -r name parts ret policy <<<"$row"
  args=(
    --bootstrap-server localhost:9092
    --create --if-not-exists
    --topic "$name"
    --partitions "$parts"
    --replication-factor "$RF"
    --config "cleanup.policy=$policy"
  )
  if [ "$ret" != "-1" ]; then
    args+=(--config "retention.ms=$ret")
  fi
  in_container kafka0 /opt/kafka/bin/kafka-topics.sh "${args[@]}" >/dev/null
done

# Quick verification.
created=$(in_container kafka0 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --list | grep -v '^_' | grep -v '^__' | wc -l | tr -d ' ')
echo "topics-after-seed=${created} set=${SEED_SET}"
