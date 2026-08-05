---
name: sleep-and-wait
description: Use when a CLI agent needs to sleep for a set amount of time and then be woken at that moment — waiting for a scheduled time, a rate-limit or quota reset, a cooldown, or a time-gated check. Works in any harness; hard-capped at 12 hours so an agent cannot sleep itself forever.
---

# Sleep and wait

Sleep for a duration and be ready to act the moment it elapses. The helper
prints the target wake time (UTC) up front, and refuses any request over 12
hours.

## Run

```bash
bash "$SKILL_DIR/scripts/sleep-and-wait.sh" 6h
```

- Duration: `300` (seconds), `45m`, `6h`, `12h`. Anything over 12h is refused
  (exit 2).
- Exit `0` = elapsed; exit `3` = one chunk slept, loop again; `130` =
  interrupted.
- `--chunk N` overrides the chunk size (default 540s); `--chunk 0` sleeps the
  whole duration in one call (for background use).

## Pick the strongest wait mechanism

1. **Background re-invocation (Claude Code):** launch the helper as a background
   Bash task (`run_in_background: true`) with `--chunk 0` — the agent is
   re-invoked when the sleep completes, which is the true wake.
2. **Blocking chunks (any harness):** run the default one-chunk form; on exit
   `3`, call it again with the remaining time. Each chunk (default 540s) stays
   under the host's foreground command timeout.

The sleep is cancellable — send SIGTERM/SIGINT to stop it cleanly (exit 130).
