# sleep-and-wait

Portable skill: a CLI agent sleeps for a set duration (hard-capped at 12
hours) and is woken at that moment. Prints the target wake time up front.

- `SKILL.md` — usage, including the one-wait-call-per-interval rule for Codex,
  Claude Code, and other harnesses
- `scripts/sleep-and-wait.sh` — deterministic helper (duration parsing, 12h cap,
  UTC wake-time printing, a cheap-wait hint line, chunked/background modes,
  cancellable sleep)
- `tests/smoke.sh` — exit codes, the 12h cap, the hint line, and cancellation

## Install

Symlink or copy `sleep-and-wait` into any harness-defined skill root, or use
`skillshare install /path/to/sleep-and-wait`.

## Test

```bash
bash tests/smoke.sh                        # all checks, exit 0 on success
bash scripts/sleep-and-wait.sh 1          # sleeps 1s, exit 0
bash scripts/sleep-and-wait.sh 13h; echo $?   # 2 (refused: over 12h cap)
bash scripts/sleep-and-wait.sh 5 --chunk 2; echo $?   # 3 (chunk done, more remains)
bash scripts/sleep-and-wait.sh 5 --chunk 0; echo $?   # 0 (full duration in one call)
```
