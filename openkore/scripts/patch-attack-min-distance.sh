#!/usr/bin/env bash
# Allow attackMinPlayerDistance 0 / attackMinPortalDistance 0 (OpenKore treats 0 as unset via ||).
set -euo pipefail
MISC="${1:-$HOME/openkore/src/Misc.pm}"
[[ -f "$MISC" ]] || { echo "Missing $MISC"; exit 1; }
python3 - "$MISC" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text()
old = "\tmy $portalDist = $config{'attackMinPortalDistance'} || 4;\n\tmy $playerDist = $config{'attackMinPlayerDistance'} || 1;"
new = "\tmy $portalDist = (defined $config{'attackMinPortalDistance'} && $config{'attackMinPortalDistance'} ne '') ? $config{'attackMinPortalDistance'} : 4;\n\tmy $playerDist = (defined $config{'attackMinPlayerDistance'} && $config{'attackMinPlayerDistance'} ne '') ? $config{'attackMinPlayerDistance'} : 1;"
if old in text:
    path.write_text(text.replace(old, new, 1))
    print(f'patched {path}')
elif 'defined $config{\'attackMinPlayerDistance\'}' in text:
    print(f'already patched {path}')
else:
    raise SystemExit('pattern not found — OpenKore version mismatch')
PY
