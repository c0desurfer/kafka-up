<div align="center">

# kafka-up

**One command, one cluster, zero ceremony.**

A local Apache Kafka environment for developers, ready in around ten seconds.

[![CI](https://github.com/c0desurfer/kafka-up/actions/workflows/e2e.yml/badge.svg)](https://github.com/c0desurfer/kafka-up/actions/workflows/e2e.yml)
[![Lint](https://github.com/c0desurfer/kafka-up/actions/workflows/lint.yml/badge.svg)](https://github.com/c0desurfer/kafka-up/actions/workflows/lint.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](./LICENSE)
[![Renovate](https://img.shields.io/badge/Renovate-enabled-1A1F6C?logo=renovatebot&logoColor=white)](./renovate.json)

[![Apache Kafka](https://img.shields.io/badge/Apache%20Kafka-4.3.0-231F20?logo=apachekafka&logoColor=white)](https://kafka.apache.org/)
[![Schema Registry](https://img.shields.io/badge/Schema%20Registry-7.9.7-1F2F46)](https://docs.confluent.io/platform/current/schema-registry/index.html)
[![Kafka Connect](https://img.shields.io/badge/Kafka%20Connect-7.9.7-1F2F46)](https://docs.confluent.io/platform/current/connect/index.html)
[![Kafbat UI](https://img.shields.io/badge/Kafbat%20UI-v1.5.0-3D8BD3)](https://github.com/kafbat/kafka-ui)

[![KRaft](https://img.shields.io/badge/KRaft-no%20ZooKeeper-F37726)](https://kafka.apache.org/documentation/#kraft)
[![Podman](https://img.shields.io/badge/Podman-4%2B-892CA0?logo=podman&logoColor=white)](https://podman.io/)
[![Docker](https://img.shields.io/badge/Docker-24%2B-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Bash](https://img.shields.io/badge/Bash-5%2B-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Shellcheck](https://img.shields.io/badge/shellcheck-clean-brightgreen)](https://www.shellcheck.net/)

</div>

---

```text
$ ./kafka-up
██╗  ██╗ █████╗ ███████╗██╗  ██╗ █████╗       ██╗   ██╗██████╗
██║ ██╔╝██╔══██╗██╔════╝██║ ██╔╝██╔══██╗      ██║   ██║██╔══██╗
█████╔╝ ███████║█████╗  █████╔╝ ███████║█████╗██║   ██║██████╔╝
██╔═██╗ ██╔══██║██╔══╝  ██╔═██╗ ██╔══██║╚════╝██║   ██║██╔═══╝
██║  ██╗██║  ██║██║     ██║  ██╗██║  ██║      ╚██████╔╝██║
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝       ╚═════╝ ╚═╝
one command, one cluster, zero ceremony

  ...

summary
+----------------------------------------------------------------+
| kafka-up is ready                                              |
+----------------------------------------------------------------+
| bootstrap (host)     localhost:9092                            |
| schema registry      http://localhost:8081                     |
| kafka connect        http://localhost:8083                     |
| web ui               http://localhost:8080                     |
|                                                                |
| brokers              1                                         |
| replication factor   1                                         |
| min insync replicas  1                                         |
+----------------------------------------------------------------+

ready in 11s
```

## What it gives you

| Component       | Image                                   | Port           |
|-----------------|-----------------------------------------|----------------|
| Apache Kafka    | `apache/kafka:4.3.0`                    | 9092 (9192, 9292 in cluster mode) |
| Schema Registry | `confluentinc/cp-schema-registry:7.9.7` | 8081           |
| Kafka Connect   | `confluentinc/cp-kafka-connect:7.9.7`   | 8083           |
| Kafbat UI       | `ghcr.io/kafbat/kafka-ui:v1.5.0`        | 8080           |

KRaft-only. No ZooKeeper, no legacy listeners, no surprises. Everything
binds to `127.0.0.1`, so nothing leaks beyond the host.

## Why another Kafka quickstart

The official compose files in the Apache and Confluent repos optimise
for showcasing a feature, not for being your daily driver. They drift
between versions, bury the bootstrap address under three layers of
indirection, and leave you to figure out replication factors when you
add a second broker. kafka-up has one job: give you a realistic,
correctly-configured cluster fast enough that you treat it as
disposable.

Design choices worth knowing:

- **KRaft from day one.** Apache Kafka 4 drops ZooKeeper entirely. The
  brokers in this repo are combined controller+broker nodes, which is
  the supported topology for development clusters.
- **Internal + external listeners, properly advertised.** Sidecars
  inside the compose network reach the broker via `kafka0:29092`
  (advertised as the in-network hostname). Your code on the host
  reaches it via `localhost:9092`. The two are not the same broker
  endpoint, and getting this wrong is the most common cause of
  Schema Registry restart loops.
- **Replication factor tracks the topology.** Single broker uses RF=1
  and min.insync.replicas=1. Three brokers use RF=3 and min.isr=2. The
  internal topics (`__consumer_offsets`, `_schemas`, `_connect-*`)
  pick the same numbers, so the cluster behaves like the production
  one you eventually deploy.
- **Healthchecks gate everything.** Sidecars `depends_on` the broker
  with `condition: service_healthy`, the script waits for each container
  to report healthy before declaring success. No `sleep 30; hope`.
- **Containers and volumes are named.** `kafka-up-kafka0`,
  `kafka-up-kafka0-data`, and so on. Easy to find, easy to remove.

## Requirements

- Podman 4+ with the `podman-compose` provider, or Docker 24+ with
  Compose v2.
- Bash, `curl`. That is the whole list.

On macOS or Windows, `./kafka-up` starts the podman machine for you if
one exists but is stopped. The very first time you use podman on a new
machine, run `podman machine init` once to create the VM.

## Usage

```bash
git clone https://github.com/c0desurfer/kafka-up.git
cd kafka-up
./kafka-up
```

```bash
./kafka-up --brokers 3        # three-broker cluster, RF=3, min.isr=2
./kafka-up --no-connect       # skip Kafka Connect
./kafka-up --no-ui            # skip the Kafbat UI
./kafka-up --no-seed          # do not create example topics
./kafka-up --auth             # add SCRAM-256/512 + SASL_SSL + mTLS listeners
./kafka-up --full-seed        # 12-topic seed with sample messages
./kafka-up --alt-registry     # add Apicurio Registry on 8082
./kafka-up --engine docker    # use docker compose instead of podman
```

| Script           | Purpose                                                     |
|------------------|-------------------------------------------------------------|
| `./kafka-up`     | Start the environment. Idempotent. Picks up where you left off. |
| `./kafka-down`   | Stop containers. Volumes are preserved.                     |
| `./kafka-reset`  | Tear down containers and wipe volumes. Asks for typed confirmation, or pass `--yes`. |
| `./kafka-status` | Read-only snapshot: containers, topics, subjects, connectors. |
| `./kafka-logs`   | Tail logs for a service. Defaults to `kafka0`.              |

All five scripts are pure Bash. Read them. They are the documentation.

## Auth mode (`--auth`)

By default, `./kafka-up` exposes one PLAINTEXT listener on `localhost:9092`,
which is fine for almost all local development. When you want to exercise
authenticated paths — testing a SASL/SCRAM connection from a client, a
SASL_SSL bootstrap with cert pinning, or anything that talks to a
production-shaped broker — pass `--auth`.

`./kafka-up --auth` brings up five host-facing listeners:

| Port | Protocol           | Mechanism      | Cert                     |
|------|--------------------|----------------|--------------------------|
| 9092 | PLAINTEXT          | none           | none                     |
| 9093 | SASL_PLAINTEXT     | SCRAM-SHA-256  | none                     |
| 9094 | SASL_PLAINTEXT     | SCRAM-SHA-512  | none                     |
| 9095 | SASL_SSL           | SCRAM-SHA-512  | self-signed (`certs/ca.pem`) |
| 9096 | SSL (mTLS)         | client cert    | self-signed, client cert **required** |

Each external listener has a matching `INT_*` twin on `29093..29096`
advertised under `kafka0:` so in-network sidecars can follow metadata
back to the broker.

The difference between 9095 and 9096 is `ssl.client.auth`: 9095 encrypts
the connection and authenticates the user with SCRAM, while 9096 sets
`ssl.client.auth=required` and will not finish a handshake at all unless
the client presents a certificate signed by the CA. That makes 9096 the
listener to test real mutual TLS against. No authorizer is configured,
so any client holding a CA-signed cert is fully authorized once the
handshake succeeds.

Four SCRAM users are provisioned automatically:

| User         | Mechanisms                  | Default password (override via `.env`)    |
|--------------|-----------------------------|-------------------------------------------|
| `kafkaup`    | SCRAM-SHA-256 + SCRAM-SHA-512 | `kafkaup-dev-256` / `kafkaup-dev-512`   |
| `admin`      | SCRAM-SHA-512               | `admin-secret`                            |
| `readonly`   | SCRAM-SHA-512               | `readonly-secret`                         |

Copy `.env.example` to `.env` to override these. The defaults are fine
for one-machine development. `certs/server.crt` is self-signed by
`certs/ca.pem` with a 10-year validity; `./kafka-up --auth` only
regenerates them if they're missing or within 7 days of expiry. The
client certificate for the mTLS listener (`CN=neostream-client`,
`extendedKeyUsage=clientAuth`) is signed by the same CA and written
alongside it, also as a combined PEM and as a PKCS12 bundle with the
passphrase `changeit`.

A minimal SCRAM-256 client config looks like:

```properties
bootstrap.servers=localhost:9093
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafkaup" password="kafkaup-dev-256";
```

For SASL_SSL on 9095, add the truststore and disable hostname checks
against the self-signed cert:

```properties
bootstrap.servers=localhost:9095
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafkaup" password="kafkaup-dev-512";
ssl.truststore.location=/path/to/certs/ca.pem
ssl.truststore.type=PEM
ssl.endpoint.identification.algorithm=
```

For mTLS on 9096, present a client certificate as well as trusting the
CA. There is no SASL layer on this listener, so there is no username:

```properties
bootstrap.servers=localhost:9096
security.protocol=SSL
ssl.truststore.location=/path/to/certs/ca.pem
ssl.truststore.type=PEM
ssl.keystore.location=/path/to/certs/client.pem
ssl.keystore.type=PEM
ssl.endpoint.identification.algorithm=
```

Omitting the keystore is the useful negative test: the broker drops the
connection during the TLS handshake rather than returning a Kafka auth
error, because client authentication happens below the Kafka protocol.
A client that reports this as a generic "connection reset" is hiding the
real cause from whoever has to debug it.

`--auth` is currently single-broker only. Combining it with `--brokers 3`
is rejected because the cluster topology would need per-broker SCRAM/SSL
port mapping (9193, 9293 variants); that work is out of scope until
there's a real reason to test multi-broker SASL locally.

## Full seed (`--full-seed`)

The default seed is five lean topics. `--full-seed` swaps that for a
twelve-topic set with retention/compaction variety, two keyed topics
(`cdc.postgres.public.orders` and `users.profile.changelog`), and an
internal probe topic (`__kafkaup_test_internal`). It also produces
~1000 sample JSON messages spread across the set, so the UI has
something to scroll through.

Full-seed topics:

| Topic                          | Partitions | Retention | Cleanup policy |
|--------------------------------|-----------:|-----------|----------------|
| `orders.v1.created`            |         12 | 7d        | delete         |
| `orders.v1.updated`            |         12 | 7d        | delete         |
| `orders.v1.cancelled`          |          6 | 7d        | delete         |
| `payments.transactions`        |          6 | 14d       | delete         |
| `users.sessions`               |          4 | 3d        | delete         |
| `analytics.pageview`           |          8 | 2d        | delete         |
| `notifications.outbox`         |          2 | 1d        | delete         |
| `notifications.dlq`            |          2 | 30d       | delete         |
| `cdc.postgres.public.orders`   |          8 | 7d        | compact        |
| `inventory.stock-delta`        |          4 | 7d        | delete         |
| `users.profile.changelog`      |          4 | infinite  | compact        |
| `__kafkaup_test_internal`      |          1 | 7d        | delete         |

## Alternate registry (`--alt-registry`)

`--alt-registry` brings up Apicurio Registry on `http://localhost:8082`
in parallel to Confluent Schema Registry on 8081. The registries share
the same broker but maintain their own subject namespaces, so this is
the easiest way to test cross-registry compatibility for Avro / JSON
Schema / Protobuf.

## Connecting to the cluster

From your application code on the host:

```text
bootstrap.servers = localhost:9092
```

In cluster mode the host-side bootstrap is
`localhost:9092,localhost:9192,localhost:9292`. The internal hostnames
`kafka0`, `kafka1`, `kafka2` are not resolvable from outside the
compose network, which is intentional.

Schema Registry and Connect speak HTTP:

```text
schema_registry.url = http://localhost:8081
connect.url         = http://localhost:8083
```

The Kafbat UI auto-discovers both. Open `http://localhost:8080` and you
see the cluster, its topics, the Schema Registry subjects, and the
Connect cluster in one place.

## Seeded topics

`./kafka-up` creates five example topics so the UI is not empty when
you open it. The seed is idempotent, additive, and skips topics that
already exist.

| Topic                        | Partitions | Retention | Cleanup policy |
|------------------------------|-----------:|-----------|----------------|
| `orders.created`             |          6 | 7d        | delete         |
| `orders.updated`             |          6 | 7d        | delete         |
| `payments.transactions`      |          6 | 14d       | delete         |
| `users.profile.changelog`    |          3 | infinite  | compact        |
| `analytics.pageview`         |          8 | 2d        | delete         |

The script produces no messages. If you want sample data, pipe your
own JSON into `kafka-console-producer`:

```bash
echo '{"order_id":"abc","total_eur":42.0}' \
  | podman exec -i kafka-up-kafka0 \
      /opt/kafka/bin/kafka-console-producer.sh \
      --bootstrap-server localhost:9092 \
      --topic orders.created
```

## Single vs. cluster mode

```text
single (default):                   cluster (--brokers 3):

  +----------+                       +----------+ +----------+ +----------+
  |  kafka0  |  RF=1                 |  kafka0  | |  kafka1  | |  kafka2  |  RF=3
  | ctrl+brk |  min.isr=1            | ctrl+brk | | ctrl+brk | | ctrl+brk |  min.isr=2
  +----+-----+                       +----+-----+ +----+-----+ +----+-----+
       |                                  |           |             |
       |        +----+----+----+          +-----------+-------------+
       +------->| SR | CN | UI |                      |
                +----+----+----+                      v
                                              +----+----+----+
                                              | SR | CN | UI |
                                              +----+----+----+
```

In cluster mode each broker is a KRaft voter as well as a regular
broker. Failure tolerance is one broker: with three voters the quorum
survives one outage. This matches the "n=3 for a real cluster" baseline
you should run in production.

## Port allocation

| Service           | Host port | In-network address     |
|-------------------|-----------|------------------------|
| kafka0 (PLAINTEXT)| 9092      | `kafka0:29092`         |
| kafka1 (PLAINTEXT)| 9192      | `kafka1:29092`         |
| kafka2 (PLAINTEXT)| 9292      | `kafka2:29092`         |
| Schema Registry   | 8081      | `schema-registry:8081` |
| Kafka Connect     | 8083      | `connect:8083`         |
| Kafbat UI         | 8080      | `ui:8080`              |

Controller ports (9090) are not exposed to the host. They speak the
KRaft raft protocol only and have no reason to leave the network.

## Troubleshooting

**`port 9092 is already in use`.** Something else on your box is
bound to 9092. `lsof -nP -iTCP:9092 -sTCP:LISTEN` shows what. Stop it,
or change the host port in `compose.yml`.

**`schema-registry` keeps restarting.** Means the broker came up but
SR cannot reach it on the internal listener. Run `./kafka-logs
schema-registry` and look for `KafkaStoreException`. Almost always
fixed by `./kafka-down && ./kafka-up` once the broker is fully ready.

**`connect` exits with `Topic ... has unexpected replication factor`.**
You switched between `--brokers 1` and `--brokers 3` without resetting
volumes. The internal Connect topics were created with the old factor.
Run `./kafka-reset --yes` and start again.

**`./kafka-up` hangs at `waiting for health`.** Open another terminal
and run `./kafka-logs kafka0`. If the broker is logging
`UnsupportedVersionException` against an older client, your podman
machine has a stale image cached. `podman image prune -a` then retry.

**On macOS, podman says `Cannot connect to Podman`.** Your VM is not
running. `./kafka-up` auto-starts it on bring-up, so the failure mode
you usually see is the VM crashing mid-session. `podman machine
restart` resolves it. If you have never run podman before, do
`podman machine init` once to create the VM.

## How it is wired

`compose.yml` is the source of truth. The scripts are thin wrappers
that set environment variables, pick profiles, and drive `compose up`
with the right service list. The interesting pieces:

- **`scripts/_common.sh`** translates a broker count into the env vars
  the compose file consumes (`KAFKA_UP_RF`, `KAFKA_UP_QUORUM_VOTERS`,
  `KAFKA_UP_BOOTSTRAP_INTERNAL_PLAIN`). One function, no surprises.
- **`scripts/_ui.sh`** holds the ANSI helpers. The output respects
  `NO_COLOR` and degrades to plain text when stdout is not a TTY.
- **`scripts/seed-topics.sh`** is invoked inside the broker container,
  so the host needs no Kafka CLI.

If you want to add a service (a producer container, a custom Connect
plugin, a second registry), drop it into `compose.yml` behind a profile
and update the `services=( ... )` list in `kafka-up`. The plumbing is
deliberately shallow.

## Versions and updates

Image tags are pinned in `compose.yml`. Renovate (configured in
`renovate.json`) opens grouped pull requests when Apache Kafka,
Confluent Platform, or Kafbat UI ship a new version. CI runs the full
bring-up against both single and cluster modes on every PR, so a
green Renovate PR means the new image is wire-compatible with the
rest of the stack.

## Contributing

Issues and pull requests are welcome. See
[`CONTRIBUTING.md`](./CONTRIBUTING.md) for the short version. If you
are reporting a bring-up failure, include the output of `./kafka-up`
and `./kafka-logs kafka0`.

Security-relevant reports go to the address in
[`SECURITY.md`](./SECURITY.md), not the public tracker.

## License

Apache 2.0. See [`LICENSE`](./LICENSE).

The bundled container images keep their own licenses: Apache Kafka and
Kafbat UI are Apache 2.0, the Confluent Platform images
(Schema Registry, Kafka Connect) are under the Confluent Community
License, which permits unrestricted use for development and internal
deployments.
