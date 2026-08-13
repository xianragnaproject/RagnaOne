#!/usr/bin/env bash
# Per-boot: bring FreshGrind fleet + watchdog + panel + tunnel online.
# Idempotent — safe to run on every environment start. Must terminate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="${OPENKORE_HOME:-$HOME/openkore}"
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
export OPENKORE_HOME="$OK"
export TMUX_CONF="$TF"

echo "[start-fleet] OpenKore home=$OK"

# Prefer repo symlink
if [[ -d "$ROOT/openkore" && ! -e "$OK" ]]; then
  ln -sfn "$ROOT/openkore" "$OK"
fi
if [[ -L "$HOME/openkore" || -d "$HOME/openkore" ]]; then
  OK="$(readlink -f "$HOME/openkore" 2>/dev/null || echo "$HOME/openkore")"
  export OPENKORE_HOME="$OK"
fi

if [[ ! -f "$OK/openkore.pl" ]]; then
  echo "[start-fleet] ERROR: openkore.pl missing at $OK" >&2
  exit 1
fi

chmod +x "$OK"/scripts/*.sh 2>/dev/null || true

# 1) Start all Grind* bots + fleet watchdog
bash "$OK/scripts/start-fleet.sh" || true

# 2) Fleet control panel (password-protected web UI)
bash "$OK/scripts/start-fleet-panel.sh" || true

# 3) Cloudflare tunnel + tunnel watchdog (public link when possible)
if [[ -x /tmp/cloudflared || -x "$OK/bin/cloudflared" ]]; then
  if ! tmux -f "$TF" has-session -t '=fleet-tunnel-watchdog' 2>/dev/null; then
    tmux -f "$TF" new-session -d -s fleet-tunnel-watchdog -c "$OK" -- bash -l
    sleep 1
    tmux -f "$TF" send-keys -t 'fleet-tunnel-watchdog:0.0' \
      "bash '$OK/scripts/fleet-tunnel-watchdog.sh'" C-m
    echo "[start-fleet] tunnel watchdog started"
  fi
fi

# 4) Supervisor that re-checks every minute (survives partial crashes)
if ! tmux -f "$TF" has-session -t '=ok-fleet-supervisor' 2>/dev/null; then
  tmux -f "$TF" new-session -d -s ok-fleet-supervisor -c "$OK" -- bash -l
  sleep 1
  tmux -f "$TF" send-keys -t 'ok-fleet-supervisor:0.0' \
    "bash '$ROOT/scripts/fleet-supervisor.sh'" C-m
  echo "[start-fleet] supervisor started"
fi

# 5) Detached always-on daemon (no systemd on Cursor pods).
# Skip when already inside the daemon heal path to avoid recursion.
if [[ -z "${FLEET_DAEMON_ACTIVE:-}" && -x "$ROOT/scripts/fleet-daemon.sh" ]]; then
  bash "$ROOT/scripts/fleet-daemon.sh" start || true
fi

n=$(tmux -f "$TF" ls 2>/dev/null | grep -c '^ok-Grind' || true)
echo "[start-fleet] grind sessions=$n"
echo "[start-fleet] ready"
