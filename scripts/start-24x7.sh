#!/usr/bin/env bash
# Per-boot 24/7 helper. Must terminate (used as environment start).
# Starts a tmux watchdog when credentials are present; otherwise no-ops.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSION="ok-24x7"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "24/7 watchdog already running in tmux session $SESSION"
  exit 0
fi

if [[ -z "${RO_USERNAME:-}" || -z "${RO_PASSWORD:-}" ]]; then
  echo "24/7 watchdog armed. Set RO_USERNAME and RO_PASSWORD, then: bash $ROOT/scripts/start-24x7.sh"
  exit 0
fi

tmux new-session -d -s "$SESSION" "bash $ROOT/scripts/watchdog-openkore.sh"
echo "Started 24/7 OpenKore watchdog in tmux session $SESSION"
exit 0
