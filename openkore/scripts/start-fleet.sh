#!/usr/bin/env bash
# Start grind fleet + 24/7 watchdog
set -euo pipefail
OK="${HOME}/openkore"
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
PROFILES=(GrindSword GrindPrt08 GrindMage GrindArcher GrindAco GrindMerch)
for p in "${PROFILES[@]}"; do
  "$OK/scripts/start-bot.sh" "$p" || true
done
SESSION=ok-fleet-watchdog
if ! tmux -f "$TF" has-session -t "=$SESSION" 2>/dev/null; then
  tmux -f "$TF" new-session -d -s "$SESSION" -c "$OK" -- bash -lc 'bash ~/openkore/scripts/fleet-watchdog.sh'
  echo "Started watchdog → tmux attach -t $SESSION"
else
  echo "Watchdog already running: $SESSION"
fi
