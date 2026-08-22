#!/usr/bin/env bash
# Phase1 8-hour watchdog — keep OpenKore bots alive and healthy.
# Usage: ./phase1-watchdog.sh [hours]
set -u
# Avoid OpenKore's custom LD_LIBRARY_PATH breaking system awk/grep tools
unset LD_LIBRARY_PATH
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/home/ubuntu/.local/bin
ROOT=/home/ubuntu/openkore
TMUX_BIN=(tmux)
if [[ -f /exec-daemon/tmux.portal.conf ]]; then TMUX_BIN=(tmux -f /exec-daemon/tmux.portal.conf); fi
cd "$ROOT"
HOURS="${1:-8}"
END=$(( $(date +%s) + HOURS * 3600 ))
LOG="$ROOT/logs/phase1-watchdog.log"
STATE="$ROOT/logs/phase1-watchdog.state"
AWK=/usr/bin/awk
mkdir -p "$ROOT/logs"
: > "$STATE"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

bot_pids() { ps -eo pid=,cmd= | $AWK '/perl \.\/openkore\.pl --profile=/{print $1,$0}'; }

kill_bot() {
  local p=$1
  local pid
  pid=$(ps -eo pid=,cmd= | $AWK -v p="$p" '$0 ~ "perl ./openkore.pl --profile="p {print $1; exit}')
  if [[ -n "${pid:-}" ]]; then kill -9 "$pid" 2>/dev/null || true; fi
  "${TMUX_BIN[@]}" kill-session -t "ok-$p" 2>/dev/null || true
}

start_bot() {
  local p=$1
  "$ROOT/run-bots.sh" status >/dev/null 2>&1 || true
  "${TMUX_BIN[@]}" kill-session -t "ok-$p" 2>/dev/null || true
  "${TMUX_BIN[@]}" new-session -d -s "ok-$p" -c "$ROOT" -- bash -l
  # Keep stdin on the tmux TTY so send-keys works; tee still captures logs
  "${TMUX_BIN[@]}" send-keys -t "ok-$p:0.0" "cd $ROOT; export PATH=/home/ubuntu/.local/bin:\$PATH; export LD_LIBRARY_PATH=/home/ubuntu/.local/lib:/home/ubuntu/.local/sysroot/usr/lib/x86_64-linux-gnu; perl ./openkore.pl --profile=$p --interface=Console::Simple 2>&1 | tee -a logs/${p}.log" C-m
  sleep 2
  # dismiss any startup prompts
  "${TMUX_BIN[@]}" send-keys -t "ok-$p:0.0" Enter Enter Enter Enter
  log "started $p"
}

send_cmd() {
  local p=$1; shift
  "${TMUX_BIN[@]}" send-keys -t "ok-$p:0.0" "$*" Enter 2>/dev/null || true
}

parse_title() {
  # Extract latest OSC title snapshot from log: B#, J#, map, AI queue
  local f=$1
  local line
  line=$(grep -a $'\033]2;' "$f" 2>/dev/null | tail -1 | tr -d '\000' || true)
  # strip ANSI / OSC junk for state file
  echo "$line" | sed -E 's/\x1b\[[0-9;]*m//g; s/\x1b\]2;//g; s/\x07.*//; s/\x1b.*//g' | tail -c 300
}

