#!/usr/bin/env bash
# Apply every known fleet fix to ALL bots: table patches, pack→profile sync, live reload.
# Usage: fleet-apply-fixes.sh
# Safe to re-run (idempotent).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OK="${OK:-$HOME/openkore}"
PACKS_ROOT="${PACKS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROFILES_ROOT="${PROFILES_ROOT:-$OK/profiles}"
TMUX_CFG="/exec-daemon/tmux.portal.conf"
TMUX=(tmux)
[[ -f "$TMUX_CFG" ]] && TMUX=(tmux -f "$TMUX_CFG")

echo "== 1) Table / source patches =="
run_patch() {
  local name="$1"; shift
  local script=""
  if [[ -x "$SCRIPT_DIR/$name" ]]; then script="$SCRIPT_DIR/$name"
  elif [[ -x "$OK/scripts/$name" ]]; then script="$OK/scripts/$name"
  else echo "WARN: missing $name"; return 0; fi
  "$script" "$@" || echo "WARN: $name failed (non-fatal)"
}
run_patch patch-disable-paygld-portal.sh "$OK"
run_patch patch-allow-ks.sh "$OK/src/Misc.pm"
run_patch patch-attack-min-distance.sh "$OK/src/Misc.pm"

echo "== 2) Sync pack control → all profiles (preserves username/password) =="
"$SCRIPT_DIR/sync-all-profiles.sh" "$PACKS_ROOT" "$PROFILES_ROOT"

echo "== 3) Live reload / ensure runtime conf on every tmux bot =="
mapfile -t SESSIONS < <("${TMUX[@]}" ls -F '#{session_name}' 2>/dev/null | grep -E '^(ok-|openkore$)' || true)
echo "Sessions: ${#SESSIONS[@]}"

send_all() {
  local cmd="$1"
  local i=0
  for s in "${SESSIONS[@]}"; do
    "${TMUX[@]}" send-keys -t "$s" "$cmd" Enter || true
    i=$((i+1))
    if (( i % 10 == 0 )); then sleep 0.5; fi
  done
}

# Ensure combat/loot basics (never leave a bot paused after testing)
send_all 'conf attackAuto 2'
send_all 'conf route_randomWalk 1'
send_all 'conf itemsTakeAuto 2'
send_all 'conf itemsGatherAuto 2'
send_all 'conf attackAuto_allowKS 1'
send_all 'conf dealAuto 3'
send_all 'ai auto'
sleep 1
send_all 'reload portals'
sleep 1
send_all 'reload eventMacro'
sleep 2

echo "== Done. All ${#SESSIONS[@]} bots received patches + sync + reload. =="
