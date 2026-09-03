#!/usr/bin/env bash
# sleep-and-wait.sh — sleep for a duration, print the target wake time, and
# print a one-line cheap-wait hint for the calling harness.
#
# Hard cap of 12 hours (43200s) so an agent can never sleep itself forever.
#
# USAGE
#   sleep-and-wait.sh <duration> [--chunk <seconds>]
#
#   <duration>    Integer seconds (300) or a unit suffix: 45m, 6h, 12h.
#                 1d and anything over 12h is refused.
#   --chunk <s>   Sleep at most this many seconds in one call (default 540).
#                 Use --chunk 0 to sleep the full duration in a single call
#                 (for harnesses that re-invoke on background completion).
#
# EXIT CODES
#   0   the full duration elapsed
#   2   bad arguments, or duration exceeds the 12h cap
#   3   one chunk elapsed; more remains — the caller should loop
#   130 interrupted by SIGTERM/SIGINT
#
# The sleep is cancellable: a TERM/INT signal kills the child and exits 130 so
# a supervisor can interrupt cleanly.

set -euo pipefail

MAX_SECONDS=43200   # 12h hard cap
DEFAULT_CHUNK=540   # safely under Claude Code's 10-minute foreground ceiling

usage() {
  sed -n '1,24p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'
  exit 2
}

# Parse "<int>[smhd]?" into seconds; echoes the seconds, exits 2 on garbage.
parse_duration() {
  local d="$1"
  [[ "$d" =~ ^([0-9]+)([smhd]?)$ ]] || { echo "sleep-and-wait: invalid duration '$d' (want seconds, or 45m/6h/12h)" >&2; exit 2; }
  local n="${BASH_REMATCH[1]}" unit="${BASH_REMATCH[2]}" mult=1
  case "$unit" in
    s|"") mult=1 ;;
    m) mult=60 ;;
    h) mult=3600 ;;
    d) mult=86400 ;;
  esac
  echo $(( n * mult ))
}

# ISO-8601 UTC from an epoch; GNU date and macOS/BSD both supported.
date_iso() {
  local e="$1"
  if date -u -d "@$e" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then
    return 0
  fi
  date -u -r "$e" +%Y-%m-%dT%H:%M:%SZ
}

# One-line reminder, printed before the sleep starts, telling the calling
# harness how to wait for this process with a single tool call instead of a
# poll loop. It lands in the model's context exactly when it decides how to
# wait, which survives context compaction.
cheap_wait_hint() {
  local secs="$1"
  local ms=$(( secs * 1000 + 5000 ))
  echo "sleep-and-wait: wait cheaply — Codex: one write_stdin(chars:\"\", yield_time_ms:${ms}) on this cell, repeated once only if it is still running (ceiling: background_terminal_max_timeout, default 300000; set 3600000 for one-call waits); Claude Code: background task, act on re-invocation; other harnesses: foreground chunks. One wait call per interval."
}

# Cancellable sleep: background `sleep`, wait on it, kill the child on signal.
sleep_for() {
  local n="$1"
  [[ "$n" -eq 0 ]] && return 0
  local pid rc=0
  sleep "$n" &
  pid=$!
  # `|| true` on each step keeps the handler set -e-safe: the child's `wait`
  # returns non-zero once the kill lands, and that must not abort the handler
  # before `exit 130`.
  trap 'kill -TERM '"$pid"' 2>/dev/null || true; wait '"$pid"' 2>/dev/null || true; exit 130' TERM INT
  wait "$pid" || rc=$?
  trap - TERM INT
  return "$rc"
}

main() {
  local dur="" chunk="$DEFAULT_CHUNK"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --chunk)
        [[ $# -ge 2 ]] || { echo "sleep-and-wait: --chunk requires a value" >&2; exit 2; }
        [[ "$2" =~ ^[0-9]+$ ]] || { echo "sleep-and-wait: --chunk must be an integer >= 0" >&2; exit 2; }
        chunk="$2"
        shift 2
        ;;
      -h|--help|help) usage ;;
      -*)
        echo "sleep-and-wait: unknown option: $1" >&2
        usage
        ;;
      *)
        [[ -z "$dur" ]] || { echo "sleep-and-wait: too many durations" >&2; usage; }
        dur="$1"
        shift
        ;;
    esac
  done
  [[ -n "$dur" ]] || usage

  local total
  total=$(parse_duration "$dur")
  [[ "$total" -le "$MAX_SECONDS" ]] || {
    echo "sleep-and-wait: refusing to sleep $dur ($total seconds) — hard cap is 12h (${MAX_SECONDS}s)" >&2
    exit 2
  }

  local now wake
  now=$(date -u +%s)
  wake=$(( now + total ))

  if [[ "$total" -eq 0 ]]; then
    echo "sleep-and-wait: 0s — nothing to do"
    exit 0
  fi

  if [[ "$chunk" -eq 0 ]] || [[ "$total" -le "$chunk" ]]; then
    echo "sleep-and-wait: sleeping ${total}s until $(date_iso "$wake")"
    cheap_wait_hint "$total"
    sleep_for "$total"
    exit 0
  fi

  local remain=$(( total - chunk ))
  echo "sleep-and-wait: sleeping ${chunk}s of ${total}s; ${remain}s remain (target $(date_iso "$wake"))"
  cheap_wait_hint "$chunk"
  sleep_for "$chunk"
  exit 3
}

main "$@"
