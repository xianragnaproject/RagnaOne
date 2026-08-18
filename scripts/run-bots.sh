#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ubuntu/openkore
cd "$ROOT"
if [[ -f /exec-daemon/tmux.portal.conf ]]; then
  TMUX=(tmux -f /exec-daemon/tmux.portal.conf)
else
  TMUX=(tmux)
fi
start_one() {
  local p=$1
  local pid
  pid=$(ps -eo pid=,cmd= | awk -v p="$p" '$0 ~ "perl ./openkore.pl --profile="p {print $1; exit}') || true
  if [[ -n "${pid:-}" ]]; then kill -9 "$pid" 2>/dev/null || true; fi
  "${TMUX[@]}" kill-session -t "ok-$p" 2>/dev/null || true
  "${TMUX[@]}" new-session -d -s "ok-$p" -c "$ROOT" -- bash -l
  # stdin stays on tmux TTY so console commands work; tee appends logs
  "${TMUX[@]}" send-keys -t "ok-$p:0.0" "cd $ROOT; export PATH=/home/ubuntu/.local/bin:\$PATH; export LD_LIBRARY_PATH=/home/ubuntu/.local/lib:/home/ubuntu/.local/sysroot/usr/lib/x86_64-linux-gnu; perl ./openkore.pl --profile=$p --interface=Console::Simple 2>&1 | tee -a logs/${p}.log" C-m
  sleep 2
  "${TMUX[@]}" send-keys -t "ok-$p:0.0" Enter Enter Enter Enter
  echo "started $p (tmux ok-$p)"
}
stop_one() {
  local p=$1
  "${TMUX[@]}" send-keys -t "ok-$p:0.0" "quit" Enter 2>/dev/null || true
  sleep 1
  local pid
  pid=$(ps -eo pid=,cmd= | awk -v p="$p" '$0 ~ "perl ./openkore.pl --profile="p {print $1; exit}') || true
  if [[ -n "${pid:-}" ]]; then kill -9 "$pid" 2>/dev/null || true; fi
  "${TMUX[@]}" kill-session -t "ok-$p" 2>/dev/null || true
  echo "stopped $p"
}
list_bots() {
  if [[ -f "$ROOT/profiles/FLEET_40.txt" ]]; then
    awk 'NF' "$ROOT/profiles/FLEET_40.txt"
  else
    printf '%s\n' bot1 bot2
  fi
}
case "${1:-}" in
  start)
    start_one bot1; sleep 8; start_one bot2; free -h | head -2
    ;;
  start-all)
    n=0
    while read -r p; do
      [[ -z "$p" ]] && continue
      start_one "$p"
      n=$((n+1))
      # stagger to avoid login stampede
      sleep 3
    done < <(list_bots)
    echo "started $n bots"
    free -h | head -2
    ;;
  stop|stop-all)
    while read -r p; do
      [[ -z "$p" ]] && continue
      stop_one "$p" || true
    done < <(list_bots)
    echo done
    ;;
  status)
    "${TMUX[@]}" ls 2>/dev/null | grep ok-bot || true
    ps -eo pid,rss,pcpu,cmd | awk '/perl \.\/openkore\.pl/'
    echo "running=$(ps -eo cmd | awk '/perl \.\/openkore\.pl --profile=/{c++} END{print c+0}')"
    free -h | head -2
    ;;
  *) echo "Usage: $0 {start|start-all|stop|stop-all|status}"; exit 1 ;;
esac
