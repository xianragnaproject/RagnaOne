#!/usr/bin/env bash
# Run OpenKore against RagnaOne (173.208.138.84, PACKETVER 20180620)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="$ROOT/openkore"
BASE_CONFIG="$OK/control/config.txt"

if [[ ! -f "$OK/openkore.pl" ]]; then
  echo "OpenKore not found. Run scripts/setup-openkore.sh first." >&2
  exit 1
fi

if [[ -z "${RO_USERNAME:-}" || -z "${RO_PASSWORD:-}" ]]; then
  echo "Set RO_USERNAME and RO_PASSWORD before connecting." >&2
  exit 1
fi

TMP_CONFIG="$(mktemp -p "$OK/control" config.runtime.XXXXXX.txt)"
cleanup() { rm -f "$TMP_CONFIG"; }
trap cleanup EXIT

cp "$BASE_CONFIG" "$TMP_CONFIG"
python3 - "$TMP_CONFIG" <<'PY'
import os, re, sys
path = sys.argv[1]
text = open(path).read()
def set_key(text, key, value):
    pat = re.compile(rf'^{re.escape(key)}(?:\s+.*)?$', re.M)
    if pat.search(text):
        return pat.sub(f'{key} {value}', text, count=1)
    return text + f'\n{key} {value}\n'
text = set_key(text, 'master', 'RagnaOne')
text = set_key(text, 'server', os.environ.get('RO_SERVER', '0'))
text = set_key(text, 'char', os.environ.get('RO_CHAR', '0'))
text = set_key(text, 'username', os.environ['RO_USERNAME'])
text = set_key(text, 'password', os.environ['RO_PASSWORD'])
open(path, 'w').write(text)
PY

export PERL5LIB="${HOME}/perl5/lib/perl5:${PERL5LIB:-}"
cd "$OK"
# Console interface; AI off until login is confirmed
exec perl ./openkore.pl --config="$TMP_CONFIG" --interface=Console --ai=manual
