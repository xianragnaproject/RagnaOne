#!/usr/bin/env bash
# Keep Cloudflare quick tunnel pointing at fleet panel :8787
set -euo pipefail
TF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
SESSION=fleet-cf-tunnel
PANEL_PORT="${FLEET_PANEL_PORT:-8787}"
CFBIN="${CLOUDFLARED_BIN:-/tmp/cloudflared}"
URLFILE="${OPENKORE_HOME:-$HOME/openkore}/fleet_panel/PUBLIC_URL.txt"
mkdir -p "$(dirname "$URLFILE")"

ensure_cloudflared() {
  if [[ ! -x "$CFBIN" ]]; then
    curl -fsSL -o "$CFBIN" https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x "$CFBIN"
  fi
}

current_url() {
  tmux -f "$TF" capture-pane -t "$SESSION" -p -J -S -300 2>/dev/null \
    | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1 || true
}

restart_tunnel() {
  tmux -f "$TF" kill-session -t "$SESSION" 2>/dev/null || true
  sleep 1
  tmux -f "$TF" new-session -d -s "$SESSION" -c /tmp -- bash -l
  sleep 1
  tmux -f "$TF" send-keys -t "$SESSION:0.0" "$CFBIN tunnel --url http://127.0.0.1:${PANEL_PORT}" C-m
  sleep 10
  local url
  url=$(current_url)
  if [[ -n "$url" ]]; then
    printf 'updated=%s\ncloudflare=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$url" > "$URLFILE"
    echo "[tunnel-watchdog] new URL $url"
  else
    echo "[tunnel-watchdog] restart failed to get URL"
  fi
}

ensure_cloudflared
while true; do
  url=$(current_url)
  ok=0
  if [[ -n "$url" ]]; then
    code=$(curl -sS -m 12 -o /dev/null -w '%{http_code}' -L "$url/" || echo 000)
    [[ "$code" == "200" ]] && ok=1
  fi
  if [[ "$ok" -ne 1 ]]; then
    echo "[tunnel-watchdog] $(date -u +%H:%M:%SZ) tunnel unhealthy — restarting"
    restart_tunnel
  else
    printf 'updated=%s\ncloudflare=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$url" > "$URLFILE"
  fi
  sleep 60
done
