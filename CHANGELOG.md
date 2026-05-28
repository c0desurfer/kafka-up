# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `--auth` flag: bring up SCRAM-SHA-256 (9093), SCRAM-SHA-512 (9094),
  and SASL_SSL/SCRAM-SHA-512 (9095) listeners alongside the default
  PLAINTEXT one. Self-signed CA + broker cert are generated on first
  use (`scripts/generate-certs.sh`, 10-year validity, 7-day skip-if-
  fresh). Four SCRAM users are provisioned automatically
  (`scripts/provision-users.sh`): a main `kafkaup` user with both
  SCRAM-256 and SCRAM-512 credentials, plus `admin` and `readonly`.
  Single-broker only for now.
- `--full-seed` flag: replaces the 5-topic default seed with a richer
  12-topic set (varied retention, compact + delete cleanup policies,
  one keyed topic, one `__`-prefixed internal probe) and produces
  ~1000 sample JSON messages across the set
  (`scripts/seed-messages.sh`).
- `--alt-registry` flag: adds Apicurio Registry 3.0.0 on port 8082 in
  parallel to Confluent Schema Registry, for cross-registry
  compatibility testing.
- `.env.example` with overrides for the SCRAM user/password defaults.
- `compose.auth.override.yml` overlay file used by `--auth` to mount
  the 4-listener `config/server-auth.properties` and the certs
  directory.

### Fixed

- `kafka-status` no longer relies on `mapfile`, which is unavailable
  in bash 3.2 (macOS default).

## [0.1.0] — initial release

### Added

- `compose.yml` with single-broker default and three-broker cluster
  profile, using Apache Kafka 4.3.0 in KRaft mode.
- Schema Registry 7.9.7, Kafka Connect 7.9.7, Kafbat UI v1.5.0 bundled
  by default.
- `kafka-up`, `kafka-down`, `kafka-reset`, `kafka-status`, `kafka-logs`
  scripts with consistent ASCII output and `NO_COLOR` support.
- Seed of five example topics on first bring-up.
- Renovate configuration with grouped sidecar updates and patch
  automerge.
- CI: shellcheck, yamllint, actionlint, markdownlint, em-dash linter,
  end-to-end bring-up against both topologies.