check_errors() {
  local p=$1
  local f="$ROOT/logs/${p}.log"
  [[ -f "$f" ]] || return 0
  # recent window: last ~2000 lines
  local recent
  recent=$(tail -n 2000 "$f" | sed -E 's/\x1b\[[0-9;]*m//g')
  local issues=0

  if echo "$recent" | grep -q '\[macro\].*error'; then
    # Only act on fresh errors in the very end of the log (avoid replaying old ones forever)
    local fresh
    fresh=$(tail -n 80 "$f" | sed -E 's/\x1b\[[0-9;]*m//g' | grep -c '\[macro\].*error' || true)
    if [[ "$fresh" -gt 0 ]]; then
      log "$p MACRO_ERROR (fresh=$fresh) — reload macros; do not clear Busy mid-job blindly"
      send_cmd "$p" "reload macros"
      # If Busy stuck with expired BusyUntil, clear; else leave job/AFK alone
      local untilv now
      untilv=$(grep '^Phase1BusyUntil' "$ROOT/profiles/$p/config.txt" | $AWK '{print $2}')
      now=$(date +%s)
      if grep -q '^Phase1Busy 1' "$ROOT/profiles/$p/config.txt"; then
        if [[ -z "${untilv:-}" || ! "$untilv" =~ ^[0-9]+$ || "$now" -ge "$untilv" ]]; then
          log "$p clearing expired Busy after macro error"
          send_cmd "$p" "conf Phase1Busy 0"
          send_cmd "$p" "conf Phase1BusyUntil"
          send_cmd "$p" "ai on"
          send_cmd "$p" "conf attackAuto 2"
        fi
      else
        send_cmd "$p" "ai on"
      fi
      issues=1
    fi
  fi
  if echo "$recent" | grep -q 'cannot find label'; then
    log "$p LABEL_ERROR — macros need fix/reload"
    send_cmd "$p" "reload macros"
    issues=1
  fi
  if echo "$recent" | grep -q 'Unknown skill'; then
    log "$p SKILL_LIST_ERROR — unknown skill in skillsAddAuto_list"
    send_cmd "$p" "conf skillsAddAuto 0"
    issues=1
  fi
  if echo "$recent" | grep -q 'Unknown stat'; then
    log "$p STAT_LIST_ERROR — unknown stat in statsAddAuto_list"
    send_cmd "$p" "conf statsAddAuto 0"
    issues=1
  fi

  # Disconnect storm: many disconnects in recent log without reconnecting in game
  local dc
  dc=$(echo "$recent" | grep -ci 'disconnected' || true)
  if [[ "$dc" -gt 20 ]]; then
    log "$p DISCONNECT_STORM count=$dc — restart"
    kill_bot "$p"; sleep 2; start_bot "$p"
    issues=1
  fi

  # Busy stuck in config
  if grep -q '^Phase1Busy 1' "$ROOT/profiles/$p/config.txt" 2>/dev/null; then
    local untilv now
    untilv=$(grep '^Phase1BusyUntil' "$ROOT/profiles/$p/config.txt" | $AWK '{print $2}')
    now=$(date +%s)
    if [[ -n "${untilv:-}" && "$untilv" =~ ^[0-9]+$ && "$now" -gt $((untilv + 60)) ]]; then
      log "$p BUSY_STUCK past BusyUntil — force clear via conf"
      send_cmd "$p" "conf Phase1Busy 0"
      send_cmd "$p" "conf Phase1BusyUntil"
      send_cmd "$p" "ai on"
      send_cmd "$p" "conf attackAuto 2"
      issues=1
    fi
  fi

  # Stuck position: same map/coords in title for too long (and not AFK busy)
  local snap
  snap=$(parse_title "$f")
  local prev=""
  if [[ -f "$STATE" ]]; then
    prev=$(grep "^$p|" "$STATE" | tail -1 || true)
  fi
  local nowts
  nowts=$(date +%s)
  echo "$p|$nowts|$snap" >> "$STATE"
  # keep state file small
  tail -n 500 "$STATE" > "$STATE.tmp" 2>/dev/null && mv "$STATE.tmp" "$STATE"

  if [[ -n "$prev" && -n "$snap" ]]; then
    local prev_ts prev_snap
    prev_ts=$(echo "$prev" | cut -d'|' -f2)
    prev_snap=$(echo "$prev" | cut -d'|' -f3-)
    # Compare map+coords portion if both contain a map name
    local a b
    a=$(echo "$prev_snap" | grep -oE '[0-9]+,[0-9]+ [a-z0-9_]+' | tail -1 || true)
    b=$(echo "$snap" | grep -oE '[0-9]+,[0-9]+ [a-z0-9_]+' | tail -1 || true)
    if [[ -n "$a" && "$a" == "$b" && "$nowts" -gt $((prev_ts + 600)) ]]; then
      # same tile 10+ minutes — only if not intentionally Busy
      if ! grep -q '^Phase1Busy 1' "$ROOT/profiles/$p/config.txt" 2>/dev/null; then
        log "$p POSITION_STUCK at $b for >10m — ai clear + re-lock"
        send_cmd "$p" "ai clear"
        send_cmd "$p" "ai on"
        send_cmd "$p" "conf attackAuto 2"
        send_cmd "$p" "macro phase1_setLock"
        # if still same later loops, restart
        local stuck_count
        stuck_count=$(grep -c "$p POSITION_STUCK" "$LOG" || true)
        if [[ "$stuck_count" -gt 3 ]]; then
          log "$p POSITION_STUCK repeated — restart"
          kill_bot "$p"; sleep 2; start_bot "$p"
        fi
        issues=1
      fi
    fi
  fi

  return $issues
}

