#!/usr/bin/env bash
# Restart OpenKore if it exits so the client stays up on a long-lived host.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$ROOT/openkore/logs/watchdog.log"
mkdir -p "$(dirname "$LOG")"

if [[ -z "${RO_USERNAME:-}" || -z "${RO_PASSWORD:-}" ]]; then
  echo "Set RO_USERNAME and RO_PASSWORD before starting the 24/7 watchdog." >&2
  exit 1
fi

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) watchdog start" | tee -a "$LOG"
while true; do
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) starting OpenKore" | tee -a "$LOG"
  bash "$ROOT/scripts/run-openkore.sh" >>"$LOG" 2>&1 || true
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) OpenKore exited; restart in 15s" | tee -a "$LOG"
  sleep 15
done
