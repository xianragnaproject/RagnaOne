#!/usr/bin/env bash
# Install Phase 1 + Phase 2 macros into a local OpenKore tree.
# Phase2 eventMacros are appended after Phase1.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="${OPENKORE_HOME:-$ROOT/openkore}"
P1="$ROOT/openkore-config/phase1"
P2="$ROOT/openkore-config/phase2"

if [[ ! -f "$OK/openkore.pl" ]]; then
  echo "OpenKore not found at $OK — run scripts/setup-openkore.sh first." >&2
  exit 1
fi

mkdir -p "$OK/control"

# Concatenate Phase1 + Phase2 macros
{
  cat "$P1/eventMacros.txt"
  echo ""
  echo "###############################################################################"
  echo "# ===== PHASE 2 (appended) ====="
  echo "###############################################################################"
  echo ""
  cat "$P2/eventMacros.txt"
} > "$OK/control/eventMacros.txt"

cp -a "$P1/items_control.txt" "$OK/control/items_control.txt"

if [[ -f "$ROOT/openkore-config/timeouts-24x7.txt" ]]; then
  cp -a "$ROOT/openkore-config/timeouts-24x7.txt" "$OK/control/timeouts.txt"
fi

# Merge both config snippets
python3 - "$OK/control/config.txt" "$P1/config-snippet.txt" "$P2/config-snippet.txt" <<'PY'
from pathlib import Path
import re, sys

cfg_path = Path(sys.argv[1])
text = cfg_path.read_text()

def set_key(text, key, value):
    pat = re.compile(rf'^{re.escape(key)}(?:\s+.*)?$', re.M)
    line = f'{key} {value}'.rstrip() if value != '' else key
    if pat.search(text):
        return pat.sub(line, text, count=1)
    return text.rstrip() + '\n' + line + '\n'

PROGRESS_KEYS = {
    'phase1LockDone', 'phase1SaveDone', 'phase1ShopDone',
    'phase1JobDone', 'phase1Done',
    'phase2Active', 'phase2LockDone', 'phase2SaveDone', 'phase2ShopDone',
    'phase2BuildDone',
}

def get_key(text, key):
    m = re.search(rf'^{re.escape(key)}\s+(\S+)', text, re.M)
    return m.group(1) if m else None

def merge_snip(text, snip_path):
    snip = Path(snip_path).read_text()
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
    return text

for snip in sys.argv[2:]:
    text = merge_snip(text, snip)

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
print(f'Installed Phase1+Phase2 macros → {cfg_path.parent}')
PY

echo "Phase 1+2 ready. Restart OpenKore (or: reload eventMacro / reload conf)."
