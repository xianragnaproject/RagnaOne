#!/usr/bin/env bash
# Keep all mapped OpenKore bots online 24/7 (restart on crash / exit).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="${OPENKORE_HOME:-$ROOT/openkore}"
MAP="$ROOT/accounts/ACCOUNT_MAP.txt"
# Legacy single-bot session still supported
LEGACY_SESSION="${OK_TMUX_SESSION:-ok-connect}"
LOG_DIR="${OK_LOG_DIR:-/tmp/ok-run}"
LOG="$LOG_DIR/watchdog.log"
TMUX_CFG="/exec-daemon/tmux.portal.conf"
[[ -f "$TMUX_CFG" ]] || TMUX_CFG=""

mkdir -p "$LOG_DIR" "$ROOT/accounts"
ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { echo "$(ts) $*" | tee -a "$LOG"; }

tmux_cmd() {
  if [[ -n "$TMUX_CFG" ]]; then tmux -f "$TMUX_CFG" "$@"; else tmux "$@"; fi
}

list_bots() {
  local bots=()
  if [[ -f "$MAP" ]]; then
    while IFS=$'\t' read -r name session user pass char sex; do
      [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
      bots+=("$name")
    done < "$MAP"
  fi
  # Include legacy .env bot as Fresh1 if map empty / missing
  if [[ ${#bots[@]} -eq 0 && -f "$ROOT/.env" ]]; then
    bots+=("Fresh1")
    if [[ ! -f "$ROOT/accounts/Fresh1.env" ]]; then
      cp "$ROOT/.env" "$ROOT/accounts/Fresh1.env"
      chmod 600 "$ROOT/accounts/Fresh1.env"
      if [[ ! -f "$MAP" ]]; then
        printf '%s\n' '# bot_name	session	username	password	char_name	sex' > "$MAP"
      fi
      # shellcheck disable=SC1091
      set -a; source "$ROOT/.env"; set +a
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "Fresh1" "ok-fresh1" "${RO_USERNAME}" "${RO_PASSWORD}" "OKFresh1" "M" >> "$MAP"
    fi
  fi
  printf '%s\n' "${bots[@]}"
}

session_for() {
  local name="$1"
  if [[ -f "$MAP" ]]; then
    local s
    s="$(awk -F'\t' -v n="$name" '$1==n{print $2; exit}' "$MAP")"
    if [[ -n "$s" ]]; then echo "$s"; return; fi
  fi
  echo "ok-$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
}

bot_pid_for_session() {
  local session="$1"
  # Match openkore.pl whose parent tmux pane belongs to session — approximate via log/runtime
  # Fallback: any openkore is fine for status; ensure uses start-bot.
  pgrep -af 'perl ./openkore.pl' 2>/dev/null | grep -c . || true
}

session_has_openkore() {
  local session="$1"
  tmux_cmd has-session -t "=$session" 2>/dev/null || return 1
  local pane
  pane="$(tmux_cmd capture-pane -t "$session:0.0" -p -S -12 2>/dev/null || true)"
  # Dead shell / exited
  if ! tmux_cmd list-panes -t "$session:0.0" -F '#{pane_current_command}' 2>/dev/null | grep -qiE 'perl|bash|tee'; then
    return 1
  fi
  # Stuck password prompt / bad login
  if echo "$pane" | grep -qE 'Enter your Ragnarok Online password again|Password Error for account'; then
    return 1
  fi
  # Reconnect backoff got huge — treat as inactive so we restart fresh
  if echo "$pane" | grep -qE 'connecting to Account Server in ([0-9]+) seconds'; then
    local wait_s
    wait_s="$(echo "$pane" | sed -n 's/.*connecting to Account Server in \([0-9][0-9]*\) seconds.*/\1/p' | tail -1)"
    if [[ -n "$wait_s" && "$wait_s" -gt 90 ]]; then
      return 1
    fi
  fi
  # Prefer detecting perl in the session's process tree
  local pid
  pid="$(tmux_cmd list-panes -t "$session:0.0" -F '#{pane_pid}' 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  if pstree -p "$pid" 2>/dev/null | grep -q 'openkore.pl'; then
    return 0
  fi
  # pstree may be missing — check pane still active and recent log activity
  pgrep -f 'perl ./openkore.pl' >/dev/null 2>&1
}

start_bot_name() {
  local name="$1"
  log "Starting bot $name"
  bash "$ROOT/scripts/start-bot.sh" "$name" >>"$LOG" 2>&1 || log "WARN: failed to start $name"
}

ensure_once() {
  local name session
  local any=0
  while read -r name; do
    [[ -z "$name" ]] && continue
    any=1
    session="$(session_for "$name")"
    if session_has_openkore "$session"; then
      echo "online $name session=$session"
    else
      log "Bot $name down — restarting"
      start_bot_name "$name"
    fi
  done < <(list_bots)

  # Also keep legacy ok-connect if it exists and map includes nothing for it
  if [[ $any -eq 0 ]]; then
    if pgrep -f 'perl ./openkore.pl' >/dev/null 2>&1; then
      echo "online legacy"
    else
      log "No bots mapped and none running"
      return 1
    fi
  fi
}

watch_loop() {
  log "Watchdog multi-bot loop starting"
  while true; do
    ensure_once >>"$LOG" 2>&1 || true
    sleep "${OK_WATCHDOG_INTERVAL:-30}"
  done
}

status_all() {
  local name session
  local n=0
  while read -r name; do
    [[ -z "$name" ]] && continue
    n=$((n+1))
    session="$(session_for "$name")"
    if session_has_openkore "$session"; then
      echo "online  $name  tmux=$session"
    else
      echo "offline $name  tmux=$session"
    fi
  done < <(list_bots)
  echo "openkore_procs=$(pgrep -c -f 'perl ./openkore.pl' 2>/dev/null || echo 0)"
  [[ $n -gt 0 ]]
}

case "${1:-ensure}" in
  ensure|once) ensure_once ;;
  start)
    while read -r name; do
      [[ -z "$name" ]] && continue
      start_bot_name "$name"
    done < <(list_bots)
    ;;
  loop|watch) watch_loop ;;
  status) status_all ;;
  stop)
    log "Stopping all bots"
    while read -r name; do
      [[ -z "$name" ]] && continue
      session="$(session_for "$name")"
      tmux_cmd send-keys -t "$session:0.0" 'quit' C-m 2>/dev/null || true
      sleep 1
      tmux_cmd kill-session -t "$session" 2>/dev/null || true
    done < <(list_bots)
    tmux_cmd kill-session -t "$LEGACY_SESSION" 2>/dev/null || true
    pkill -f 'perl ./openkore.pl' 2>/dev/null || true
    ;;
  *)
    echo "Usage: $0 {ensure|start|loop|status|stop}"
    exit 2
    ;;
esac
