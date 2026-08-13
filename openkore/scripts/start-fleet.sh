#!/usr/bin/env bash
# Start registered FreshGrind (Grind*) profiles + 24/7 watchdog.
# Skips profiles still in /tmp/fresh-grind-n-pending.txt (awaiting char create).
# Optional shard: FLEET_SHARD_FILE=/path/to/list.txt or FLEET_SHARD=0..3
set -euo pipefail
OK="${OPENKORE_HOME:-$HOME/openkore}"
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
PROFILES_DIR="${OK}/profiles"
PENDING_FILE="${PENDING_FILE:-/tmp/fresh-grind-n-pending.txt}"
SHARD_FILE="${FLEET_SHARD_FILE:-}"
if [[ -z "$SHARD_FILE" && -n "${FLEET_SHARD:-}" ]]; then
  SHARD_FILE="$OK/fleet_shards/shard${FLEET_SHARD}.txt"
fi

pending=""
if [[ -f "$PENDING_FILE" ]]; then
  pending=$(awk -F'\t' '!/^#/ && NF>=1 {print $1}' "$PENDING_FILE")
fi

mapfile -t ALL < <(
  find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | grep -E '^Grind' | sort
)

PROFILES=()
SKIPPED=0
for p in "${ALL[@]}"; do
  if echo "$pending" | grep -qx "$p"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  if [[ -n "$SHARD_FILE" && -f "$SHARD_FILE" ]]; then
    grep -qx "$p" "$SHARD_FILE" || continue
  fi
  PROFILES+=("$p")
done

if [[ ${#PROFILES[@]} -eq 0 ]]; then
  echo "No registered Grind* profiles under $PROFILES_DIR (pending=$SKIPPED shard=${SHARD_FILE:-none})"
  exit 1
fi

echo "Starting ${#PROFILES[@]} FreshGrind bots (skipping $SKIPPED pending, shard=${SHARD_FILE:-all})..."
for p in "${PROFILES[@]}"; do
  "$OK/scripts/start-bot.sh" "$p" || true
done

SESSION=ok-fleet-watchdog
if ! tmux -f "$TF" has-session -t "=$SESSION" 2>/dev/null; then
  tmux -f "$TF" new-session -d -s "$SESSION" -c "$OK" -- bash -l
  sleep 1
  tmux -f "$TF" send-keys -t "${SESSION}:0.0" \
    "export OPENKORE_HOME='$OK' TMUX_CONF='$TF' FLEET_SHARD='${FLEET_SHARD:-}' FLEET_SHARD_FILE='${SHARD_FILE:-}'; bash '$OK/scripts/fleet-watchdog.sh'" C-m
  echo "Started watchdog → tmux attach -t $SESSION (shard=${SHARD_FILE:-all})"
else
  echo "Watchdog already running: $SESSION"
fi
