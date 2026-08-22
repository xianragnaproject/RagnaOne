#!/usr/bin/env bash
# Start the FreshGrind fleet control panel (web UI).
set -euo pipefail
OK="${OPENKORE_HOME:-$HOME/openkore}"
# Prefer workspace pack when present (same tree when symlinked)
if [[ -f /workspace/openkore/fleet_panel/app.py ]]; then
  PANEL=/workspace/openkore/fleet_panel
  OK=/workspace/openkore
else
  PANEL="${OK}/fleet_panel"
fi
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
SESSION="${FLEET_PANEL_SESSION:-fleet-panel}"
PORT="${FLEET_PANEL_PORT:-8787}"
PASS_FILE="${FLEET_PANEL_PASS_FILE:-$PANEL/panel.pass}"

mkdir -p "$PANEL"
if [[ ! -f "$PASS_FILE" ]]; then
  PASS=$(python3 -c 'import secrets; print("fg-" + secrets.token_urlsafe(10))')
  printf '%s\n' "$PASS" > "$PASS_FILE"
  chmod 600 "$PASS_FILE"
  echo "Created panel password → $PASS_FILE"
  echo "PASSWORD: $PASS"
else
  echo "Password file: $PASS_FILE"
fi

if tmux -f "$TF" has-session -t "=$SESSION" 2>/dev/null; then
  echo "Already running: tmux attach -t $SESSION (port $PORT)"
  exit 0
fi

export OPENKORE_HOME="$OK"
export FLEET_PANEL_PORT="$PORT"
export FLEET_PANEL_PASS_FILE="$PASS_FILE"
tmux -f "$TF" new-session -d -s "$SESSION" -c "$PANEL" -- bash -l
sleep 1
tmux -f "$TF" send-keys -t "$SESSION:0.0" \
  "OPENKORE_HOME='$OK' FLEET_PANEL_PASS_FILE='$PASS_FILE' FLEET_PANEL_PORT='$PORT' python3 app.py" C-m
echo "Fleet panel → http://127.0.0.1:${PORT}/  (tmux: $SESSION)"
