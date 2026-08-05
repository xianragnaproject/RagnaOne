#!/usr/bin/env bash
# Install a RagnaOne OpenKore class pack into an OpenKore checkout.
# Usage:
#   ./install-into-openkore.sh /path/to/openkore [assassin|knight]
# Examples:
#   ./install-into-openkore.sh ~/openkore-assassin assassin
#   ./install-into-openkore.sh ~/openkore-knight knight
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"
CLASS="${2:-assassin}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 /path/to/openkore [assassin|knight]"
  exit 1
fi

PROFILE="$ROOT/$CLASS"
if [[ ! -d "$PROFILE/control" ]]; then
  # Backward-compatible: top-level control/ = assassin
  if [[ "$CLASS" == "assassin" && -d "$ROOT/control" ]]; then
    PROFILE="$ROOT"
  else
    echo "ERROR: unknown class '$CLASS' (expected assassin or knight)"
    echo "Looked for: $ROOT/$CLASS/control"
    exit 1
  fi
fi

if [[ ! -d "$TARGET/control" ]]; then
  echo "ERROR: $TARGET does not look like an OpenKore tree (missing control/)"
  echo "Clone OpenKore first, e.g. git clone https://github.com/OpenKore/openkore.git $TARGET"
  exit 1
fi

mkdir -p "$TARGET/control" "$TARGET/tables"
cp -v "$PROFILE/control/config.txt" "$TARGET/control/"
cp -v "$PROFILE/control/items_control.txt" "$TARGET/control/"
cp -v "$PROFILE/control/mon_control.txt" "$TARGET/control/"
cp -v "$PROFILE/control/eventMacros.txt" "$TARGET/control/"

SERVERS_SRC="$PROFILE/tables/servers.txt"
[[ -f "$SERVERS_SRC" ]] || SERVERS_SRC="$ROOT/tables/servers.txt"

if [[ -f "$TARGET/tables/servers.txt" ]]; then
  if grep -q '^\[RagnaOne\]' "$TARGET/tables/servers.txt"; then
    echo "RagnaOne already present in tables/servers.txt — leaving existing file."
  else
    echo "" >> "$TARGET/tables/servers.txt"
    cat "$SERVERS_SRC" >> "$TARGET/tables/servers.txt"
    echo "Appended [RagnaOne] to tables/servers.txt"
  fi
else
  cp -v "$SERVERS_SRC" "$TARGET/tables/servers.txt"
fi

echo
echo "Installed class pack: $CLASS → $TARGET"
echo "Edit $TARGET/control/config.txt and set username/password."
echo "Run OpenKore and choose master server: RagnaOne"
echo "Load event macros if needed:  load eventMacro"
