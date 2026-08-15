#!/usr/bin/env bash
# Start (or restart) one named bot from accounts/<BotName>.env
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOT_NAME="${1:-}"
[[ -n "$BOT_NAME" ]] || { echo "Usage: $0 <BotName>"; exit 1; }

ENV_FILE="$ROOT/accounts/${BOT_NAME}.env"
[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE"; exit 1; }

SESSION="ok-$(echo "$BOT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
LOG_DIR="${OK_LOG_DIR:-/tmp/ok-run}"
BOT_LOG="$LOG_DIR/${SESSION}.log"
TMUX_CFG="/exec-daemon/tmux.portal.conf"
[[ -f "$TMUX_CFG" ]] || TMUX_CFG=""
mkdir -p "$LOG_DIR"

tmux_cmd() {
  if [[ -n "$TMUX_CFG" ]]; then tmux -f "$TMUX_CFG" "$@"; else tmux "$@"; fi
}

# Kill existing session for this bot
if tmux_cmd has-session -t "=$SESSION" 2>/dev/null; then
  tmux_cmd send-keys -t "$SESSION:0.0" 'quit' C-m 2>/dev/null || true
  sleep 2
  tmux_cmd kill-session -t "$SESSION" 2>/dev/null || true
  sleep 1
fi

tmux_cmd new-session -d -s "$SESSION" -c "$ROOT" -- \
  bash -lc "set -a; source '$ENV_FILE'; set +a; export RO_BOT_NAME='$BOT_NAME'; bash '$ROOT/scripts/connect-account.sh' 2>&1 | tee -a '$BOT_LOG'"

sleep 4
if pgrep -af "openkore.pl" | grep -q .; then
  echo "Started $BOT_NAME → tmux $SESSION (log $BOT_LOG)"
else
  echo "WARN: $BOT_NAME may not have stayed up — check $BOT_LOG" >&2
fi
