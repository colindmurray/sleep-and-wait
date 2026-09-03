---
name: sleep-and-wait
description: Use when a CLI agent needs to sleep for a set amount of time and then be woken at that moment — waiting for a scheduled time, a rate-limit or quota reset, a cooldown, or a time-gated check. Works in any harness; hard-capped at 12 hours so an agent cannot sleep itself forever.
---

# Sleep and wait

Sleep for a duration and act the moment it elapses, spending as few model
turns as possible while asleep. The helper prints the target wake time (UTC)
up front, refuses any request over 12 hours, and prints a cheap-wait hint so
the caller knows how to wait without polling.

## Run

```bash
bash "$SKILL_DIR/scripts/sleep-and-wait.sh" 10m
```

- Duration: `300` (seconds), `45m`, `6h`, `12h`. Anything over 12h is refused
  (exit 2).
- Exit `0` = elapsed; exit `3` = one chunk slept, loop again; `130` =
  interrupted.
- `--chunk N` overrides the chunk size (default 540s); `--chunk 0` sleeps the
  whole duration in one call.

## One wait call per interval

A sleep costs model turns only when the harness returns control before the
sleep ends. Pick the mechanism that returns control once:

1. **Codex (unified exec / code mode).** The first `exec_command` yield is
   capped at 30 s, so the helper always becomes a background cell. Launch with
   `--chunk 0`, then make ONE `write_stdin` call on that cell with empty
   `chars` and `yield_time_ms` set to the remaining sleep plus 5 000 ms. Codex
   blocks that single call for up to `background_terminal_max_timeout`
   (default 300 000 ms). If the cell is still running when the call returns,
   repeat the same call once for the remainder. A 10-minute sleep is 2 turns
   at the 5-minute default and 1 turn once the ceiling is raised. `wait` on the
   cell follows the same rule. To wait up to an hour in one call, set
   `background_terminal_max_timeout = 3600000` in Codex `config.toml` — the
   value Codex's own built-in awaiter agent uses.
2. **Claude Code.** Run the helper as a background Bash task
   (`run_in_background: true`) with `--chunk 0`; the agent is re-invoked when
   the sleep completes.
3. **Any other harness.** Run the default one-chunk form in the foreground; on
   exit `3`, call it again with the remaining time. Each chunk (default 540 s)
   stays under a typical foreground command timeout.

The sleep is cancellable: send SIGTERM/SIGINT to the helper to wake early
(exit 130).
