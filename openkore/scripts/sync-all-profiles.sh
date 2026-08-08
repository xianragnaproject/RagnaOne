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
    AssassinClean*) echo assassin_clean ;;
    KnightClean*) echo knight_clean ;;
    WizardClean*) echo wizard_clean ;;
    HunterClean*) echo hunter_clean ;;
    PriestClean*) echo priest_clean ;;
    BlacksmithClean*) echo blacksmith_clean ;;
    Grind*|FreshGrind) echo fresh_grind ;;
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
    # Clean progression packs (AssassinClean settings) take priority
    clean_rules = [
        ('AssassinClean', 'assassin_clean'), ('KnightClean', 'knight_clean'),
        ('WizardClean', 'wizard_clean'), ('HunterClean', 'hunter_clean'),
        ('PriestClean', 'priest_clean'), ('BlacksmithClean', 'blacksmith_clean'),
    ]
    for prefix, pk in clean_rules:
        if name == prefix or name.startswith(prefix):
            return pk
    # Fresh grind fleet (prt_fild08 novice → 1st job → base 25)
    if name.startswith('Grind') or name == 'FreshGrind':
        return 'fresh_grind'
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
full_files = ('eventMacros.txt', 'items_control.txt', 'mon_control.txt', 'pickupitems.txt', 'routeweights.txt')

def ensure_char(cfg: str) -> str:
    """Always auto-select slot 0 unless a slot is already configured."""
    if re.search(r'^char\s+\S+', cfg, re.M):
        return cfg
    return set_key(cfg, 'char', '0')


def patch_config_overrides(cfg: str, overrides_path: Path) -> str:
    """Merge flat sell keys + fix tool-dealer/buyAuto standpoints for grind packs."""
    if not overrides_path.exists():
        return cfg
    # Old stuck tile -> walkable tile (tool dealer only; weapon shops stay 172,*)
    cfg = cfg.replace('standpoint prt_in 126 74', 'standpoint prt_in 130 72')
    cfg = re.sub(r'^sellAuto_standpoint\s+.*$', 'sellAuto_standpoint prt_in 130 72', cfg, flags=re.M)
    # Apply selected flat overrides from config-overrides.txt
    flat_keys = (
        'itemsMaxWeight', 'itemsMaxWeight_sellOrStore', 'sellAuto',
        'sellAuto_npc', 'sellAuto_standpoint', 'sellAuto_distance',
        'sellAuto_maxDistance', 'sellAuto_npc_steps',
    )
    text = overrides_path.read_text()
    for key in flat_keys:
        m = re.search(rf'^{re.escape(key)}\s+(.*)$', text, re.M)
        if not m:
            continue
        val = m.group(1).strip()
        if re.search(rf'^{re.escape(key)}\s+', cfg, re.M):
            cfg = re.sub(rf'^{re.escape(key)}\s+.*$', f'{key} {val}', cfg, count=1, flags=re.M)
        else:
            cfg += f'\n{key} {val}\n'
    # Re-apply named buyAuto standpoints from pack overrides (prevents drift)
    want = {}
    for m in re.finditer(r'^buyAuto\s+([^\n{]+)\s*\{(.*?)^\}', text, re.M | re.S):
        item = m.group(1).strip()
        sm = re.search(r'standpoint\s+(\S+\s+\d+\s+\d+)', m.group(2))
        if item and sm:
            want[item] = sm.group(1)

    def _fix_buy(m):
        item = m.group(1).strip()
        body = m.group(2)
        if item in want and re.search(r'standpoint\s+\S+\s+\d+\s+\d+', body):
            body = re.sub(
                r'(standpoint\s+)\S+\s+\d+\s+\d+',
                rf'\g<1>{want[item]}',
                body,
                count=1,
            )
        return f'buyAuto {item} {{{body}}}'

    if want:
        cfg = re.sub(r'^buyAuto\s+([^\n{]+)\s*\{(.*?)^\}', _fix_buy, cfg, flags=re.M | re.S)
    return cfg

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
        new_cfg = ensure_char(new_cfg)
        # Never leave template credentials
        if get_key(new_cfg, 'username') in (None, 'CHANGE_ME'):
            raise SystemExit(f'REFUSING to write {prof.name}: username missing/CHANGE_ME')
        (prof / 'config.txt').write_text(new_cfg)
    elif pack == 'fresh_grind' and (prof / 'config.txt').exists():
        # Grind fleet uses config-overrides.txt + live profile config (no full pack config)
        new_cfg = patch_config_overrides(old_cfg, src / 'config-overrides.txt')
        for k, v in saved.items():
            if v is not None and v != '':
                new_cfg = set_key(new_cfg, k, v)
        new_cfg = ensure_char(new_cfg)
        (prof / 'config.txt').write_text(new_cfg)

    print(f'OK    {prof.name} <- {pack} (user={saved.get("username")})')
    synced += 1

print(f'Synced {synced} profiles, skipped {skipped}')
PY

# Apply per-class skillsAddAuto + attack/party/self skill blocks for grind fleet
# Prefer shared-pack thin profiles (login + !include) when builder exists
if [[ -f "$SCRIPT_DIR/make-thin-grind-profiles.py" ]]; then
  python3 "$SCRIPT_DIR/make-thin-grind-profiles.py" \
    "${OPENKORE_HOME:-$HOME/openkore}" \
    "$PACKS_ROOT/fresh_grind/control" || true
elif [[ -f "$SCRIPT_DIR/apply-class-skills.py" ]]; then
  python3 "$SCRIPT_DIR/apply-class-skills.py" "$PROFILES_ROOT" || true
fi

# Party follow roles for grind fleet (no-op on already-thin follower keys; safe)
if [[ -f "$SCRIPT_DIR/apply-party-follow.py" ]]; then
  python3 "$SCRIPT_DIR/apply-party-follow.py" "$PROFILES_ROOT" || true
fi

# Merge fresh_grind timeout overrides into live OpenKore control/timeouts.txt
TIMEOUTS_OVR="$PACKS_ROOT/fresh_grind/control/timeouts-overrides.txt"
TIMEOUTS_DST="${OPENKORE_HOME:-$HOME/openkore}/control/timeouts.txt"
if [[ -f "$TIMEOUTS_OVR" && -f "$TIMEOUTS_DST" ]]; then
  python3 - "$TIMEOUTS_OVR" "$TIMEOUTS_DST" <<'PY'
import re, sys
from pathlib import Path
ovr, dst = map(Path, sys.argv[1:3])
text = dst.read_text()
for line in ovr.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith('#'):
        continue
    parts = line.split(None, 1)
    if len(parts) != 2:
        continue
    key, val = parts
    if re.search(rf'^{re.escape(key)}\s+', text, re.M):
        text = re.sub(rf'^{re.escape(key)}\s+.*$', f'{key} {val}', text, count=1, flags=re.M)
    else:
        text += f'\n{key} {val}\n'
dst.write_text(text)
print(f'Merged timeouts overrides -> {dst}')
PY
fi

# 24/7: ensure char slot + never permanent DC on storage/full reconnects
if [[ -f "$SCRIPT_DIR/apply-uptime.py" ]]; then
  python3 "$SCRIPT_DIR/apply-uptime.py" "$PROFILES_ROOT" || true
fi
