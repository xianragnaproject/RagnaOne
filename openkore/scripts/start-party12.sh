#!/usr/bin/env bash
# Start Party12 fleet (2 per class, follow/assist leader).
set -euo pipefail
OK="${OPENKORE_HOME:-$HOME/openkore}"
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
LIST="${FLEET_LIST:-$OK/profiles/FLEET_PARTY12.txt}"
STAGGER_SEC="${STAGGER_SEC:-8}"

[[ -f "$LIST" ]] || { echo "Missing $LIST"; exit 1; }

mapfile -t PROFILES < <(grep -vE '^\s*(#|$)' "$LIST")
echo "Starting ${#PROFILES[@]} Party12 bots from $LIST (stagger ${STAGGER_SEC}s)..."
for p in "${PROFILES[@]}"; do
  "$OK/scripts/start-bot.sh" "$p" || true
  sleep "$STAGGER_SEC"
done

SESSION=ok-party12-watch
if ! tmux -f "$TF" has-session -t "=$SESSION" 2>/dev/null; then
  tmux -f "$TF" new-session -d -s "$SESSION" -c "$OK" -- bash -l
  sleep 1
  tmux -f "$TF" send-keys -t "${SESSION}:0.0" \
    "export OPENKORE_HOME='$OK' TMUX_CONF='$TF'; bash '$OK/scripts/party12-watch.sh'" C-m
  echo "Started party12 watch → tmux attach -t $SESSION"
else
  echo "Watch already running: $SESSION"
fi
