#!/usr/bin/env bash
# Create a new bot profile from the Nemo pack template.
# Usage: ./scripts/add-account.sh <ProfileName> <username> <password> [charSlot]
set -euo pipefail
NAME="${1:-}"; USER="${2:-}"; PASS="${3:-}"; CHAR="${4:-0}"
OK="${HOME}/openkore"
if [[ -z "$NAME" || -z "$USER" || -z "$PASS" ]]; then
  echo "Usage: $0 <ProfileName> <username> <password> [charSlot]"
  exit 1
fi
SRC="$OK/profiles/Nemo"
DST="$OK/profiles/$NAME"
if [[ -d "$DST" ]]; then
  echo "Profile $NAME already exists at $DST"
  exit 1
fi
mkdir -p "$DST"
cp "$SRC/config.txt" "$SRC/eventMacros.txt" "$SRC/items_control.txt" "$SRC/mon_control.txt" "$DST/"
python3 - "$DST/config.txt" "$USER" "$PASS" "$CHAR" <<'PY'
import re, sys
p, user, pw, char = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
t = open(p).read()
def set_key(t,k,v):
    pat=re.compile(rf'^{re.escape(k)}(?:\s+.*)?$',re.M)
    return pat.sub(f'{k} {v}',t,count=1) if pat.search(t) else t+f'\n{k} {v}\n'
t=set_key(t,'username',user)
t=set_key(t,'password',pw)
t=set_key(t,'master','RagnaOne')
t=set_key(t,'char',char)
open(p,'w').write(t)
print(f'Created profile with user={user} char={char}')
PY
echo "Created $DST"
echo "Start with: $OK/scripts/start-bot.sh $NAME"
echo "Note: create a character on that account first (or set char slot after creating one)."
