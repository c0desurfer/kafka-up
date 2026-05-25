# Contributing

Thanks for considering a contribution. kafka-up is a small repository
with a narrow purpose, so the bar for changes is "does this make the
developer experience faster or more honest?" Cosmetic refactors that
do not change behaviour are usually closed.

## Local development

```bash
git clone https://github.com/c0desurfer/kafka-up.git
cd kafka-up
./kafka-up
./kafka-status
./kafka-reset --yes
```

A clean bring-up should take under 30 seconds on a warm cache. If
yours takes longer, that is the regression we want to hear about.

## Before you open a PR

1. `bash -n` every script you touched.
2. `podman compose -f compose.yml config --quiet` (or `docker compose
   config --quiet`) passes.
3. Run shellcheck if you have it locally:
   `shellcheck kafka-up kafka-down kafka-reset kafka-status kafka-logs scripts/*.sh`.
4. No em-dashes (`U+2014`) or en-dashes (`U+2013`) in README, compose,
   or scripts. The lint job rejects them.
5. CI runs the full bring-up on both single and cluster modes. Wait for
   it to go green before requesting review.

## What lands easily

- Bug fixes with a clear reproducer.
- New compose profiles that add a real component (ksqlDB, MirrorMaker 2,
  a second registry) without changing the default experience.
- Documentation that replaces vague advice with concrete commands.

## What needs discussion first

- New top-level scripts.
- Changes to default ports.
- Switching the bundled web UI.
- Anything that adds a dependency on a non-Apache, non-Confluent image.

Open an issue describing the use case before sinking time into the
patch.

## Commit messages

Conventional commits, lowercase scope. Examples:

```text
feat(compose): add ksqldb profile
fix(kafka-up): wait for connect health before declaring success
docs(readme): clarify cluster bootstrap string
```

The Renovate config emits semantic commits for image bumps, keep the
style consistent.

## Releases

There is no release artefact. The compose file pins image tags, so a
release is the commit on `main` you are running. Tag it locally if you
want to anchor a known-good version for your team.
