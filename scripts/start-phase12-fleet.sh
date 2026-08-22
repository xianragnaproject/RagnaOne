#!/usr/bin/env bash
set -euo pipefail
OK="${OPENKORE_HOME:-$HOME/openkore}"
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
cd "$OK"
bash ./run-bots.sh start-all || bash ./run-bots.sh start
bash "$OK/scripts/week-keepalive.sh" || true
# Detached 24/7 supervisor
if [[ -f "$TF" ]] && ! tmux -f "$TF" has-session -t '=always-on-24x7' 2>/dev/null; then
  tmux -f "$TF" new-session -d -s always-on-24x7 -c "$OK" -- bash -l
  sleep 1
  tmux -f "$TF" send-keys -t 'always-on-24x7:0.0' "bash '$OK/scripts/always-on-24x7.sh'" C-m
fi
