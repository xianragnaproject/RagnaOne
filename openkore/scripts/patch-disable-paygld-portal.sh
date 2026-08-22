#!/usr/bin/env bash
# Disable moc_fild02 <-> pay_gld portals (bots pile on 378,272; pay_fild08 path uses pay_fild04).
set -euo pipefail
OK="${1:-$HOME/openkore}"
P="$OK/tables/portals.txt"
[[ -f "$P" ]] || { echo "missing $P"; exit 1; }
cp -a "$P" "$P.bak-paygld-$(date +%Y%m%d%H%M%S)"
python3 - <<'PY' "$P"
from pathlib import Path
import sys
p = Path(sys.argv[1])
out=[]
for l in p.read_text().splitlines(True):
    if ('moc_fild02' in l and 'pay_gld' in l) or ('pay_gld' in l and 'moc_fild02' in l):
        if not l.lstrip().startswith('#'):
            out.append('#' + l)
            print('disabled', l.strip())
            continue
    out.append(l)
p.write_text(''.join(out))
PY
echo "Patched $P — reload portals in bots: reload portals"
