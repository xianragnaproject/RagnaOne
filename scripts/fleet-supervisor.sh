#!/usr/bin/env bash
# Long-running supervisor: keep fleet + watchdog + panel alive while the VM is up.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="${OPENKORE_HOME:-$HOME/openkore}"
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
LOG="${OK}/logs/fleet-supervisor.log"
mkdir -p "$(dirname "$LOG")"

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG"; }

log "supervisor start"

while true; do
  # Watchdog session
  if ! tmux -f "$TF" has-session -t '=ok-fleet-watchdog' 2>/dev/null; then
    log "restart fleet-watchdog"
    bash "$OK/scripts/start-fleet.sh" >>"$LOG" 2>&1 || true
  fi

  # Panel
  if ! tmux -f "$TF" has-session -t '=fleet-panel' 2>/dev/null; then
    log "restart fleet-panel"
    bash "$OK/scripts/start-fleet-panel.sh" >>"$LOG" 2>&1 || true
  fi

  # Ensure every Grind* profile has a session (watchdog also does this; belt+suspenders)
  if [[ -d "$OK/profiles" ]]; then
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      sess=$(printf 'ok-%s' "$p" | tr -c 'A-Za-z0-9_-' '_')
      if ! tmux -f "$TF" has-session -t "=$sess" 2>/dev/null; then
        log "restart missing bot $p"
        bash "$OK/scripts/start-bot.sh" "$p" >>"$LOG" 2>&1 || true
        sleep 1
      fi
    done < <(find "$OK/profiles" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -E '^Grind' | sort)
  fi

  sleep 60
done
