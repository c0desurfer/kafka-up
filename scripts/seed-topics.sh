#!/usr/bin/env bash
# Create a small set of example topics so kafka-up users see something
# useful in the UI immediately. Uses --if-not-exists so reruns are
# idempotent. Replication factor follows the broker count.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_common.sh
. "$HERE/_common.sh"

RF="${KAFKA_UP_RF:-1}"

# name : partitions : retention_ms : cleanup_policy
TOPICS=(
  "orders.created:6:604800000:delete"
  "orders.updated:6:604800000:delete"
  "payments.transactions:6:1209600000:delete"
  "users.profile.changelog:3:-1:compact"
  "analytics.pageview:8:172800000:delete"
)

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
  --bootstrap-server localhost:9092 --list | grep -v '^_' | wc -l | tr -d ' ')
echo "topics-after-seed=${created}"
