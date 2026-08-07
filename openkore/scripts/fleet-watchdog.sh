#!/usr/bin/env bash
# Keep grind (and optional) OpenKore fleet online 24/7.
# - Ensures tmux sessions + perl processes are running
# - Auto-answers stuck character-select prompts
# - Forces relog if pane sits on "disconnected" too long
set -uo pipefail

TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
OK="${OPENKORE_HOME:-$HOME/openkore}"
LOG_DIR="${OK}/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/fleet-watchdog.log"
INTERVAL="${WATCHDOG_INTERVAL:-45}"

# Default fleet: fresh grind party
PROFILES=(
  GrindSword
  GrindPrt08
  GrindMage
  GrindArcher
  GrindAco
  GrindMerch
)

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG"; }

session_for() {
  local p="$1"
  if [[ "$p" == "Nemo" ]]; then
    echo openkore
  else
    printf 'ok-%s' "$p" | tr -c 'A-Za-z0-9_-' '_'
  fi
}

pane_text() {
  local s="$1"
  tmux -f "$TF" capture-pane -t "${s}:0.0" -p -S -40 2>/dev/null | tr -d '\r' || true
}

ensure_session() {
  local profile="$1"
  local session
  session=$(session_for "$profile")
  if ! tmux -f "$TF" has-session -t "=$session" 2>/dev/null; then
    log "START session $session for $profile"
    tmux -f "$TF" new-session -d -s "$session" -c "$OK" -- "${SHELL:-bash}" -l
    sleep 1
    tmux -f "$TF" send-keys -t "${session}:0.0" "$OK/scripts/run-profile.sh $profile" C-m
    return
  fi
  # Session exists but openkore not running?
  if ! pgrep -af "openkore.pl --profile=${profile}" >/dev/null 2>&1; then
    local text
    text=$(pane_text "$session")
    # Avoid double-start if run-profile sleep/restart window
    if echo "$text" | grep -q 'run-profile.*restarting'; then
      return
    fi
    log "RESTART process $profile (no openkore.pl)"
    tmux -f "$TF" send-keys -t "${session}:0.0" C-c
    sleep 1
    tmux -f "$TF" send-keys -t "${session}:0.0" "$OK/scripts/run-profile.sh $profile" C-m
  fi
}

heal_stuck_prompts() {
  local profile="$1"
  local session text
  session=$(session_for "$profile")
  text=$(pane_text "$session")
  if echo "$text" | grep -q 'Please choose a character' && echo "$text" | grep -q 'Enter your answer:'; then
    # only if answer line is empty / waiting
    if echo "$text" | tail -5 | grep -q 'Enter your answer:$'; then
      log "CHARSELECT send 0 → $profile"
      tmux -f "$TF" send-keys -t "${session}:0.0" '0' C-m
      return
    fi
  fi
  if echo "$text" | grep -q 'Please choose a server' && echo "$text" | tail -5 | grep -q 'Enter your answer:$'; then
    log "SERVERSELECT send 0 → $profile"
    tmux -f "$TF" send-keys -t "${session}:0.0" '0' C-m
    return
  fi
  # Stuck disconnected with long wait / idle shell
  if echo "$text" | tail -8 | grep -q '^disconnected$'; then
    # If also showing reconnect countdown recently, leave it; else nudge relog
    if ! echo "$text" | tail -15 | grep -qiE 'connecting|Connecting|Relogging|Wait .* seconds|Timeout on'; then
      log "RELOG nudge $profile (idle disconnected)"
      tmux -f "$TF" send-keys -t "${session}:0.0" 'relog 3' C-m
    fi
  fi
}

log "watchdog start interval=${INTERVAL}s profiles=${PROFILES[*]}"
while true; do
  for p in "${PROFILES[@]}"; do
    [[ -f "$OK/profiles/$p/config.txt" ]] || continue
    ensure_session "$p"
    heal_stuck_prompts "$p"
  done
  sleep "$INTERVAL"
done
