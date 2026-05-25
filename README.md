# kafka-up

A local Apache Kafka environment for developers. One command, one
cluster, zero ceremony.

```
$ ./kafka-up
 _              __  _
| |____ _ / _| |_____ _   _ _ __
| / / _` | |_| |/ / _` |__| | | | '_ \
|   < (_| |  _|   < (_| |__| |_| | |_) |
|_|\_\__,_|_| |_|\_\__,_|   \__,_| .__/
                                 |_|
one command, one cluster, zero ceremony

plan
  engine             podman
  brokers            1
  schema registry    on  (port 8081)
  kafka connect      on  (port 8083)
  web ui             on  (port 8080)
  seed topics        yes

preflight
  ok  podman is reachable
  ok  topology configured (RF=1, min.isr=1)

starting containers
  > pulling images and creating containers
  ok  containers up

waiting for health
  > kafka0
  ok  kafka0 healthy
  > schema-registry
  ok  schema-registry healthy
  > connect
  ok  connect healthy
  > ui
  ok  ui healthy

seeding
  > creating example topics
  ok  topics ready

summary
+--------------------------------------------------------------+
| kafka-up is ready                                            |
+--------------------------------------------------------------+
| bootstrap (host)     localhost:9092                          |
| schema registry      http://localhost:8081                   |
| kafka connect        http://localhost:8083                   |
| web ui               http://localhost:8080                   |
|                                                              |
| brokers              1                                       |
| replication factor   1                                       |
| min insync replicas  1                                       |
|                                                              |
| stop the cluster     ./kafka-down                            |
| wipe everything      ./kafka-reset                           |
| see what's running   ./kafka-status                          |
+--------------------------------------------------------------+

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

On macOS or Windows, run `podman machine start` once before the first
`./kafka-up`. The script tells you so if it detects the machine is
stopped.

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
running. `podman machine start`. The script prints this hint when it
detects the situation, but it shows up unexpectedly when the VM
crashes mid-session.

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
