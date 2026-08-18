#!/usr/bin/env bash
# Retry FreshGrind char registration until pending queue is empty, then start bots.
# Safe while login server is closed — fast-fails and sleeps.
set -uo pipefail
OK="${HOME}/openkore"
PENDING="${PENDING_FILE:-/tmp/fresh-grind-n-pending.txt}"
LOG="${OK}/logs/register-pending.log"
INTERVAL="${REGISTER_INTERVAL:-45}"
mkdir -p "${OK}/logs"

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG"; }

cp -f /workspace/openkore/scripts/create-char.exp "$OK/scripts/create-char.exp" 2>/dev/null || true
cp -f /workspace/openkore/scripts/batch-create-fresh-grind-n.py "$OK/scripts/" 2>/dev/null || true
chmod +x "$OK/scripts/create-char.exp" "$OK/scripts/batch-create-fresh-grind-n.py" 2>/dev/null || true

log "register-pending start interval=${INTERVAL}s pending=$PENDING"

while true; do
  if [[ ! -f "$PENDING" ]] || [[ ! -s "$PENDING" ]]; then
    log "no pending file — idle"
    sleep "$INTERVAL"
    continue
  fi
  # Count non-comment rows
  left=$(grep -cvE '^\s*(#|$)' "$PENDING" || true)
  if [[ "${left:-0}" -eq 0 ]]; then
    log "pending empty — all registered"
    sleep "$INTERVAL"
    continue
  fi
  log "retry ${left} pending accounts"
  python3 "$OK/scripts/batch-create-fresh-grind-n.py" --retry-only >>"$LOG" 2>&1 || true
  # Start any Grind* that is no longer pending
  mapfile -t ALL < <(find "$OK/profiles" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -E '^Grind' | sort)
  pending_names=""
  if [[ -f "$PENDING" ]]; then
    pending_names=$(awk -F'\t' '!/^#/ && NF>=1 {print $1}' "$PENDING")
  fi
  for p in "${ALL[@]}"; do
    if echo "$pending_names" | grep -qx "$p"; then
      continue
    fi
    "$OK/scripts/start-bot.sh" "$p" >/dev/null 2>&1 || true
  done
  left=$(grep -cvE '^\s*(#|$)' "$PENDING" 2>/dev/null || echo 0)
  log "after retry pending=${left}"
  sleep "$INTERVAL"
done
