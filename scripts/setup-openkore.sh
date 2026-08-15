#!/usr/bin/env bash
# Fresh, clean OpenKore install for RagnaOne.
# Wipes any previous checkout (macros, grind configs, leftover control files)
# and reclones stock OpenKore. Only adds the RagnaOne server entry and
# points master at it. Credentials stay empty.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="$ROOT/openkore"

# Ensure build deps (idempotent)
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  build-essential scons python-is-python3 libreadline-dev libcurl4-openssl-dev cpanminus
# OpenKore's Makefile invokes `python`; python-is-python3 provides it.

echo "Wiping $OK for a clean OpenKore checkout"
rm -rf "$OK"
git clone --depth 1 https://github.com/OpenKore/openkore.git "$OK"

# Drop stock macro files if upstream ships any
rm -f "$OK/control/eventMacros.txt" "$OK/control/macros.txt"

# Apply RagnaOne server definition
SNIPPET="$ROOT/openkore-config/servers-ragnaone.txt"
python3 - "$OK/tables/servers.txt" "$SNIPPET" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
entry = Path(sys.argv[2]).read_text().rstrip() + "\n\n"
text = p.read_text()
marker = "[Localhost]"
if marker in text:
    p.write_text(text.replace(marker, entry + marker, 1))
else:
    p.write_text(text + "\n" + entry)
print("Added [RagnaOne] to servers.txt")
PY

# Point master at RagnaOne only. Leave every other control option stock.
python3 - "$OK/control/config.txt" <<'PY'
import re
from pathlib import Path
p = Path(__import__('sys').argv[1])
text = p.read_text()
pat = re.compile(r'^master(?:\s+.*)?$', re.M)
if pat.search(text):
    text = pat.sub('master RagnaOne', text, count=1)
else:
    text += '\nmaster RagnaOne\n'
p.write_text(text)
print("Set master RagnaOne (stock config otherwise)")
PY

# Disable macro / grind plugins. Keep reconnect and map utilities.
python3 - "$OK/control/sys.txt" <<'PY'
import re
from pathlib import Path
p = Path(__import__('sys').argv[1])
text = p.read_text()
text = re.sub(
    r'^loadPlugins_list\s+.*$',
    'loadPlugins_list map,reconnect,xconf,OTP,LatamChecksum,AdventureAgency,LATAMTranslate',
    text,
    count=1,
    flags=re.M,
)
p.write_text(text)
print("Disabled macro, eventMacro, raiseStat, raiseSkill, breakTime, profiles")
PY

# Fix mixed CP949 bytes in upstream English quests table (blocks startup)
python3 - "$OK/tables/translated/kRO_english/quests.txt" <<'PY'
from pathlib import Path
p = Path(__import__('sys').argv[1])
if not p.exists():
    raise SystemExit(0)
data = p.read_bytes()
fixed = []
n = 0
for line in data.splitlines(True):
    try:
        line.decode('utf-8')
        fixed.append(line)
    except UnicodeDecodeError:
        n += 1
        for enc in ('cp949', 'euc-kr', 'latin-1'):
            try:
                fixed.append(line.decode(enc).encode('utf-8'))
                break
            except Exception:
                continue
        else:
            fixed.append(line.decode('utf-8', errors='replace').encode('utf-8'))
if n:
    p.write_bytes(b''.join(fixed))
    print(f"Normalized UTF-8 in quests.txt ({n} lines)")
PY

cd "$OK"
scons -j"$(nproc)"
echo "Clean OpenKore ready. No macros. Run: RO_USERNAME=... RO_PASSWORD=... ./scripts/run-openkore.sh"
