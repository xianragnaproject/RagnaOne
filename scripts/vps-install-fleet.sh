#!/usr/bin/env bash
# Install FreshGrind OpenKore fleet as a true 24/7 systemd service on a VPS.
# Cursor Cloud Agents go idle/archive — they are NOT always-on. Use this on a
# cheap always-on Linux VPS (Ubuntu 22.04+ recommended).
#
# Usage (as root or with sudo):
#   cd /opt/RagnaOne   # or wherever you cloned the repo
#   sudo bash scripts/vps-install-fleet.sh
#
# Optional env:
#   FLEET_USER=ubuntu
#   OPENKORE_HOME=/home/ubuntu/openkore
#   FLEET_PANEL_PORT=8787
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLEET_USER="${FLEET_USER:-${SUDO_USER:-ubuntu}}"
OK_SRC="$ROOT/openkore"
OK_HOME="${OPENKORE_HOME:-/home/$FLEET_USER/openkore}"
PANEL_PORT="${FLEET_PANEL_PORT:-8787}"
UNIT_DIR=/etc/systemd/system

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

echo "[vps] repo=$ROOT user=$FLEET_USER home=$OK_HOME"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  perl build-essential curl ca-certificates tmux python3 git \
  libio-socket-ssl-perl libwww-perl || true

# OpenKore home → repo pack
install -d -o "$FLEET_USER" -g "$FLEET_USER" "$(dirname "$OK_HOME")"
if [[ -L "$OK_HOME" || ! -e "$OK_HOME" ]]; then
  ln -sfn "$OK_SRC" "$OK_HOME"
  chown -h "$FLEET_USER:$FLEET_USER" "$OK_HOME"
fi

chmod +x "$OK_SRC"/scripts/*.sh "$ROOT"/scripts/*.sh 2>/dev/null || true
bash "$ROOT/scripts/setup-openkore.sh" || true

# cloudflared for optional public panel URL
if [[ ! -x /usr/local/bin/cloudflared ]]; then
  curl -fsSL -o /usr/local/bin/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x /usr/local/bin/cloudflared
fi
ln -sfn /usr/local/bin/cloudflared /tmp/cloudflared 2>/dev/null || true

# tmux.conf fallback for non-Cursor hosts
TMUX_CONF_HOST=/etc/openkore-tmux.conf
cat > "$TMUX_CONF_HOST" <<'EOF'
# minimal tmux conf for OpenKore fleet on VPS
set -g history-limit 5000
EOF

install -d /etc/openkore
cat > /etc/openkore/fleet.env <<EOF
OPENKORE_HOME=$OK_HOME
TMUX_CONF=$TMUX_CONF_HOST
FLEET_PANEL_PORT=$PANEL_PORT
CLOUDFLARED_BIN=/usr/local/bin/cloudflared
EOF

# One-shot boot: start bots + panel + tunnel, then hand off to supervisor
cat > "$UNIT_DIR/openkore-fleet.service" <<EOF
[Unit]
Description=FreshGrind OpenKore fleet (24/7)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$FLEET_USER
Group=$FLEET_USER
WorkingDirectory=$ROOT
EnvironmentFile=/etc/openkore/fleet.env
# Boot everything once, then stay alive supervising
ExecStartPre=/bin/bash $ROOT/scripts/start-openkore-fleet.sh
ExecStart=/bin/bash $ROOT/scripts/fleet-supervisor.sh
Restart=always
RestartSec=15
KillMode=control-group
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openkore-fleet.service
systemctl restart openkore-fleet.service

sleep 3
systemctl --no-pager --full status openkore-fleet.service || true

PASS_FILE="$OK_SRC/fleet_panel/panel.pass"
URL_FILE="$OK_SRC/fleet_panel/PUBLIC_URL.txt"
echo
echo "[vps] installed."
echo "[vps] status:  sudo systemctl status openkore-fleet"
echo "[vps] logs:    sudo journalctl -u openkore-fleet -f"
echo "[vps] bots:    bash $OK_HOME/scripts/fleet-status.sh"
if [[ -f "$PASS_FILE" ]]; then
  echo "[vps] panel password: $(cat "$PASS_FILE")"
fi
if [[ -f "$URL_FILE" ]]; then
  echo "[vps] panel URL file: $URL_FILE"
  cat "$URL_FILE"
fi
echo "[vps] local panel: http://127.0.0.1:${PANEL_PORT}/"
echo
echo "IMPORTANT: Cursor Cloud Agents are NOT 24/7. Keep this VPS service running."
