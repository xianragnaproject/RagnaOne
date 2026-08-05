#!/usr/bin/env bash
# Install this RagnaOne OpenKore control pack into an OpenKore checkout.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 /path/to/openkore"
  echo "Example: $0 ~/openkore"
  exit 1
fi

if [[ ! -d "$TARGET/control" ]]; then
  echo "ERROR: $TARGET does not look like an OpenKore tree (missing control/)"
  exit 1
fi

mkdir -p "$TARGET/control" "$TARGET/tables"
cp -v "$ROOT/control/config.txt" "$TARGET/control/"
cp -v "$ROOT/control/items_control.txt" "$TARGET/control/"
cp -v "$ROOT/control/mon_control.txt" "$TARGET/control/"
cp -v "$ROOT/control/eventMacros.txt" "$TARGET/control/"

# Merge or replace servers entry
if [[ -f "$TARGET/tables/servers.txt" ]]; then
  if grep -q '^\[RagnaOne\]' "$TARGET/tables/servers.txt"; then
    echo "RagnaOne already present in tables/servers.txt — leaving existing file."
  else
    echo "" >> "$TARGET/tables/servers.txt"
    cat "$ROOT/tables/servers.txt" >> "$TARGET/tables/servers.txt"
    echo "Appended [RagnaOne] to tables/servers.txt"
  fi
else
  cp -v "$ROOT/tables/servers.txt" "$TARGET/tables/servers.txt"
fi

echo
echo "Done."
echo "Edit $TARGET/control/config.txt and set username/password."
echo "Run OpenKore and choose master server: RagnaOne"
echo "Load event macros if needed:  load eventMacro"
