#!/usr/bin/env bash
# Always-on fleet daemon for this VM (no systemd required).
# Single-instance via flock. Survives parent shells while the Cursor pod lives.
# Archive/kill of the Cursor agent still destroys the VM — keep the agent RUNNING.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="${OPENKORE_HOME:-$HOME/openkore}"
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
# Prefer persisted shard env when present
if [[ -f "$OK/logs/fleet.env" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$OK/logs/fleet.env"; set +a
fi
RUNDIR="${OK}/logs"
mkdir -p "$RUNDIR"
PIDFILE="${RUNDIR}/fleet-daemon.pid"
LOCKFILE="${RUNDIR}/fleet-daemon.lock"
LOG="${RUNDIR}/fleet-daemon.log"
HEARTBEAT="${RUNDIR}/fleet-daemon.heartbeat"
export OPENKORE_HOME="$OK"
export TMUX_CONF="$TF"

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG"; }

heal_once() {
  # Prevent start-openkore-fleet → fleet-daemon recursion
  export FLEET_DAEMON_ACTIVE=1

  bash "$ROOT/scripts/start-openkore-fleet.sh" >>"$LOG" 2>&1 || true

  if ! pgrep -f 'fleet-supervisor\.sh' >/dev/null 2>&1; then
    log "spawn fleet-supervisor"
    tmux -f "$TF" kill-session -t ok-fleet-supervisor 2>/dev/null || true
    tmux -f "$TF" new-session -d -s ok-fleet-supervisor -c "$ROOT" -- bash -l
    sleep 1
    tmux -f "$TF" send-keys -t 'ok-fleet-supervisor:0.0' \
      "bash '$ROOT/scripts/fleet-supervisor.sh'" C-m
  fi

  if ! pgrep -f 'fleet-tunnel-watchdog\.sh' >/dev/null 2>&1; then
    log "spawn fleet-tunnel-watchdog"
    tmux -f "$TF" kill-session -t fleet-tunnel-watchdog 2>/dev/null || true
    tmux -f "$TF" new-session -d -s fleet-tunnel-watchdog -c "$OK" -- bash -l
    sleep 1
    tmux -f "$TF" send-keys -t 'fleet-tunnel-watchdog:0.0' \
      "bash '$OK/scripts/fleet-tunnel-watchdog.sh'" C-m
  fi

  date -u +%Y-%m-%dT%H:%M:%SZ >"$HEARTBEAT"
  local n
  n=$(pgrep -c -f 'perl ./openkore.pl' 2>/dev/null || echo 0)
  log "heal ok bots=$n"
}

daemon_loop() {
  echo $$ >"$PIDFILE"
  log "daemon loop pid=$$"
  heal_once
  while true; do
    sleep 45
    heal_once
  done
}

cmd="${1:-start}"

case "$cmd" in
  heal)
    # One-shot heal for cron; does not take the long-running lock permanently
    (
      flock -n 9 || exit 0
      heal_once
    ) 9>"${RUNDIR}/fleet-daemon.heal.lock"
    ;;
  foreground)
    exec 8>"$LOCKFILE"
    if ! flock -n 8; then
      echo "fleet-daemon already running"
      exit 0
    fi
    daemon_loop
    ;;
  start|daemon)
    exec 8>"$LOCKFILE"
    if ! flock -n 8; then
      echo "fleet-daemon already running pid=$(cat "$PIDFILE" 2>/dev/null || echo '?')"
      exit 0
    fi
    # Release lock in parent; child re-acquires
    flock -u 8 || true
    # Launch detached child that holds the lock for life
    nohup bash "$ROOT/scripts/fleet-daemon.sh" foreground \
      </dev/null >>"$LOG" 2>&1 &
    sleep 1
    echo "fleet-daemon started pid=$(cat "$PIDFILE" 2>/dev/null || echo '?')"
    ;;
  status)
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "running pid=$(cat "$PIDFILE") heartbeat=$(cat "$HEARTBEAT" 2>/dev/null || echo none)"
      exit 0
    fi
    echo "stopped"
    exit 1
    ;;
  stop)
    if [[ -f "$PIDFILE" ]]; then
      kill "$(cat "$PIDFILE")" 2>/dev/null || true
      rm -f "$PIDFILE"
    fi
    echo "stopped"
    ;;
  *)
    echo "usage: $0 {start|foreground|status|stop|heal}" >&2
    exit 2
    ;;
esac
