#!/usr/bin/env bash
# Install Phase 1 macros + config into a local OpenKore tree.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="${OPENKORE_HOME:-$ROOT/openkore}"
SRC="$ROOT/openkore-config/phase1"

if [[ ! -f "$OK/openkore.pl" ]]; then
  echo "OpenKore not found at $OK — run scripts/setup-openkore.sh first." >&2
  exit 1
fi

mkdir -p "$OK/control"
cp -a "$SRC/eventMacros.txt" "$OK/control/eventMacros.txt"
cp -a "$SRC/items_control.txt" "$OK/control/items_control.txt"

# Merge config-snippet keys into control/config.txt (do not wipe credentials)
python3 - "$OK/control/config.txt" "$SRC/config-snippet.txt" <<'PY'
from pathlib import Path
import re, sys

cfg_path = Path(sys.argv[1])
snip_path = Path(sys.argv[2])
text = cfg_path.read_text()
snip = snip_path.read_text()

def set_key(text, key, value):
    pat = re.compile(rf'^{re.escape(key)}(?:\s+.*)?$', re.M)
    line = f'{key} {value}'.rstrip() if value != '' else key
    if pat.search(text):
        return pat.sub(line, text, count=1)
    return text.rstrip() + '\n' + line + '\n'

# Progress flags: never reset a completed (1) flag back to 0 on reinstall
PROGRESS_KEYS = {
    'phase1LockDone', 'phase1SaveDone', 'phase1ShopDone',
    'phase1JobDone', 'phase1Done',
}

def get_key(text, key):
    m = re.search(rf'^{re.escape(key)}\s+(\S+)', text, re.M)
    return m.group(1) if m else None

# Parse snippet: skip comments/blank; support "key value" and bare "key"
for raw in snip.splitlines():
    line = raw.strip()
    if not line or line.startswith('#'):
        continue
    if ' ' in line:
        key, value = line.split(None, 1)
    else:
        key, value = line, ''
    if key in PROGRESS_KEYS and value in ('0', '') and get_key(text, key) == '1':
        continue
    text = set_key(text, key, value)

# Ensure eventMacro plugin is loaded
sys_path = cfg_path.parent / 'sys.txt'
if sys_path.exists():
    s = sys_path.read_text()
    if 'eventMacro' not in s:
        s = re.sub(
            r'^(loadPlugins_list\s+)(.*)$',
            lambda m: m.group(1) + (m.group(2) + ',eventMacro' if m.group(2).strip() else 'eventMacro'),
            s,
            count=1,
            flags=re.M,
        )
        sys_path.write_text(s)

cfg_path.write_text(text)
print(f'Installed Phase1 macros → {cfg_path.parent}')
PY

echo "Phase 1 ready. Restart OpenKore (or: reload eventMacro / reload conf)."
