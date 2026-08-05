#!/usr/bin/env bash
# Install a RagnaOne OpenKore 2-1 class pack into an OpenKore checkout.
# Usage:
#   ./install-into-openkore.sh /path/to/openkore <class>
# Classes (2-1 only):
#   assassin knight wizard hunter priest blacksmith
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"
CLASS="${2:-assassin}"
CLASSES=(assassin knight wizard hunter priest blacksmith)

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 /path/to/openkore <class>"
  echo "Classes (2-1 only): ${CLASSES[*]}"
  exit 1
fi

PROFILE="$ROOT/$CLASS"
if [[ ! -d "$PROFILE/control" ]]; then
  echo "Unknown class '$CLASS'. Available (2-1 only): ${CLASSES[*]}"
  exit 1
fi

mkdir -p "$TARGET/control" "$TARGET/tables"
cp -f "$PROFILE/control/"* "$TARGET/control/"
cp -f "$ROOT/tables/servers.txt" "$TARGET/tables/servers.txt"

echo "Installed '$CLASS' pack into $TARGET"
echo "Edit $TARGET/control/config.txt → username / password"
echo "Run: cd $TARGET && perl ./openkore.pl"
