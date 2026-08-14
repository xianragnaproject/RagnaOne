#!/usr/bin/env bash
# Keep one OpenKore account online 24/7 (restart on crash / exit).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="${OPENKORE_HOME:-$ROOT/openkore}"
SESSION="${OK_TMUX_SESSION:-ok-connect}"
LOG_DIR="${OK_LOG_DIR:-/tmp/ok-run}"
LOG="$LOG_DIR/watchdog.log"
BOT_LOG="$LOG_DIR/phase1.log"
TMUX_CFG="/exec-daemon/tmux.portal.conf"
[[ -f "$TMUX_CFG" ]] || TMUX_CFG=""

mkdir -p "$LOG_DIR"
ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { echo "$(ts) $*" | tee -a "$LOG"; }

tmux_cmd() {
  if [[ -n "$TMUX_CFG" ]]; then
    tmux -f "$TMUX_CFG" "$@"
  else
    tmux "$@"
  fi
}

bot_pid() {
  pgrep -f 'perl ./openkore.pl' 2>/dev/null | head -1 || true
}

session_alive() {
  tmux_cmd has-session -t "=$SESSION" 2>/dev/null
}

start_bot() {
  mkdir -p "$LOG_DIR"
  if [[ ! -f "$ROOT/.env" ]]; then
    log "ERROR: missing $ROOT/.env (RO_USERNAME / RO_PASSWORD)"
    return 1
  fi
  if [[ ! -f "$OK/openkore.pl" ]]; then
    log "OpenKore missing — running setup"
    bash "$ROOT/scripts/setup-openkore.sh" >>"$LOG" 2>&1 || true
  fi
  # Ensure Phase1 macros present
  if [[ ! -f "$OK/control/eventMacros.txt" ]]; then
    bash "$ROOT/scripts/install-phase1.sh" >>"$LOG" 2>&1 || true
  fi

  if session_alive; then
    tmux_cmd kill-session -t "$SESSION" 2>/dev/null || true
    sleep 1
  fi

  log "Starting OpenKore in tmux session '$SESSION'"
  tmux_cmd new-session -d -s "$SESSION" -c "$ROOT" -- \
    bash -lc "set -a; source '$ROOT/.env'; set +a; bash '$ROOT/scripts/connect-account.sh' 2>&1 | tee -a '$BOT_LOG'"
  sleep 5
  if [[ -n "$(bot_pid)" ]]; then
    log "OpenKore up pid=$(bot_pid)"
    return 0
  fi
  log "WARN: OpenKore did not stay up after start"
  return 1
}

# One-shot ensure (safe for cron): start only if down
ensure_once() {
  local pid
  pid="$(bot_pid)"
  if [[ -n "$pid" ]]; then
    # Recover if AI was accidentally toggled off
    if session_alive; then
      # Best-effort: only nudge if map timeout / password prompt not present
      if ! tmux_cmd capture-pane -t "$SESSION:0.0" -p -S -15 2>/dev/null | grep -qE 'Enter your Ragnarok Online password|Enter your answer:'; then
        :
      fi
    fi
    echo "online pid=$pid"
    return 0
  fi
  log "OpenKore not running — restarting"
  start_bot
}

# Forever supervisor loop
watch_loop() {
  log "Watchdog loop starting (session=$SESSION)"
  while true; do
    if [[ -z "$(bot_pid)" ]]; then
      log "Bot process missing — restart"
      start_bot || true
    fi
    sleep "${OK_WATCHDOG_INTERVAL:-30}"
  done
}

case "${1:-ensure}" in
  ensure|once) ensure_once ;;
  start) start_bot ;;
  loop|watch) watch_loop ;;
  status)
    pid="$(bot_pid)"
    if [[ -n "$pid" ]]; then
      echo "online pid=$pid etime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')"
      session_alive && echo "tmux session: $SESSION" || echo "tmux session: missing"
    else
      echo "offline"
      exit 1
    fi
    ;;
  stop)
    log "Stopping bot + session"
    pkill -f 'perl ./openkore.pl' 2>/dev/null || true
    session_alive && tmux_cmd kill-session -t "$SESSION" 2>/dev/null || true
    ;;
  *)
    echo "Usage: $0 {ensure|start|loop|status|stop}"
    exit 2
    ;;
esac
