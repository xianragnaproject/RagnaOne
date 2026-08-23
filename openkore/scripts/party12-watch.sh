#!/usr/bin/env bash
# Watch Party12: restart down bots; log levels / job / map every 60s.
set -euo pipefail
OK="${OPENKORE_HOME:-$HOME/openkore}"
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
LIST="${FLEET_LIST:-$OK/profiles/FLEET_PARTY12.txt}"
LOG="${PARTY12_WATCH_LOG:-/tmp/party12-watch.log}"
INTERVAL="${WATCH_INTERVAL:-60}"

status_one() {
  local p="$1" sess out
  sess=$(printf 'ok-%s' "$p" | tr -c 'A-Za-z0-9_-' '_' )
  sess="${sess#_}"; sess="${sess%_}"
  if ! tmux -f "$TF" has-session -t "=$sess" 2>/dev/null; then
    echo -e "$p\tDOWN\t"
    return 1
  fi
  out=$(tmux -f "$TF" capture-pane -t "$sess" -p -S -80 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' || true)
  local map job bl jl detail
  map=$(echo "$out" | grep -oE 'Map Change: [a-z0-9_@-]+' | tail -1 | sed 's/Map Change: //' || true)
  [[ -z "$map" ]] && map=$(echo "$out" | grep -oE '(prt_fild08|prt_fild[0-9]+|prontera|prt_in|payon|pay_fild[0-9]+|izlude|morocc|geffen|new_[0-9]-[0-9]+|iz_int|job_[a-z]+)' | tail -1 || true)
  bl=$(echo "$out" | grep -oE 'Base Level: [0-9]+|Lv: [0-9]+/[0-9]+' | tail -1 || true)
  jl=$(echo "$out" | grep -oE 'Job Level: [0-9]+|Job: [A-Za-z ]+ \([0-9]+\)' | tail -1 || true)
  job=$(echo "$out" | grep -oE 'You are now a [A-Za-z ]+|Job changed to [A-Za-z ]+|Swordman|Magician|Archer|Acolyte|Merchant|Thief|Novice' | tail -1 || true)
  if echo "$out" | grep -qiE 'Password Error|permanently banned'; then
    detail=LOGIN_FAIL
  elif echo "$out" | grep -qE 'You attack|Monster .*died|Targeting|Attacking'; then
    detail=HUNTING
  elif echo "$out" | grep -qiE 'Following|followTarget|party request|Party created|joined the party'; then
    detail=PARTY
  elif echo "$out" | grep -qiE 'sellAuto|Sold |weight'; then
    detail=SELL
  elif echo "$out" | grep -qiE 'Connecting|disconnected|Pausing'; then
    detail=CONNECTING
  else
    detail=ONLINE
  fi
  echo -e "$p\t$detail\t${map:-?} ${bl:-} ${jl:-} ${job:-}"
  return 0
}

echo "party12-watch start $(date -u +%FT%TZ)" | tee -a "$LOG"
while true; do
  mapfile -t PROFILES < <(grep -vE '^\s*(#|$)' "$LIST")
  ts=$(date -u +%FT%TZ)
  {
    echo "==== $ts ===="
    up=0
    for p in "${PROFILES[@]}"; do
      if status_one "$p"; then
        up=$((up + 1))
      else
        echo "restart $p" | tee -a "$LOG"
        "$OK/scripts/start-bot.sh" "$p" || true
        sleep 5
      fi
    done
    echo "up=$up/${#PROFILES[@]}"
  } | tee -a "$LOG"
  sleep "$INTERVAL"
done
