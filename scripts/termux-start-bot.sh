#!/usr/bin/env bash
# Start one OpenKore bot inside the Ubuntu proot (called by ~/ok-start.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p /tmp/ok-run
USER_NAME="${1:-${RO_USERNAME:-}}"
PASS="${2:-${RO_PASSWORD:-}}"
SESSION="${OK_TMUX_SESSION:-ok-phone}"
if [[ -z "$USER_NAME" || -z "$PASS" ]]; then
  echo "Usage: termux-start-bot.sh <username> <password>" >&2
  exit 1
fi
export RO_USERNAME="$USER_NAME" RO_PASSWORD="$PASS"
if tmux has-session -t "=$SESSION" 2>/dev/null; then
  echo "Session $SESSION already running. Attach with: tmux attach -t $SESSION"
  exit 0
fi
tmux new-session -d -s "$SESSION" -c "$ROOT" -- \
  bash -lc "RO_USERNAME='$RO_USERNAME' RO_PASSWORD='$RO_PASSWORD' bash ./scripts/run-openkore.sh 2>&1 | tee -a /tmp/ok-run/phone.log"
echo "Started tmux session: $SESSION"
