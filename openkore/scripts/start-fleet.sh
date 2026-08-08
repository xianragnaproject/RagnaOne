#!/usr/bin/env bash
# Start registered FreshGrind (Grind*) profiles + 24/7 watchdog.
# Skips profiles still in /tmp/fresh-grind-n-pending.txt (awaiting char create).
set -euo pipefail
OK="${HOME}/openkore"
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
PROFILES_DIR="${OK}/profiles"
PENDING_FILE="${PENDING_FILE:-/tmp/fresh-grind-n-pending.txt}"

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
  PROFILES+=("$p")
done

if [[ ${#PROFILES[@]} -eq 0 ]]; then
  echo "No registered Grind* profiles under $PROFILES_DIR (pending=$SKIPPED)"
  exit 1
fi

echo "Starting ${#PROFILES[@]} FreshGrind bots (skipping $SKIPPED pending)..."
for p in "${PROFILES[@]}"; do
  "$OK/scripts/start-bot.sh" "$p" || true
done

SESSION=ok-fleet-watchdog
if ! tmux -f "$TF" has-session -t "=$SESSION" 2>/dev/null; then
  tmux -f "$TF" new-session -d -s "$SESSION" -c "$OK" -- bash -lc 'bash ~/openkore/scripts/fleet-watchdog.sh'
  echo "Started watchdog → tmux attach -t $SESSION"
else
  echo "Watchdog already running: $SESSION"
fi
