#!/usr/bin/env bash
# Stop one OpenKore profile (kills its tmux session).
set -euo pipefail
PROFILE="${1:-}"
[[ -n "$PROFILE" ]] || { echo "Usage: $0 <ProfileName>"; exit 1; }
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
if [[ "$PROFILE" == "Nemo" ]]; then
  SESSION=openkore
else
  SESSION=$(printf 'ok-%s' "$PROFILE" | tr -c 'A-Za-z0-9_-' '_' )
  SESSION="${SESSION#_}"; SESSION="${SESSION%_}"
fi
if tmux -f "$TF" has-session -t "=$SESSION" 2>/dev/null; then
  tmux -f "$TF" kill-session -t "=$SESSION"
  echo "Stopped $PROFILE ($SESSION)"
else
  echo "Not running: $PROFILE"
fi
