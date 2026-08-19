#!/usr/bin/env bash
# RagnaOne Termux worker — installs Ubuntu (proot) + OpenKore with one command.
# Run this ON the cloud phone inside Termux:
#   curl -fsSL https://raw.githubusercontent.com/xianragnaproject/RagnaOne/main/scripts/termux-worker.sh | bash
# Or from a feature branch URL if main is not updated yet.
set -euo pipefail

REPO_URL="${RAGNAONE_REPO:-https://github.com/xianragnaproject/RagnaOne.git}"
# Default to this worker branch until merged; override with RAGNAONE_REF=main later.
REPO_REF="${RAGNAONE_REF:-cursor/termux-openkore-worker-db18}"
TERMUX_HOME="${HOME:-/data/data/com.termux/files/home}"
HOST_DIR="${RAGNAONE_HOST_DIR:-$TERMUX_HOME/RagnaOne}"
UBUNTU_DIR="/root/RagnaOne"
LOG_DIR="${OK_LOG_DIR:-$TERMUX_HOME/ok-run}"
mkdir -p "$LOG_DIR"

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

is_termux() {
  [[ -n "${TERMUX_VERSION:-}" ]] || [[ "${PREFIX:-}" == *com.termux* ]] || [[ -d /data/data/com.termux/files/usr ]]
}

require_termux() {
  is_termux || die "This worker must be run inside Termux on your cloud phone."
}

install_termux_pkgs() {
  say "Updating Termux packages"
  pkg update -y
  pkg upgrade -y
  pkg install -y proot-distro git curl wget tmux
}

ensure_ubuntu() {
  local rootfs="${PREFIX:-/data/data/com.termux/files/usr}/var/lib/proot-distro/installed-rootfs/ubuntu"
  if [[ -d "$rootfs" ]]; then
    say "Ubuntu already installed"
  else
    say "Installing Ubuntu (proot-distro) — this takes a few minutes"
    proot-distro install ubuntu
  fi
}

sync_repo_on_host() {
  say "Syncing RagnaOne repo on Termux host → $HOST_DIR"
  if [[ -d "$HOST_DIR/.git" ]]; then
    git -C "$HOST_DIR" fetch --depth 1 origin "$REPO_REF" || true
    git -C "$HOST_DIR" checkout -B "$REPO_REF" "origin/$REPO_REF" 2>/dev/null \
      || git -C "$HOST_DIR" pull --ff-only || true
  else
    rm -rf "$HOST_DIR"
    git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$HOST_DIR" \
      || git clone --depth 1 "$REPO_URL" "$HOST_DIR"
  fi
  chmod +x "$HOST_DIR"/scripts/*.sh
}

run_inside_ubuntu() {
  say "Entering Ubuntu worker to install OpenKore"
  # Bind Termux checkout into Ubuntu so both sides share the same files.
  proot-distro login ubuntu --bind "$HOST_DIR:$UBUNTU_DIR" -- \
    bash -lc "set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq \
        build-essential scons python-is-python3 libreadline-dev libcurl4-openssl-dev \
        cpanminus expect git tmux wget curl ca-certificates
      cd '$UBUNTU_DIR'
      bash ./scripts/setup-openkore.sh
      echo
      echo 'OpenKore build finished inside Ubuntu.'
    "
}

write_wrappers() {
  say "Writing easy launch helpers in Termux home"

  cat > "$TERMUX_HOME/ok-login.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
# Enter the Ubuntu OpenKore worker shell
exec proot-distro login ubuntu --bind "$HOST_DIR:$UBUNTU_DIR" -- bash -lc "cd '$UBUNTU_DIR' && exec bash -l"
EOF

  chmod +x "$HOST_DIR/scripts/"*.sh 2>/dev/null || true

  cat > "$TERMUX_HOME/ok-start.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
USER_NAME="\${1:-\${RO_USERNAME:-}}"
PASS="\${2:-\${RO_PASSWORD:-}}"
if [[ -z "\$USER_NAME" || -z "\$PASS" ]]; then
  echo "Usage: ./ok-start.sh <username> <password>"
  exit 1
fi
exec proot-distro login ubuntu --bind "$HOST_DIR:$UBUNTU_DIR" -- \
  bash "$UBUNTU_DIR/scripts/termux-start-bot.sh" "\$USER_NAME" "\$PASS"
EOF

  cat > "$TERMUX_HOME/ok-attach.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login ubuntu --bind "$HOST_DIR:$UBUNTU_DIR" -- \
  bash -lc 'tmux attach -t ok-phone || tmux ls'
EOF

  cat > "$TERMUX_HOME/ok-status.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login ubuntu --bind "$HOST_DIR:$UBUNTU_DIR" -- \
  bash -lc 'tmux ls 2>/dev/null || echo "No tmux sessions"; tail -n 30 /tmp/ok-run/phone.log 2>/dev/null || true'
EOF

  chmod +x "$TERMUX_HOME"/ok-*.sh
}

print_next_steps() {
  cat <<EOF

========================================
RagnaOne Termux worker is ready.
========================================

Helpers in your Termux home:
  ~/ok-login.sh     enter Ubuntu shell (repo at $UBUNTU_DIR)
  ~/ok-start.sh     start OpenKore bot in tmux
  ~/ok-attach.sh    watch the bot console
  ~/ok-status.sh    quick status / last log lines

Start a bot (auto-reg often uses name_M / name_F once):
  ~/ok-start.sh MyBot_M mypassword

Tips for cloud phones:
  - Disable battery optimization for Termux
  - Keep a wake lock if your cloud-phone app has one
  - Re-run ~/ok-start.sh after the phone reboots

Repo on phone: $HOST_DIR
EOF
}

main() {
  require_termux
  install_termux_pkgs
  ensure_ubuntu
  sync_repo_on_host
  run_inside_ubuntu
  write_wrappers
  print_next_steps
}

main "$@"