ensure_running() {
  local p=$1
  if ! ps -eo cmd= | grep -q "[p]erl ./openkore.pl --profile=$p"; then
    log "$p DEAD — restarting"
    start_bot "$p"
    return 1
  fi
  return 0
}

mem_guard() {
  local avail
  avail=$($AWK '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  [[ -z "$avail" ]] && avail=0
  if [[ "$avail" -lt 40 ]]; then
    log "LOW_MEM available=${avail}MB — bounce bot2 to reclaim RAM"
    if ps -eo cmd= | grep -q '[p]erl ./openkore.pl --profile=bot2'; then
      kill_bot bot2
      sleep 3
      sync || true
      start_bot bot2
    fi
  fi
}

BOTS_FILE="$ROOT/profiles/FLEET_40.txt"
mapfile -t BOTS < <(if [[ -f "$BOTS_FILE" ]]; then awk 'NF' "$BOTS_FILE"; else echo bot1; echo bot2; fi)

# Bootstrap: ensure bots up with TTY-capable launcher
log "=== Phase1 watchdog start (${HOURS}h bots=${#BOTS[@]}) ==="
# Patch NextAfk if missing/stale far past (avoid AFK spam on boot)
now=$(date +%s)
for p in "${BOTS[@]}"; do
  conf="$ROOT/profiles/$p/config.txt"
  if grep -q '^Phase1BusyUntil' "$conf"; then
    :
  else
    echo 'Phase1BusyUntil' >> "$conf"
  fi
  next=$(grep '^Phase1NextAfk' "$conf" | $AWK '{print $2}')
  if [[ -z "${next:-}" || ! "$next" =~ ^[0-9]+$ || "$next" -lt $((now - 60)) ]]; then
    # if overdue by a lot, push 30m from now so watchdog start doesn't force AFK
    python3 - "$conf" "$now" <<'PY'
import re,sys
p,now=sys.argv[1],int(sys.argv[2])
t=open(p).read()
val=str(now+1800)
if re.search(r'^Phase1NextAfk',t,re.M):
    t=re.sub(r'^Phase1NextAfk.*$', 'Phase1NextAfk '+val, t, flags=re.M)
else:
    t+='\nPhase1NextAfk '+val+'\n'
open(p,'w').write(t)
print('set',p,'Phase1NextAfk',val)
PY
  fi
  ensure_running "$p" || true
done

# Reload macros on live bots (TTY mode)
sleep 5
for p in "${BOTS[@]}"; do
  send_cmd "$p" "reload macros"
  send_cmd "$p" "conf Phase1Busy 0"
done

log "entering monitor loop until $(date -u -d @$END +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u)"

while [[ $(date +%s) -lt $END ]]; do
  mem_guard
  for p in "${BOTS[@]}"; do
    ensure_running "$p" || continue
    check_errors "$p" || true
  done
  # heartbeat status line
  alive=$(ps -eo cmd= | awk "/perl \.\\/openkore\.pl --profile=/{c++} END{print c+0}")
  log "HB alive=$alive/${#BOTS[@]}"
  for p in bot1 bot2; do
    title=$(parse_title "$ROOT/logs/${p}.log" | tr '\n' ' ' | cut -c1-120)
    log "HB $p=$title"
  done
  avail=$($AWK '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  [[ -z "$avail" ]] && avail=0
  log "HB mem_avail=${avail}MB"
  sleep 120
done

log "=== Phase1 watchdog finished ==="
