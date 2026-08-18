#!/usr/bin/env bash
# Copy working Phase1/2 OpenKore tree from source VPS into ~/openkore (or DEST).
set -euo pipefail

SRC_HOST="${SRC_HOST:-93.127.139.197}"
SRC_USER="${SRC_USER:-administrator}"
SRC_PATH="${SRC_PATH:-/home/administrator/openkore}"
DEST="${DEST:-$HOME/openkore}"

KEY_FILE="${SOURCE_SSH_KEY_FILE:-$HOME/.ssh/source_openkore}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

auth_args=()
if [[ -f "$KEY_FILE" ]]; then
  chmod 600 "$KEY_FILE"
  auth_args=(-i "$KEY_FILE")
elif [[ -n "${SOURCE_SSH_PRIVATE_KEY:-}" ]]; then
  mkdir -p "$(dirname "$KEY_FILE")"
  printf '%s\n' "$SOURCE_SSH_PRIVATE_KEY" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  auth_args=(-i "$KEY_FILE")
elif [[ -n "${SOURCE_SSH_PASSWORD:-}" ]]; then
  if ! command -v sshpass >/dev/null 2>&1; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sshpass
  fi
  export SSHPASS="$SOURCE_SSH_PASSWORD"
  RSYNC_RSH="sshpass -e ssh ${SSH_OPTS[*]}"
else
  echo "Missing SOURCE_SSH_PRIVATE_KEY or SOURCE_SSH_PASSWORD" >&2
  exit 2
fi

RSYNC_RSH="${RSYNC_RSH:-ssh ${auth_args[*]} ${SSH_OPTS[*]}}"
mkdir -p "$DEST"

PATHS=(
  control/macros.txt
  control/items_control.txt
  control/mon_control.txt
  control/config.txt
  tables/servers.txt
  tables/portals.txt
  tables/npc_shops.txt
  profiles/
  creds/accounts.json
  run-bots.sh
  watch-bots-8h.sh
  run-openkore.sh
  phase1-watchdog.sh
  plugins/autoCharCreate/
  SETUP_NOTES.md
)

echo "[rsync] $SRC_USER@$SRC_HOST:$SRC_PATH → $DEST"
for rel in "${PATHS[@]}"; do
  echo "  + $rel"
  mkdir -p "$DEST/$(dirname "$rel")"
  rsync -a --info=stats0,progress2 -e "$RSYNC_RSH" \
    "$SRC_USER@$SRC_HOST:$SRC_PATH/$rel" \
    "$DEST/$rel"
done

# Also pull XSTools / core pieces referenced by SETUP_NOTES if present
for rel in openkore.pl start.pl src/ fields/ tables/kRO tables/translated SConstruct Makefile control/sys.txt control/timeouts.txt control/consolecolors.txt plugins/macro plugins/eventMacro plugins/profiles; do
  rsync -a -e "$RSYNC_RSH" \
    "$SRC_USER@$SRC_HOST:$SRC_PATH/$rel" \
    "$DEST/$rel" 2>/dev/null || true
done

chmod +x "$DEST"/run-bots.sh "$DEST"/watch-bots-8h.sh "$DEST"/run-openkore.sh "$DEST"/phase1-watchdog.sh 2>/dev/null || true
echo "[rsync] done"
ls -la "$DEST" | head -40
