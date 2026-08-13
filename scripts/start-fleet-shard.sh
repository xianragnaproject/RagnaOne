#!/usr/bin/env bash
# Start only one fleet shard (0-3). Split ~46 bots across multiple Cursor VMs.
# Usage: FLEET_SHARD=1 ./scripts/start-fleet-shard.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="${OPENKORE_HOME:-$HOME/openkore}"
if [[ -d "$ROOT/openkore" && ! -e "$OK" ]]; then
  ln -sfn "$ROOT/openkore" "$OK"
fi
if [[ -L "$HOME/openkore" || -d "$HOME/openkore" ]]; then
  OK="$(readlink -f "$HOME/openkore" 2>/dev/null || echo "$HOME/openkore")"
fi
SHARD="${FLEET_SHARD:-0}"
SHARD_FILE="${FLEET_SHARD_FILE:-$OK/fleet_shards/shard${SHARD}.txt}"
export OPENKORE_HOME="$OK"
export FLEET_SHARD="$SHARD"
export FLEET_SHARD_FILE="$SHARD_FILE"
export TMUX_CONF="${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"

if [[ ! -f "$SHARD_FILE" ]]; then
  echo "missing shard file: $SHARD_FILE" >&2
  exit 1
fi

chmod +x "$OK"/scripts/*.sh "$ROOT"/scripts/*.sh 2>/dev/null || true
bash "$ROOT/scripts/setup-openkore.sh" || true

echo "[shard] id=$SHARD file=$SHARD_FILE count=$(grep -cve '^[[:space:]]*$' "$SHARD_FILE")"

if [[ -f "$OK/profiles/ACCOUNT_MAP.txt" ]]; then
  bash "$OK/scripts/materialize-profiles-from-map.sh" "$OK/profiles/ACCOUNT_MAP.txt" || true
fi

# Boot via standard start path (respects FLEET_SHARD)
bash "$ROOT/scripts/start-openkore-fleet.sh"
echo "[shard] ready shard=$SHARD bots=$(pgrep -c -f 'perl ./openkore.pl' || echo 0)"
