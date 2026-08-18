#!/usr/bin/env bash
# Show live status of all FreshGrind bots (tmux ok-Grind*).
# Usage:
#   ~/openkore/scripts/fleet-status.sh
#   ~/openkore/scripts/fleet-status.sh --watch     # refresh every 15s
#   ~/openkore/scripts/fleet-status.sh Grind01 Grind05
set -euo pipefail

OK="${HOME}/openkore"
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
WATCH=0
FILTER=()

for arg in "$@"; do
  case "$arg" in
    --watch|-w) WATCH=1 ;;
    *) FILTER+=("$arg") ;;
  esac
done

classify() {
  local p="$1" sess out map status detail
  sess="ok-${p}"
  if ! tmux -f "$TF" has-session -t "=$sess" 2>/dev/null; then
    printf '%s\t%s\t%s\n' "$p" DOWN 'no tmux session'
    return
  fi
  out=$(tmux -f "$TF" capture-pane -t "$sess" -p -S -40 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' || true)
  map=$(echo "$out" | grep -oE 'Map Change: [a-z0-9_]+' | tail -1 | sed 's/Map Change: //' || true)
  [[ -z "$map" ]] && map=$(echo "$out" | grep -oE 'prt_fild08|pay_fild08|pay_fild03|prontera|prt_in|alberta|alberta_in|payon|payon_in01|new_1-[123]' | tail -1 || true)

  if echo "$out" | grep -qiE 'Password Error|Account name .* doesn.t exist|permanently banned'; then
    status=LOGIN_FAIL
    detail=$(echo "$out" | grep -iE 'Password Error|doesn.t exist|Banned' | tail -1 | tr '\t' ' ' | cut -c1-60)
  elif echo "$out" | grep -qiE 'There are no characters on this account|desired properties for your characters'; then
    status=NO_CHAR
    detail='stuck on char create'
  elif echo "$out" | grep -qiE 'Cannot locate automacro|unexpected problem'; then
    status=CRASH
    detail=$(echo "$out" | grep -iE 'Cannot locate|Error message|unexpected problem' | tail -1 | tr '\t' ' ' | cut -c1-60)
  elif echo "$out" | grep -qE 'Buy failed \(insufficient zeny\)|Set to start talking with NPC Tool Dealer'; then
    status=STUCK_BUY
    detail="shop loop${map:+ @ $map}"
  elif echo "$out" | grep -qE 'You attack|Monster .*died|Targeting'; then
    status=HUNTING
    detail="${map:-?}"
  elif echo "$out" | grep -qE 'prt_fild08|pay_fild08|Prontera Field|Payon Forest'; then
    status=FIELD
    detail="${map:-?}"
  elif echo "$out" | grep -qE 'PHASE2|Alberta|payon'; then
    status=PHASE2
    detail="${map:-?}"
  elif echo "$out" | grep -qE 'Calculating lockMap route|Calculating auto-buy route|Calculating route|walk Prontera south'; then
    status=ROUTING
    detail="${map:-?}"
  elif echo "$out" | grep -qE 'You are now: Sitting'; then
    status=SITTING
    detail="${map:-?}"
  elif echo "$out" | grep -qiE 'Connecting to Account|Connecting to Map|disconnected'; then
    status=CONNECTING
    detail="${map:-}"
  else
    status=ONLINE
    detail="${map:-}"
  fi
  printf '%s\t%s\t%s\n' "$p" "$status" "$detail"
}

list_profiles() {
  if ((${#FILTER[@]})); then
    printf '%s\n' "${FILTER[@]}"
    return
  fi
  find "$OK/profiles" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
    | grep -E '^Grind' | sort
}

once() {
  local rows=() line p st det
  local -A counts=()
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    line=$(classify "$p")
    rows+=("$line")
    st=$(printf '%s\n' "$line" | cut -f2)
    counts[$st]=$(( ${counts[$st]:-0} + 1 ))
  done < <(list_profiles)

  printf '%-12s %-12s %s\n' PROFILE STATUS DETAIL
  printf '%-12s %-12s %s\n' '-------' '------' '------'
  for line in "${rows[@]}"; do
    p=$(printf '%s\n' "$line" | cut -f1)
    st=$(printf '%s\n' "$line" | cut -f2)
    det=$(printf '%s\n' "$line" | cut -f3-)
    printf '%-12s %-12s %s\n' "$p" "$st" "$det"
  done
  echo
  echo -n "summary:"
  for st in HUNTING FIELD PHASE2 ROUTING SITTING ONLINE STUCK_BUY CONNECTING LOGIN_FAIL NO_CHAR CRASH DOWN; do
    [[ -n "${counts[$st]:-}" ]] && echo -n " ${st}=${counts[$st]}"
  done
  # any other keys
  for st in "${!counts[@]}"; do
    case "$st" in
      HUNTING|FIELD|PHASE2|ROUTING|SITTING|ONLINE|STUCK_BUY|CONNECTING|LOGIN_FAIL|NO_CHAR|CRASH|DOWN) ;;
      *) echo -n " ${st}=${counts[$st]}" ;;
    esac
  done
  echo
  echo "total=${#rows[@]}  time=$(date -u +%H:%M:%SZ)"
}

if [[ "$WATCH" -eq 1 ]]; then
  while true; do
    clear 2>/dev/null || true
    once
    sleep 15
  done
else
  once
fi
