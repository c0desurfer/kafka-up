# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Initial release.
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
