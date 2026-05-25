# Security policy

kafka-up spins up a local Kafka environment. The threat model is
narrow on purpose: nothing in this repository is intended to run on
a network anyone else can reach.

## Supported versions

Only `main` is supported. The compose file pins image tags, so an
older commit is a known snapshot you can run forever, but security
fixes only land on `main`.

## Reporting a vulnerability

If you find an issue that is materially worse than "this is a
plaintext dev cluster on localhost," report it privately:

1. Open a GitHub security advisory on the repository, **or**
2. Email the maintainer listed in `MAINTAINERS` (if present) or the
   repository owner's public address.

Please do not open a public issue for vulnerabilities. A coordinated
disclosure window of 30 days is plenty for a project this size.

## What is in scope

- Container configuration that exposes services beyond `127.0.0.1`
  unintentionally.
- Default credentials or shared secrets that are not clearly labelled
  as dev-only.
- Image versions with known critical CVEs that we could pin away from.

## What is out of scope

- Apache Kafka, Confluent Platform, or Kafbat UI vulnerabilities
  themselves. Report those upstream.
- The fact that PLAINTEXT is the only listener. That is the design.
- The fact that anyone with shell access to your machine can produce to
  your local cluster. Also the design.
