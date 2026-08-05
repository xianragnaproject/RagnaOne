#!/usr/bin/env bash
set -euo pipefail
PROFILE="${1:-}"
OK="${HOME}/openkore"
[[ -n "$PROFILE" ]] || { echo "Usage: $0 <ProfileName>"; ls -1 "$OK/profiles"; exit 1; }
[[ -f "$OK/profiles/$PROFILE/config.txt" ]] || { echo "Missing profile $PROFILE"; exit 1; }
SESSION=$(printf 'ok-%s' "$PROFILE" | tr -c 'A-Za-z0-9_-' '_' )
SESSION="${SESSION#_}"; SESSION="${SESSION%_}"
if tmux -f /exec-daemon/tmux.portal.conf has-session -t "=$SESSION" 2>/dev/null; then
  echo "Already running: tmux attach -t $SESSION"; exit 0
fi
tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION" -c "$OK" -- "${SHELL:-bash}" -l
tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION:0.0" "$OK/scripts/run-profile.sh $PROFILE" C-m
echo "Started $PROFILE → tmux attach -t $SESSION"
