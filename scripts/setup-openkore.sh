#!/usr/bin/env bash
# Idempotent OpenKore bootstrap for Cursor Cloud Agent environments.
# Runs from /workspace after checkout. Must terminate successfully.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK_SRC="${ROOT}/openkore"
OK_HOME="${OPENKORE_HOME:-$HOME/openkore}"

echo "[setup-openkore] root=$ROOT"

# Symlink live OpenKore home → repo pack (profiles + control live here)
if [[ -L "$OK_HOME" ]]; then
  :
elif [[ -d "$OK_HOME" && ! -L "$OK_HOME" ]]; then
  echo "[setup-openkore] warning: $OK_HOME exists as a real dir; leaving it"
else
  ln -sfn "$OK_SRC" "$OK_HOME"
  echo "[setup-openkore] linked $OK_HOME → $OK_SRC"
fi

# Ensure executable bits on fleet scripts
chmod +x "$OK_SRC"/scripts/*.sh "$OK_SRC"/scripts/*.py 2>/dev/null || true
chmod +x "$ROOT"/scripts/*.sh 2>/dev/null || true

# Perl deps commonly needed by OpenKore (best-effort; ignore if already present)
if command -v cpanm >/dev/null 2>&1; then
  cpanm --local-lib="$HOME/perl5" --notest Time::HiRes IO::Socket::INET 2>/dev/null || true
elif command -v cpan >/dev/null 2>&1; then
  true
fi

# Shared FreshGrind control into control/
if [[ -x "$OK_SRC/scripts/install-shared-control.sh" ]]; then
  bash "$OK_SRC/scripts/install-shared-control.sh" || true
fi

# Fleet panel password (local only; never commit)
PANEL_PASS="$OK_SRC/fleet_panel/panel.pass"
mkdir -p "$OK_SRC/fleet_panel"
if [[ ! -f "$PANEL_PASS" ]]; then
  python3 -c 'import secrets; print("fg-" + secrets.token_urlsafe(10))' > "$PANEL_PASS"
  chmod 600 "$PANEL_PASS"
  echo "[setup-openkore] created fleet panel password → $PANEL_PASS"
fi

# cloudflared binary for public panel tunnel (optional)
if [[ ! -x /tmp/cloudflared ]]; then
  curl -fsSL -o /tmp/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    && chmod +x /tmp/cloudflared \
    || echo "[setup-openkore] cloudflared download skipped"
fi

# User cron heal (Cursor pods have no systemd; cron keeps fleet alive while VM lives)
if command -v crontab >/dev/null 2>&1; then
  CRON_TMP=$(mktemp)
  {
    echo "SHELL=/bin/bash"
    echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    echo "OPENKORE_HOME=$OK_HOME"
    echo "TMUX_CONF=${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
    echo "* * * * * $ROOT/scripts/fleet-daemon.sh heal >>$OK_HOME/logs/fleet-cron.log 2>&1"
    echo "*/5 * * * * $ROOT/scripts/fleet-daemon.sh start >>$OK_HOME/logs/fleet-cron.log 2>&1"
  } >"$CRON_TMP"
  crontab "$CRON_TMP" || true
  rm -f "$CRON_TMP"
  echo "[setup-openkore] installed fleet heal crontab"
fi

echo "[setup-openkore] done"
