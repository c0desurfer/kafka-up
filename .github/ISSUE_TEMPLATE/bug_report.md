---
name: Bug report
about: Something does not work the way it should
labels: bug
---

## What happened

(One paragraph. Be specific.)

## What you expected

(One paragraph.)

## Reproducer

```bash
./kafka-up ...
```

## Environment

- OS:
- Container engine: `podman --version` / `docker --version`
- Output of `./kafka-status`:

## Logs

Paste the relevant section of `./kafka-logs kafka0` (or whichever
service misbehaved). Trim aggressively, surround in fenced code.
