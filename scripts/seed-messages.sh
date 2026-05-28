#!/usr/bin/env bash
# Produce 50-200 messages per topic across the full seed set. All JSON
# bodies; no Avro/Protobuf (that's a downstream concern that needs
# Schema Registry integration on the producing side).
#
# Invoked automatically by `kafka-up --full-seed` after seed-topics
# finishes. Idempotent in the loose sense: re-running adds more
# messages to each topic. Use `kafka-reset` for a clean baseline.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_common.sh
. "$HERE/_common.sh"

# Wait briefly in case the caller raced ahead of broker readiness.
i=0
while (( i < 10 )); do
  if in_container kafka0 /opt/kafka/bin/kafka-broker-api-versions.sh \
      --bootstrap-server localhost:9092 >/dev/null 2>&1; then
    break
  fi
  sleep 1
  i=$((i+1))
done
if (( i == 10 )); then
  echo "✗ broker not ready" >&2; exit 1
fi

# Pseudo-uuid using /dev/urandom. uuidgen is not in apache/kafka.
uuid() {
  local hex
  hex=$(od -vAn -N16 -tx1 /dev/urandom | tr -d ' \n')
  echo "${hex:0:8}-${hex:8:4}-${hex:12:4}-${hex:16:4}-${hex:20:12}"
}

# Random integer in [min, max]. $RANDOM is 0..32767 which is plenty.
rint() {
  local min="$1" max="$2"
  echo $((min + RANDOM % (max - min + 1)))
}

# Random pick from comma-separated list: choose "a,b,c".
choose() {
  local IFS=','
  # shellcheck disable=SC2206
  local arr=($1)
  echo "${arr[RANDOM % ${#arr[@]}]}"
}

# Current epoch as ISO-8601 with sub-second jitter.
iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%S.$(printf '%03d' $((RANDOM % 1000)))Z"
}

# produce <topic> [<key_separator>] — body on stdin, one JSON per line.
# If key_separator is given, expect `key<sep>value` lines.
produce() {
  local topic="$1" key_sep="${2:-}"
  local args=(
    --bootstrap-server localhost:9092
    --topic "$topic"
  )
  if [ -n "$key_sep" ]; then
    args+=(
      --property "parse.key=true"
      --property "key.separator=$key_sep"
    )
  fi
  "$KAFKA_UP_ENGINE" exec -i kafka-up-kafka0 \
    /opt/kafka/bin/kafka-console-producer.sh "${args[@]}"
}

CUSTOMERS=(cust_a1 cust_b2 cust_c3 cust_d4 cust_e5 cust_f6 cust_g7 cust_h8)
CITIES="Bern,Zurich,Geneva,Berlin,Munich,Vienna,Amsterdam,Paris,Lisbon,Madrid"
STATUSES="pending,authorized,settled,refunded,failed"
PAGES="/home,/products,/products/123,/cart,/checkout,/account,/orders,/blog,/about,/pricing"
REASONS="customer-request,fraud-suspected,out-of-stock,duplicate-order,payment-failed"
SKUS="SKU-1001,SKU-1002,SKU-1003,SKU-1004,SKU-2001,SKU-2002,SKU-3001"
LOCATIONS="warehouse-zh,warehouse-ge,warehouse-be,store-001,store-002"
UAS="Mozilla/5.0,Safari/15,Chrome/120,Firefox/119,Edge/121"

now_ms() { date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))'; }

