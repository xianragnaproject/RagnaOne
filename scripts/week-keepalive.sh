#!/usr/bin/env bash
# Keep Phase1/2 40-bot fleet alive while this Cursor VM exists.
set -u
unset LD_LIBRARY_PATH
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/home/ubuntu/.local/bin
ROOT=/home/ubuntu/openkore
TF=/exec-daemon/tmux.portal.conf
LOG="$ROOT/logs/week-keepalive.log"
mkdir -p "$ROOT/logs"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "[$(ts)] $*" >>"$LOG"; }

TMUX=(tmux -f "$TF")
cd "$ROOT" || exit 0

# 1) Ensure fleet bots are up
alive=$(ps -eo cmd= | awk '/perl \.\/openkore\.pl --profile=/{c++} END{print c+0}')
if [[ "${alive:-0}" -lt 35 ]]; then
  log "low alive=$alive — start-all"
  bash "$ROOT/run-bots.sh" start-all >>"$LOG" 2>&1 || true
fi

# 2) Ensure phase1-watchdog (168h) running
if ! "${TMUX[@]}" has-session -t '=phase1-watchdog' 2>/dev/null; then
  log "restart phase1-watchdog 168h"
  "${TMUX[@]}" new-session -d -s phase1-watchdog -c "$ROOT" -- bash -l
  sleep 1
  "${TMUX[@]}" send-keys -t 'phase1-watchdog:0.0' \
    "cd $ROOT; ./phase1-watchdog.sh 168 >> logs/phase1-watchdog.log 2>&1" C-m
fi

# 3) Ensure watch-bots-week looping
if ! "${TMUX[@]}" has-session -t '=watch-bots-week' 2>/dev/null; then
  log "restart watch-bots-week"
  "${TMUX[@]}" new-session -d -s watch-bots-week -c "$ROOT" -- bash -l
  sleep 1
  "${TMUX[@]}" send-keys -t 'watch-bots-week:0.0' \
    "cd $ROOT; while true; do ./watch-bots-8h.sh; done" C-m
fi

# 4) Heartbeat marker for uptime proof
alive=$(ps -eo cmd= | awk '/perl \.\/openkore\.pl --profile=/{c++} END{print c+0}')
avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
echo "$(ts) alive=$alive mem_avail=${avail}MB" > "$ROOT/logs/WEEK_ALIVE.txt"
# only log every ~10 min to keep file small
min=$(date +%M)
if [[ "$min" == "00" || "$min" == "10" || "$min" == "20" || "$min" == "30" || "$min" == "40" || "$min" == "50" ]]; then
  log "HB alive=$alive mem_avail=${avail}MB"
fi
