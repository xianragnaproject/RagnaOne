#!/usr/bin/env bash
# Clone and build OpenKore for RagnaOne (PACKETVER 20180620)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="$ROOT/openkore"

if [[ ! -d "$OK/.git" && ! -f "$OK/openkore.pl" ]]; then
  git clone --depth 1 https://github.com/OpenKore/openkore.git "$OK"
fi

# Ensure build deps (idempotent)
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    build-essential scons python-is-python3 libreadline-dev libcurl4-openssl-dev cpanminus expect cron
  sudo service cron start 2>/dev/null || true
fi

# Apply RagnaOne server definition if missing
SNIPPET="$ROOT/openkore-config/servers-ragnaone.txt"
if ! grep -q '^\[RagnaOne\]' "$OK/tables/servers.txt" 2>/dev/null; then
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
else
  # Refresh existing [RagnaOne] block from snippet
  python3 - "$OK/tables/servers.txt" "$SNIPPET" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
entry = Path(sys.argv[2]).read_text().rstrip() + "\n\n"
text = p.read_text()
text2, n = re.subn(r'(?ms)^\[RagnaOne\].*?(?=^\[|\Z)', entry, text, count=1)
if n:
    p.write_text(text2)
    print("Updated [RagnaOne] in servers.txt")
else:
    print("RagnaOne block present; left unchanged")
PY
fi

# Point default master at RagnaOne (credentials stay empty / env-injected)
python3 - "$OK/control/config.txt" <<'PY'
import re, sys
from pathlib import Path
p = Path(sys.argv[1])
text = p.read_text()
def set_key(text, key, value):
    pat = re.compile(rf'^{re.escape(key)}(?:\s+.*)?$', re.M)
    if pat.search(text):
        return pat.sub(f'{key} {value}', text, count=1)
    return text + f'\n{key} {value}\n'
text = set_key(text, 'master', 'RagnaOne')
text = set_key(text, 'server', '0')
text = set_key(text, 'char', '0')
text = set_key(text, 'attackAuto', '0')
text = set_key(text, 'route_randomWalk', '0')
text = set_key(text, 'pauseCharLogin', '3')
text = set_key(text, 'pauseCharServer', '2')
text = set_key(text, 'pauseMapServer', '2')
p.write_text(text)
print("Updated control/config.txt defaults")
PY

# Fix mixed CP949 bytes in upstream English quests table (blocks startup)
python3 - "$OK/tables/translated/kRO_english/quests.txt" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
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

# Install Phase 1 novice macros (lockmap / save / sell / buy / AFK / job / sit)
bash "$ROOT/scripts/install-phase1.sh"

echo "OpenKore ready. Run: RO_USERNAME=... RO_PASSWORD=... ./scripts/run-openkore.sh"
