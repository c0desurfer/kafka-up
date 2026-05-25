## What

(One paragraph. What changes, what stays the same.)

## Why

(Link an issue or describe the motivation.)

## How tested

- [ ] `./kafka-up` single mode brings up cleanly.
- [ ] `./kafka-up --brokers 3` cluster mode brings up cleanly.
- [ ] `./kafka-reset --yes` cleans up without leftover containers or
      volumes.
- [ ] Touched scripts pass `bash -n`.
- [ ] Touched scripts pass `shellcheck` if installed locally.

## Notes

(Anything reviewers should know that is not in the diff.)
