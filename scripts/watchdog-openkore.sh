#!/usr/bin/env bash
# Keep all mapped OpenKore bots really online 24/7.
# Process-alive is NOT enough — detect reconnect/GM-kick/AI-off and recover.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="${OPENKORE_HOME:-$ROOT/openkore}"
MAP="$ROOT/accounts/ACCOUNT_MAP.txt"
LEGACY_SESSION="${OK_TMUX_SESSION:-ok-connect}"
LOG_DIR="${OK_LOG_DIR:-/tmp/ok-run}"
LOG="$LOG_DIR/watchdog.log"
STATE_DIR="$LOG_DIR/watchdog-state"
TMUX_CFG="/exec-daemon/tmux.portal.conf"
[[ -f "$TMUX_CFG" ]] || TMUX_CFG=""
# Restart only if reconnect wait exceeds this (let OpenKore handle normal backoff)
RECONNECT_STALE_SEC="${OK_RECONNECT_STALE_SEC:-180}"
# Stagger between hard restarts so 20 bots don't stampede login
RESTART_STAGGER_SEC="${OK_RESTART_STAGGER_SEC:-8}"

mkdir -p "$LOG_DIR" "$ROOT/accounts" "$STATE_DIR"
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

# Classify pane health. Prints one of:
#   dead | password | reconnect:<sec> | connecting | ai_off | ingame | idle_login | unknown
classify_session() {
  local session="$1"
  if ! tmux_cmd has-session -t "=$session" 2>/dev/null; then
    echo "dead"
    return
  fi

  local cmd pane pid
  cmd="$(tmux_cmd list-panes -t "$session:0.0" -F '#{pane_current_command}' 2>/dev/null || true)"
  if [[ -z "$cmd" ]]; then
    echo "dead"
    return
  fi
  if ! echo "$cmd" | grep -qiE 'perl|bash|tee'; then
    echo "dead"
    return
  fi

  pane="$(tmux_cmd capture-pane -t "$session:0.0" -p -S -40 2>/dev/null || true)"
  pid="$(tmux_cmd list-panes -t "$session:0.0" -F '#{pane_pid}' 2>/dev/null || true)"

  local has_perl=0
  if [[ -n "$pid" ]] && pstree -p "$pid" 2>/dev/null | grep -q 'openkore.pl'; then
    has_perl=1
  elif pgrep -f 'perl ./openkore.pl' >/dev/null 2>&1 && echo "$cmd" | grep -qiE 'perl|bash|tee'; then
    # Fallback when pstree missing — session still looks alive
    has_perl=1
  fi
  if [[ "$has_perl" -eq 0 ]]; then
    echo "dead"
    return
  fi

  if echo "$pane" | grep -qE 'Enter your Ragnarok Online password again|Password Error for account'; then
    echo "password"
    return
  fi

  local wait_s=""
  wait_s="$(echo "$pane" | sed -n 's/.*connecting to Account Server in \([0-9][0-9]*\) seconds.*/\1/p' | tail -1)"
  if [[ -n "$wait_s" ]]; then
    echo "reconnect:${wait_s}"
    return
  fi

  if echo "$pane" | grep -qiE 'Connecting to Account Server|Connecting to Character Server|Connecting to Map Server|Closing connection to Account Server'; then
    # Mid-login handshake — not dead
    if echo "$pane" | grep -qiE 'You are now in the game|Map loaded|Your Coordinates:|attacking Monster|Calculating (lockMap |random )?route|anti-idle|PHASE1'; then
      :
    else
      echo "connecting"
      return
    fi
  fi

  if echo "$pane" | grep -qE 'AI turned off|AI is turned off'; then
    # Only treat as ai_off if last AI line is off (not followed by on)
    local last_ai
    last_ai="$(echo "$pane" | grep -E 'AI (turned|set to|is already)' | tail -1 || true)"
    if echo "$last_ai" | grep -qE 'turned off|is turned off'; then
      echo "ai_off"
      return
    fi
  fi

  if echo "$pane" | grep -qiE 'attacking Monster|You attack Monster|Finished attacking|Target Monster|Calculating (lockMap |random )?route|anti-idle step|PHASE1:|Gathering:|You are now attacking|Location:|Map Change:'; then
    echo "ingame"
    return
  fi

  if echo "$pane" | grep -qiE 'You are now in the game|Your Coordinates:|NPC Exists:|Homunculus automatic feeding|Pet automatic feeding'; then
    # Logged in but no AI activity visible in recent pane — may be frozen/parked
    echo "idle_login"
    return
  fi

  echo "unknown"
}

