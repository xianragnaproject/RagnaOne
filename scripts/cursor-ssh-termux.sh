#!/usr/bin/env bash
# Run FROM Cursor cloud agent — SSH into Termux via VPS reverse tunnel.
# Requires:
#   - Termux running scripts/termux-cursor-bridge.sh
#   - VPS SSH access (key or password) as jump host
#   - Private key at ~/.ssh/termux_cursor (matches scripts/cursor-termux.pub)
set -euo pipefail

VPS_HOST="${VPS_HOST:-173.208.138.84}"
VPS_USER="${VPS_USER:-root}"
VPS_PORT="${VPS_PORT:-22}"
REMOTE_PORT="${REMOTE_PORT:-2223}"
TERMUX_USER="${TERMUX_USER:-}"
KEY="${TERMUX_SSH_KEY:-$HOME/.ssh/termux_cursor}"
VPS_KEY="${VPS_SSH_KEY:-${HOME}/.ssh/id_ed25519}"
CMD="${*:-}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$KEY" ]] || die "Missing Termux key: $KEY (generate or restore secret TERMUX_CURSOR_SSH_KEY)"

# Discover Termux username if not set (optional; user can export TERMUX_USER)
if [[ -z "$TERMUX_USER" ]]; then
  # Common Termux pattern; override with TERMUX_USER=u0_aXX
  die "Set TERMUX_USER to your Termux username (printed by termux-cursor-bridge.sh as termux_user=...)"
fi

PROXY=(ssh -W "127.0.0.1:${REMOTE_PORT}" -p "$VPS_PORT" -o StrictHostKeyChecking=accept-new)
if [[ -f "$VPS_KEY" ]]; then
  PROXY+=(-i "$VPS_KEY")
fi
PROXY+=("${VPS_USER}@${VPS_HOST}")

SSH_BASE=(
  ssh
  -i "$KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
  -o ProxyCommand="${PROXY[*]}"
  "${TERMUX_USER}@127.0.0.1"
)

if [[ -n "$CMD" ]]; then
  exec "${SSH_BASE[@]}" -- "$CMD"
else
  exec "${SSH_BASE[@]}"
fi
