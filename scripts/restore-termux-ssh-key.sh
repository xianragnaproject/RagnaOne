#!/usr/bin/env bash
# Restore Cursor→Termux private key from env secret (for new cloud agent sessions).
# Secret name: TERMUX_CURSOR_SSH_KEY  (full private key PEM / OpenSSH format)
set -euo pipefail
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
KEY="$HOME/.ssh/termux_cursor"
if [[ -n "${TERMUX_CURSOR_SSH_KEY:-}" ]]; then
  printf '%s\n' "$TERMUX_CURSOR_SSH_KEY" > "$KEY"
  chmod 600 "$KEY"
  echo "Restored $KEY from TERMUX_CURSOR_SSH_KEY"
elif [[ -f "$KEY" ]]; then
  echo "Using existing $KEY"
else
  echo "ERROR: No TERMUX_CURSOR_SSH_KEY secret and no $KEY file." >&2
  exit 1
fi
