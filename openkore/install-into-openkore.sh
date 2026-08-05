#!/usr/bin/env bash
# Install a RagnaOne OpenKore class pack into an OpenKore checkout.
# Usage:
#   ./install-into-openkore.sh /path/to/openkore <class>
# Classes:
#   assassin knight blacksmith wizard hunter priest crusader sage monk
#   alchemist rogue bard dancer
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"
CLASS="${2:-assassin}"
CLASSES=(assassin knight blacksmith wizard hunter priest crusader sage monk alchemist rogue bard dancer)

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 /path/to/openkore <class>"
  echo "Classes: ${CLASSES[*]}"
  exit 1
fi

PROFILE="$ROOT/$CLASS"
if [[ ! -d "$PROFILE/control" ]]; then
  echo "Unknown class '$CLASS'. Available: ${CLASSES[*]}"
  exit 1
fi

mkdir -p "$TARGET/control" "$TARGET/tables"
cp -f "$PROFILE/control/"* "$TARGET/control/"
cp -f "$PROFILE/tables/servers.txt" "$TARGET/tables/servers.txt"
# Shared servers block also at pack root tables/
if [[ -f "$ROOT/tables/servers.txt" ]]; then
  cp -f "$ROOT/tables/servers.txt" "$TARGET/tables/servers.txt"
fi

echo "Installed '$CLASS' pack into $TARGET"
echo "Edit $TARGET/control/config.txt → username / password"
echo "Run: cd $TARGET && perl ./openkore.pl"