send_ai_on() {
  local session="$1"
  tmux_cmd send-keys -t "$session:0.0" 'ai on' C-m 2>/dev/null || true
}

start_bot_name() {
  local name="$1"
  local stamp_file="$STATE_DIR/${name}.last_restart"
  local now last
  now="$(date +%s)"
  if [[ -f "$stamp_file" ]]; then
    last="$(cat "$stamp_file" 2>/dev/null || echo 0)"
    # Don't thrash the same bot more than once per 90s
    if [[ -n "$last" && $((now - last)) -lt 90 ]]; then
      log "SKIP restart $name (cooldown $((now - last))s)"
      return 0
    fi
  fi
  echo "$now" > "$stamp_file"
  log "Starting bot $name"
  bash "$ROOT/scripts/start-bot.sh" "$name" >>"$LOG" 2>&1 || log "WARN: failed to start $name"
  sleep "$RESTART_STAGGER_SEC"
}

ensure_once() {
  local name session state wait_s
  local any=0
  local restarted=0

  while read -r name; do
    [[ -z "$name" ]] && continue
    any=1
    session="$(session_for "$name")"
    state="$(classify_session "$session")"

    case "$state" in
      dead|password)
        log "Bot $name $state — hard restart"
        start_bot_name "$name"
        restarted=1
        ;;
      reconnect:*)
        wait_s="${state#reconnect:}"
        if [[ "$wait_s" =~ ^[0-9]+$ && "$wait_s" -gt "$RECONNECT_STALE_SEC" ]]; then
          log "Bot $name reconnect stale (${wait_s}s > ${RECONNECT_STALE_SEC}s) — restart"
          start_bot_name "$name"
          restarted=1
        else
          echo "reconnecting $name session=$session wait=${wait_s}s"
        fi
        ;;
      connecting)
        echo "connecting $name session=$session"
        ;;
      ai_off)
        log "Bot $name AI off — sending ai on"
        send_ai_on "$session"
        echo "ai_recovered $name session=$session"
        ;;
      idle_login)
        # Likely parked or frozen after login — nudge AI on; don't kill (causes dual-login storms)
        send_ai_on "$session"
        echo "idle_login $name session=$session (nudged ai on)"
        ;;
      ingame)
        echo "online $name session=$session"
        ;;
      *)
        echo "unknown $name session=$session state=$state"
        send_ai_on "$session"
        ;;
    esac
  done < <(list_bots)

  if [[ $any -eq 0 ]]; then
    if pgrep -f 'perl ./openkore.pl' >/dev/null 2>&1; then
      echo "online legacy"
    else
      log "No bots mapped and none running"
      return 1
    fi
  fi
  return 0
}

watch_loop() {
  log "Watchdog multi-bot loop starting (stale_reconnect=${RECONNECT_STALE_SEC}s stagger=${RESTART_STAGGER_SEC}s)"
  while true; do
    ensure_once >>"$LOG" 2>&1 || true
    sleep "${OK_WATCHDOG_INTERVAL:-30}"
  done
}

status_all() {
  local name session state
  local n=0
  while read -r name; do
    [[ -z "$name" ]] && continue
    n=$((n+1))
    session="$(session_for "$name")"
    state="$(classify_session "$session")"
    printf '%-14s %-12s tmux=%s\n' "$state" "$name" "$session"
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