echo "  → seeding orders.v1.created"
{
  for i in $(seq 1 120); do
    oid=$(uuid)
    cust=${CUSTOMERS[$((RANDOM % ${#CUSTOMERS[@]}))]}
    qty=$(rint 1 5)
    total=$(rint 1000 49999)
    cents=$((total / 100)).${total: -2}
    printf '{"order_id":"%s","customer_id":"%s","items":[{"sku":"%s","qty":%d}],"total_eur":%s,"city":"%s","created_at":"%s"}\n' \
      "$oid" "$cust" "$(choose "$SKUS")" "$qty" "$cents" "$(choose "$CITIES")" "$(iso_now)"
  done
} | produce orders.v1.created

echo "  → seeding orders.v1.updated"
{
  for i in $(seq 1 80); do
    printf '{"order_id":"%s","status":"%s","updated_at":"%s"}\n' \
      "$(uuid)" "$(choose "shipped,delivered,returned")" "$(iso_now)"
  done
} | produce orders.v1.updated

echo "  → seeding orders.v1.cancelled"
{
  for i in $(seq 1 40); do
    printf '{"order_id":"%s","reason":"%s","cancelled_at":"%s"}\n' \
      "$(uuid)" "$(choose "$REASONS")" "$(iso_now)"
  done
} | produce orders.v1.cancelled

echo "  → seeding payments.transactions"
{
  for i in $(seq 1 100); do
    amt=$(rint 500 999900)
    cents=$((amt / 100)).${amt: -2}
    printf '{"tx_id":"%s","order_id":"%s","amount_chf":%s,"currency":"CHF","status":"%s","ts":"%s"}\n' \
      "$(uuid)" "$(uuid)" "$cents" "$(choose "$STATUSES")" "$(iso_now)"
  done
} | produce payments.transactions

echo "  → seeding users.sessions"
{
  for i in $(seq 1 75); do
    printf '{"session_id":"%s","user_id":"user_%d","ip":"10.%d.%d.%d","ua":"%s","started_at":"%s"}\n' \
      "$(uuid)" "$(rint 1 250)" "$(rint 0 255)" "$(rint 0 255)" "$(rint 0 255)" \
      "$(choose "$UAS")" "$(iso_now)"
  done
} | produce users.sessions

echo "  → seeding analytics.pageview"
{
  for i in $(seq 1 150); do
    printf '{"path":"%s","user_id":"user_%d","ts":"%s"}\n' \
      "$(choose "$PAGES")" "$(rint 1 250)" "$(iso_now)"
  done
} | produce analytics.pageview

echo "  → seeding notifications.outbox"
{
  for i in $(seq 1 60); do
    printf '{"notif_id":"%s","type":"%s","user_id":"user_%d","subject":"Your order is on the way"}\n' \
      "$(uuid)" "$(choose "email,push,sms")" "$(rint 1 250)"
  done
} | produce notifications.outbox

echo "  → seeding notifications.dlq"
{
  for i in $(seq 1 15); do
    printf '{"notif_id":"%s","error":"%s","attempt":%d,"failed_at":"%s"}\n' \
      "$(uuid)" "$(choose "smtp-timeout,recipient-bounce,rate-limited,template-render-failed")" \
      "$(rint 1 5)" "$(iso_now)"
  done
} | produce notifications.dlq

echo "  → seeding cdc.postgres.public.orders"
{
  for i in $(seq 1 90); do
    oid=$(uuid)
    op=$(choose "c,u,d,r")
    printf '%s|{"op":"%s","before":null,"after":{"id":"%s","status":"%s"},"ts_ms":%s}\n' \
      "$oid" "$op" "$oid" "$(choose "$STATUSES")" "$(now_ms)"
  done
} | produce cdc.postgres.public.orders "|"

echo "  → seeding inventory.stock-delta"
{
  for i in $(seq 1 110); do
    delta=$(rint -20 20)
    printf '{"sku":"%s","delta":%d,"location":"%s","ts":"%s"}\n' \
      "$(choose "$SKUS")" "$delta" "$(choose "$LOCATIONS")" "$(iso_now)"
  done
} | produce inventory.stock-delta

echo "  → seeding users.profile.changelog"
{
  for i in $(seq 1 70); do
    uid="user_$(rint 1 50)"
    printf '%s|{"user_id":"%s","email_verified":%s,"city":"%s","updated_at":"%s"}\n' \
      "$uid" "$uid" "$(choose "true,false")" "$(choose "$CITIES")" "$(iso_now)"
  done
} | produce users.profile.changelog "|"

echo "  → seeding __kafkaup_test_internal"
{
  for i in $(seq 1 5); do
    printf '{"probe":"%s","sequence":%d,"emitted_at":"%s"}\n' \
      "$(uuid)" "$i" "$(iso_now)"
  done
} | produce __kafkaup_test_internal

echo "→ seed complete"
