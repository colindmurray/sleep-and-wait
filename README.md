# sleep-and-wait

Portable skill: a CLI agent sleeps for a set duration (hard-capped at 12
hours) and is woken at that moment. Prints the target wake time up front.

- `SKILL.md` — usage
- `scripts/sleep-and-wait.sh` — deterministic helper (duration parsing, 12h cap,
  UTC wake-time printing, chunked/background modes, cancellable sleep)

## Install

Symlink or copy `sleep-and-wait` into any harness-defined skill root, or use
`skillshare install /path/to/sleep-and-wait`.

## Test

```bash
bash scripts/sleep-and-wait.sh 1          # sleeps 1s, exit 0
bash scripts/sleep-and-wait.sh 13h; echo $?   # 2 (refused: over 12h cap)
bash scripts/sleep-and-wait.sh 5 --chunk 2; echo $?   # 3 (chunk done, more remains)
bash scripts/sleep-and-wait.sh 5 --chunk 0; echo $?   # 0 (full duration in one call)
```
