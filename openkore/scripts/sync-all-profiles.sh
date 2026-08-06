#!/usr/bin/env bash
# Sync class pack control files → every live OpenKore profile.
# Preserves per-account keys (username/password/etc.) from ACCOUNT_MAP or existing config.
# Usage: sync-all-profiles.sh [packs_root] [profiles_root]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKS_ROOT="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROFILES_ROOT="${2:-$HOME/openkore/profiles}"
ACCOUNT_MAP="${ACCOUNT_MAP:-$PROFILES_ROOT/ACCOUNT_MAP.txt}"

pack_for() {
  local name="$1"
  case "$name" in
    Black|Blacksmith*) echo blacksmith ;;
    Night|Nemo|Assassin*) echo assassin ;;
    Hunter*) echo hunter ;;
    Knight*) echo knight ;;
    Priest*) echo priest ;;
    Wizard*) echo wizard ;;
    *) echo "" ;;
  esac
}

# Keys that must never be overwritten by pack templates
PRESERVE_KEYS=(username password loginPinCode char)

FILES_FULL=(eventMacros.txt items_control.txt mon_control.txt)

synced=0
skipped=0
echo "Packs:    $PACKS_ROOT"
echo "Profiles: $PROFILES_ROOT"

python3 - "$PACKS_ROOT" "$PROFILES_ROOT" "$ACCOUNT_MAP" <<'PY'
import re, sys, shutil
from pathlib import Path

packs_root, profiles_root, account_map = map(Path, sys.argv[1:4])

def pack_for(name):
    rules = [
        ('Blacksmith', 'blacksmith'), ('Assassin', 'assassin'), ('Hunter', 'hunter'),
        ('Knight', 'knight'), ('Priest', 'priest'), ('Wizard', 'wizard'),
        ('Black', 'blacksmith'), ('Night', 'assassin'), ('Nemo', 'assassin'),
    ]
    for prefix, pk in sorted(rules, key=lambda x: -len(x[0])):
        if name == prefix or name.startswith(prefix):
            return pk
    return None

def parse_map(text):
    accounts = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split('\t')
        if len(parts) < 5:
            continue
        profile, char = parts[1], parts[2]
        if len(parts) == 6 and parts[3] in ('M', 'F'):
            user, passwd = parts[4], parts[5]
        elif len(parts) == 6 and parts[5] in ('M', 'F'):
            user, passwd = parts[3], parts[4]
        else:
            user, passwd = parts[3], parts[4]
        accounts[profile] = (user, passwd, char)
    return accounts

def get_key(text, key):
    m = re.search(rf'^{re.escape(key)}\s+(.*)$', text, re.M)
    return m.group(1).strip() if m else None

def set_key(text, key, value):
    pat = re.compile(rf'^{re.escape(key)}\s+.*$', re.M)
    if pat.search(text):
        return pat.sub(f'{key} {value}', text, count=1)
    return re.sub(r'^(master\s+.*)$', rf'\1\n{key} {value}', text, count=1, flags=re.M)

accounts = parse_map(account_map.read_text()) if account_map.exists() else {}
preserve_keys = ('username', 'password', 'loginPinCode', 'char')
full_files = ('eventMacros.txt', 'items_control.txt', 'mon_control.txt')

synced = skipped = 0
for prof in sorted(profiles_root.iterdir()):
    if not prof.is_dir() or prof.name.startswith('_'):
        continue
    pack = pack_for(prof.name)
    if not pack:
        print(f'SKIP  {prof.name} (no pack mapping)')
        skipped += 1
        continue
    src = packs_root / pack / 'control'
    if not src.is_dir():
        print(f'SKIP  {prof.name} (missing pack {pack})')
        skipped += 1
        continue

    # Preserve account fields from existing config or ACCOUNT_MAP
    old_cfg = (prof / 'config.txt').read_text() if (prof / 'config.txt').exists() else ''
    saved = {k: get_key(old_cfg, k) for k in preserve_keys}
    if prof.name in accounts:
        user, passwd, _char = accounts[prof.name]
        saved['username'] = user
        saved['password'] = passwd
        # keep char slot index from existing if present, else 0
        if not saved.get('char'):
            saved['char'] = '0'

    for f in full_files:
        if (src / f).exists():
            shutil.copy2(src / f, prof / f)

    if (src / 'config.txt').exists():
        new_cfg = (src / 'config.txt').read_text()
        for k, v in saved.items():
            if v is not None and v != '':
                new_cfg = set_key(new_cfg, k, v)
        # Never leave template credentials
        if get_key(new_cfg, 'username') in (None, 'CHANGE_ME'):
            raise SystemExit(f'REFUSING to write {prof.name}: username missing/CHANGE_ME')
        (prof / 'config.txt').write_text(new_cfg)

    print(f'OK    {prof.name} <- {pack} (user={saved.get("username")})')
    synced += 1

print(f'Synced {synced} profiles, skipped {skipped}')
PY
