#!/usr/bin/env bash
# Install FreshGrind shared control into the single OpenKore control/ folder.
# Profiles then only need config.txt (login + job); everything else is shared.
set -euo pipefail
OK="${OPENKORE_HOME:-$HOME/openkore}"
SRC="${1:-}"
if [[ -z "$SRC" ]]; then
  if [[ -d /workspace/openkore/fresh_grind/control ]]; then
    SRC=/workspace/openkore/fresh_grind/control
  else
    SRC="$OK/fresh_grind/control"
  fi
fi
CTRL="$OK/control"
PACK="$OK/fresh_grind/control"
mkdir -p "$CTRL" "$PACK"

# Keep pack copy in sync (source of truth for repo)
if [[ -d "$SRC" && "$(readlink -f "$SRC")" != "$(readlink -f "$PACK")" ]]; then
  cp -a "$SRC"/. "$PACK"/
fi

# Shared files live in control/ so every --profile=X finds them after config.txt
for f in eventMacros.txt items_control.txt mon_control.txt pickupitems.txt routeweights.txt; do
  if [[ -f "$PACK/$f" ]]; then
    cp -a "$PACK/$f" "$CTRL/$f"
    echo "control/$f"
  fi
done

# Merge timeout overrides into control/timeouts.txt if present
if [[ -f "$PACK/timeouts-overrides.txt" && -f "$CTRL/timeouts.txt" ]]; then
  # Append override keys (last wins when OpenKore parses duplicates inconsistently,
  # so rewrite matching keys in place)
  python3 - "$CTRL/timeouts.txt" "$PACK/timeouts-overrides.txt" <<'PY'
import re, sys
base, ov = sys.argv[1], sys.argv[2]
text = open(base).read()
for line in open(ov):
    line=line.strip()
    if not line or line.startswith('#'):
        continue
    parts=line.split(None, 1)
    if len(parts)<2:
        continue
    k,v=parts[0], parts[1]
    pat=re.compile(rf'^{re.escape(k)}\s+.*$', re.M)
    if pat.search(text):
        text=pat.sub(f'{k} {v}', text, count=1)
    else:
        text=text.rstrip()+f'\n{k} {v}\n'
open(base,'w').write(text)
print('merged timeouts-overrides')
PY
fi

echo "Shared FreshGrind control installed → $CTRL"
echo "Per-account files: $OK/profiles/<Name>/config.txt only"
