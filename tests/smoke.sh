#!/usr/bin/env bash
# Smoke test for sleep-and-wait.sh: exit codes, cap, and the cheap-wait hint.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
s="$here/scripts/sleep-and-wait.sh"
fail=0
check() { # name expected_rc actual_rc
  if [[ "$2" == "$3" ]]; then echo "ok   $1 (rc=$3)"; else echo "FAIL $1 (want rc=$2 got rc=$3)"; fail=1; fi
}
out=$(bash "$s" 1 2>&1); check "1s full sleep" 0 $?
grep -q 'sleeping 1s until' <<<"$out" || { echo "FAIL wake-time line missing"; fail=1; }
grep -q 'wait cheaply — Codex: one write_stdin(chars:"", yield_time_ms:6000)' <<<"$out" || { echo "FAIL cheap-wait hint missing or wrong ms"; echo "$out"; fail=1; }
grep -q 'One wait call per interval' <<<"$out" || { echo "FAIL hint tail missing"; fail=1; }
out=$(bash "$s" 3 --chunk 1 2>&1); check "chunk done, more remains" 3 $?
grep -q 'yield_time_ms:6000' <<<"$out" || { echo "FAIL chunk hint should use the chunk length (1s -> 6000 ms)"; echo "$out"; fail=1; }
bash "$s" 13h >/dev/null 2>&1; check "over 12h refused" 2 $?
bash "$s" 0 >/dev/null 2>&1; check "zero duration" 0 $?
bash "$s" garbage >/dev/null 2>&1; check "bad duration" 2 $?
( bash "$s" 30 --chunk 0 >/dev/null 2>&1 & pid=$!; sleep 1; kill -TERM "$pid"; wait "$pid"; exit $? ); check "cancellable (SIGTERM -> 130)" 130 $?
exit $fail
