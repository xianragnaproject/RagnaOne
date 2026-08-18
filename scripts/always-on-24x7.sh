#!/usr/bin/env bash
# Forever loop — keep fleet + watchdogs alive while this process/VM exists.
set -u
unset LD_LIBRARY_PATH
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/home/ubuntu/.local/bin
ROOT=/home/ubuntu/openkore
TF=/exec-daemon/tmux.portal.conf
LOG="$ROOT/logs/always-on-24x7.log"
mkdir -p "$ROOT/logs"
cd "$ROOT" || exit 1
TMUX=(tmux -f "$TF")
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG"; }

log "ALWAYS-ON 24/7 START (week target end=$(cat logs/WEEK_END.txt 2>/dev/null || echo unknown))"

while true; do
  # bots
  alive=$(ps -eo cmd= | awk '/perl \.\/openkore\.pl --profile=/{c++} END{print c+0}')
  if [[ "${alive:-0}" -lt 35 ]]; then
    log "heal bots alive=$alive → start-all"
    bash "$ROOT/run-bots.sh" start-all >>"$LOG" 2>&1 || true
  fi

  # phase1 watchdog 168h
  if ! "${TMUX[@]}" has-session -t '=phase1-watchdog' 2>/dev/null; then
    log "heal phase1-watchdog"
    "${TMUX[@]}" new-session -d -s phase1-watchdog -c "$ROOT" -- bash -l
    sleep 1
    "${TMUX[@]}" send-keys -t 'phase1-watchdog:0.0' \
      "cd $ROOT; ./phase1-watchdog.sh 168 >> logs/phase1-watchdog.log 2>&1" C-m
  fi

  # watch loop
  if ! "${TMUX[@]}" has-session -t '=watch-bots-week' 2>/dev/null; then
    log "heal watch-bots-week"
    "${TMUX[@]}" new-session -d -s watch-bots-week -c "$ROOT" -- bash -l
    sleep 1
    "${TMUX[@]}" send-keys -t 'watch-bots-week:0.0' \
      "cd $ROOT; while true; do ./watch-bots-8h.sh; done" C-m
  fi

  # ai on nudge for any bot with AI off (best-effort, light)
  if (( $(date +%M) % 5 == 0 )); then
    while read -r b; do
      "${TMUX[@]}" send-keys -t "ok-$b:0.0" 'ai on' Enter 2>/dev/null || true
    done < "$ROOT/profiles/FLEET_40.txt"
  fi

  alive=$(ps -eo cmd= | awk '/perl \.\/openkore\.pl --profile=/{c++} END{print c+0}')
  avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) alive=$alive mem_avail=${avail}MB" > "$ROOT/logs/WEEK_ALIVE.txt"
  log "HB alive=$alive mem=${avail}MB"
  sleep 45
done
