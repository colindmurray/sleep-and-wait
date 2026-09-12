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

1. **Codex (code mode).** For a genuinely parked graph, prefer the native
   `clock.sleep` idle tool: it is direct-model-only, bypasses the code-mode
   cell, takes a `duration_ms` up to 12 h, and wakes on timer expiry or new
   input — one call, one turn. Enable it with `[features.sleep_tool] enabled =
   true, mode = "always_on"`.
   To wait on a running cell instead, launch the helper with `--chunk 0`, then
   make ONE `write_stdin` call on that cell with empty `chars` and a
   `yield_time_ms` at the ceiling. Note the ceiling: in code mode a single wait
   is bounded by the OUTER code-mode cell yield, whose default is
   `default_exec_yield_time_ms` (~30 000 ms) — NOT by
   `background_terminal_max_timeout`, which separately bounds the inner terminal
   read and does not lengthen the outer cell. Raise the per-call hold by setting
   `[features.code_mode] default_exec_yield_time_ms` (e.g. 60000) in the profile;
   that value survives compaction where a per-call `@exec` pragma does not. A
   following `functions.wait` on a code-cell carries its own requested value.
   Repeat the one call only while the cell is still running. Do not rely on a
   built-in awaiter agent — its role registration is not available in current
   Codex. Verify the effective per-call maximum on the host.
2. **Claude Code.** Run the helper as a background Bash task
   (`run_in_background: true`) with `--chunk 0`; the agent is re-invoked when
   the sleep completes.
3. **Any other harness.** Run the default one-chunk form in the foreground; on
   exit `3`, call it again with the remaining time. Each chunk (default 540 s)
   stays under a typical foreground command timeout.

The sleep is cancellable: send SIGTERM/SIGINT to the helper to wake early
(exit 130).
