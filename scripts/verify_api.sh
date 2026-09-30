#!/usr/bin/env bash
# Boot the OMNIVEST backend, run the API smoke test, tear it down.
#
# This lives in its own file on purpose. Doing it inline in the Makefile put
# the string "run.py" in the recipe shell's own command line, so the cleanup
# `pkill` matched itself and killed the recipe (make exited 2 with
# "Terminated" even though every test passed). A script's command line is just
# its path, so the pattern cannot collide with itself.
#
# exit 0 = all API checks passed, backend stopped
# exit 1 = a check failed, backend stopped
# exit 2 = backend never came up

set -uo pipefail

# scripts/ -> repo root. One level up, not two: this is scripts/verify_api.sh.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
LOG="${OMNIVEST_VERIFY_LOG:-/tmp/omnivest-verify.log}"
PIDFILE="$(mktemp -u /tmp/omnivest-verify.XXXXXX.pid)"

# Never inherit a stale journal: a leftover file from a crashed run would make
# the test's own "entry persisted" assertions pass for the wrong reason.
rm -f "$BACKEND/omnivest_journal.json"

cleanup() {
  if [[ -f "$PIDFILE" ]]; then
    local pid
    pid="$(cat "$PIDFILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      # Give uvicorn a moment to close the listener before we return.
      for _ in $(seq 1 20); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
      done
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
  fi
}
trap cleanup EXIT INT TERM

echo "── booting backend (log: $LOG) ──"
(
  cd "$BACKEND" || exit 2
  OMNIVEST_RELOAD=0 ./.venv/bin/python run.py
) > "$LOG" 2>&1 &
echo $! > "$PIDFILE"

# Poll the health endpoint rather than sleeping a fixed amount. A fixed sleep is
# either too short on a cold box (spurious failure) or too long every other run.
ready=0
for _ in $(seq 1 60); do
  if curl -sf --max-time 2 http://127.0.0.1:8123/api/health >/dev/null 2>&1; then
    ready=1
    break
  fi
  # If the process died, stop waiting and say so instead of timing out silently.
  if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    break
  fi
  sleep 0.5
done

if [[ "$ready" -ne 1 ]]; then
  echo "FATAL: backend did not become healthy within 30s"
  echo "──── last 30 log lines ────"
  tail -30 "$LOG"
  exit 2
fi

cd "$BACKEND" || exit 2
./.venv/bin/python -m app.tests.test_api
status=$?

echo "── stopped; server log: $LOG ──"
exit "$status"
