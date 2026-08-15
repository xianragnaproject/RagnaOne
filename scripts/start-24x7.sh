#!/usr/bin/env bash
# Boot entry for Cursor Cloud / machine start — keep OpenKore online 24/7.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${OK_LOG_DIR:-/tmp/ok-run}"
mkdir -p "$LOG_DIR"

# Install deps / OpenKore / Phase1 if needed (idempotent)
bash "$ROOT/scripts/setup-openkore.sh" >>"$LOG_DIR/boot.log" 2>&1 || true

# Install cron if missing (Cursor pods often omit it)
if ! command -v crontab >/dev/null 2>&1; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cron >/dev/null 2>&1 || true
fi
sudo service cron start 2>/dev/null || sudo systemctl start cron 2>/dev/null || true

# Cron every minute as belt-and-suspenders
CRON_LINE="* * * * * cd $ROOT && bash ./scripts/watchdog-openkore.sh ensure >>$LOG_DIR/cron.log 2>&1"
if command -v crontab >/dev/null 2>&1; then
  (crontab -l 2>/dev/null | grep -v 'watchdog-openkore.sh' || true; echo "$CRON_LINE") | crontab -
fi

# Foreground-ish supervisor in tmux (survives start script exit)
SESSION="${OK_WATCHDOG_TMUX:-ok-watchdog}"
TMUX_CFG="/exec-daemon/tmux.portal.conf"
tmux_cmd() {
  if [[ -f "$TMUX_CFG" ]]; then tmux -f "$TMUX_CFG" "$@"; else tmux "$@"; fi
}
if ! tmux_cmd has-session -t "=$SESSION" 2>/dev/null; then
  tmux_cmd new-session -d -s "$SESSION" -c "$ROOT" -- \
    bash -lc "bash '$ROOT/scripts/watchdog-openkore.sh' loop 2>&1 | tee -a '$LOG_DIR/watchdog.log'"
fi

# Also ensure bot is up right now
bash "$ROOT/scripts/watchdog-openkore.sh" ensure >>"$LOG_DIR/boot.log" 2>&1 || true
echo "OpenKore 24/7 watchdog armed (cron + tmux $SESSION)"
