#!/data/data/com.termux/files/usr/bin/bash
# Run ON Termux — opens SSH + reverse tunnel so Cursor can reach this phone.
# Usage:
#   bash ~/RagnaOne/scripts/termux-cursor-bridge.sh
# Or:
#   curl -fsSL -o ~/termux-cursor-bridge.sh \
#     https://raw.githubusercontent.com/xianragnaproject/RagnaOne/cursor/termux-openkore-worker-db18/scripts/termux-cursor-bridge.sh
#   bash ~/termux-cursor-bridge.sh
set -euo pipefail

VPS_HOST="${VPS_HOST:-173.208.138.84}"
VPS_USER="${VPS_USER:-root}"
VPS_PORT="${VPS_PORT:-22}"
REMOTE_PORT="${REMOTE_PORT:-2223}"   # port on VPS that forwards to Termux sshd
LOCAL_SSHD_PORT="${LOCAL_SSHD_PORT:-8022}"
REPO_REF="${RAGNAONE_REF:-cursor/termux-openkore-worker-db18}"
PUB_URL="https://raw.githubusercontent.com/xianragnaproject/RagnaOne/${REPO_REF}/scripts/cursor-termux.pub"
TERMUX_HOME="${HOME:-/data/data/com.termux/files/home}"
AUTH="$TERMUX_HOME/.ssh/authorized_keys"
INFO="$TERMUX_HOME/cursor-bridge-info.txt"

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -n "${PREFIX:-}" || -d /data/data/com.termux/files/usr ]] || die "Run this inside Termux."

say "Installing OpenSSH + tools"
pkg update -y
pkg install -y openssh netcat-openbsd curl

mkdir -p "$TERMUX_HOME/.ssh"
chmod 700 "$TERMUX_HOME/.ssh"

# Ensure host keys exist
if [[ ! -f "$PREFIX/etc/ssh/ssh_host_ed25519_key" ]]; then
  ssh-keygen -A
fi

say "Installing Cursor agent public key"
curl -fsSL "$PUB_URL" -o /tmp/cursor-termux.pub \
  || die "Could not download Cursor public key from GitHub."
touch "$AUTH"
chmod 600 "$AUTH"
# idempotent append
if ! grep -qF "$(awk '{print $2}' /tmp/cursor-termux.pub)" "$AUTH" 2>/dev/null; then
  cat /tmp/cursor-termux.pub >> "$AUTH"
fi

# sshd config for Termux
mkdir -p "$PREFIX/etc/ssh"
cat > "$PREFIX/etc/ssh/sshd_config" <<EOF
Port $LOCAL_SSHD_PORT
ListenAddress 127.0.0.1
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile $AUTH
PermitRootLogin no
ChallengeResponseAuthentication no
EOF

say "Starting Termux sshd on 127.0.0.1:$LOCAL_SSHD_PORT"
pkill -x sshd 2>/dev/null || true
sshd

TERMUX_USER="$(whoami)"
{
  echo "termux_user=$TERMUX_USER"
  echo "local_sshd_port=$LOCAL_SSHD_PORT"
  echo "vps_host=$VPS_HOST"
  echo "vps_user=$VPS_USER"
  echo "remote_port=$REMOTE_PORT"
  echo "updated=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$INFO"

say "Bridge info written to $INFO"
cat "$INFO"

say "Starting reverse tunnel to $VPS_USER@$VPS_HOST:$VPS_PORT (remote $REMOTE_PORT → local $LOCAL_SSHD_PORT)"
echo
echo "You will be asked for the VPS password (or key passphrase) once."
echo "Leave this session running. Keep Termux awake / wake-locked."
echo

# Kill old tunnel if any
pkill -f "ssh .*${REMOTE_PORT}:127.0.0.1:${LOCAL_SSHD_PORT}" 2>/dev/null || true

# Loop so tunnel auto-reconnects
while true; do
  ssh -N -T \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    -o StrictHostKeyChecking=accept-new \
    -p "$VPS_PORT" \
    -R "127.0.0.1:${REMOTE_PORT}:127.0.0.1:${LOCAL_SSHD_PORT}" \
    "${VPS_USER}@${VPS_HOST}" \
    && true
  echo "Tunnel dropped — retrying in 5s..."
  sleep 5
done
