#!/usr/bin/env bash
# Watch ok-bot1 / ok-bot2 for 8 hours; auto-fix common OpenKore failures.
set -u
ROOT=/home/ubuntu/openkore
LOG="$ROOT/logs/watch-phase2.log"
END_AT=$(( $(date +%s) + 8*3600 ))
INTERVAL=180
TMUX=(tmux -f /exec-daemon/tmux.portal.conf)
mkdir -p "$ROOT/logs"
exec >>"$LOG" 2>&1

say() { echo "[$(date '+%F %T')] $*"; }

send() {
  local sess=$1; shift
  "${TMUX[@]}" send-keys -t "${sess}:0.0" "$*" C-m 2>/dev/null || return 1
}

session_up() {
  "${TMUX[@]}" has-session -t "=$1" 2>/dev/null
}

# Never send bare 'ai' — it toggles. Always 'ai on'.
fix_bot() {
  local sess=$1
  local pane
  pane=$("${TMUX[@]}" capture-pane -t "${sess}:0.0" -p -S -80 2>/dev/null) || return 1

  # Disconnect / char select stuck
  if echo "$pane" | grep -qiE 'Disconnected|Connection timed out|Timeout on Recv|CharSelect|Please wait for disconnection'; then
    say "$sess: disconnect/charselect — sending Enter + ai on"
    send "$sess" ""
    sleep 1
    send "$sess" "ai on"
  fi

  # AI manually off (status lines / conf)
  if echo "$pane" | grep -q 'AI turned off'; then
    say "$sess: AI was off — ai on"
    send "$sess" "ai on"
  fi

  # attackAuto 0 while Phase farming (not town heal) — soft nudge
  if echo "$pane" | grep -q "Config 'attackAuto' is 0"; then
    if echo "$pane" | grep -qiE 'Location:.*Field|Location:.*Forest|pay_fild|prt_fild|moc_fild|gef_fild'; then
      say "$sess: attackAuto 0 on field — force 2"
      send "$sess" "conf attackAuto 2"
      send "$sess" "ai on"
    fi
  fi

  # Macro parser / load errors
  if echo "$pane" | grep -qiE 'error in macro|Macro.*error|automacro.*error'; then
    say "$sess: macro error seen — reload macros"
    send "$sess" "reload macros"
  fi

  # Dead stuck without respawn attempt
  if echo "$pane" | grep -q 'You are now: Dead'; then
    if ! echo "$pane" | grep -q 'Sending respawn'; then
      say "$sess: dead without respawn — conf dcOnDeath 0"
      send "$sess" "conf dcOnDeath 0"
    fi
  fi
}

check_progress() {
  local sess=$1
  send "$sess" "s"
  sleep 1
  send "$sess" "where"
  sleep 1
  local pane
  pane=$("${TMUX[@]}" capture-pane -t "${sess}:0.0" -p -S -50 2>/dev/null) || return
  local line
  line=$(echo "$pane" | grep -E 'OkBot|Base:|Job |Location:|Zeny:|HP:' | tr '\n' ' ' | head -c 280)
  say "$sess status: $line"
}

BOTS_FILE="$ROOT/profiles/FLEET_40.txt"
mapfile -t BOTS < <(if [[ -f "$BOTS_FILE" ]]; then awk 'NF' "$BOTS_FILE"; else echo bot1; echo bot2; fi)
say "===== WATCH START bots=${#BOTS[@]} (8h until $(date -d @$END_AT '+%F %T')) ====="

while (( $(date +%s) < END_AT )); do
  for b in "${BOTS[@]}"; do
    s="ok-$b"
    if session_up "$s"; then
      fix_bot "$s"
      check_progress "$s"
    else
      say "$s: SESSION MISSING — restarting profile $b"
      # reuse start_one path via run-bots helper
      bash -c "source <(sed -n "1,/^case/p" "$ROOT/run-bots.sh" | head -n -1); start_one "$b"" >>"$LOG" 2>&1 || {
        # fallback: direct start
        TMUX=(tmux -f /exec-daemon/tmux.portal.conf)
        "${TMUX[@]}" kill-session -t "ok-$b" 2>/dev/null || true
        "${TMUX[@]}" new-session -d -s "ok-$b" -c "$ROOT" -- bash -l
        sleep 1
        "${TMUX[@]}" send-keys -t "ok-$b:0.0" "cd $ROOT; perl ./openkore.pl --profile=$b --interface=Console::Simple 2>&1 | tee -a logs/${b}.log" C-m
      }
    fi
  done

  # Log tail scan for hard errors
  for f in "$ROOT/logs/console_okbot14ea705_0.txt" "$ROOT/logs/console_okbot25k9t_0.txt"; do
    [[ -f "$f" ]] || continue
    err=$(tail -80 "$f" | grep -iE 'Could not find NPC|Base Exception|Out of memory|Segmentation|syntax error|disconnected from map' | tail -3)
    if [[ -n "${err:-}" ]]; then
      say "LOG $(basename "$f"): $err"
    fi
  done

  sleep "$INTERVAL"
done

say "===== WATCH END ====="
