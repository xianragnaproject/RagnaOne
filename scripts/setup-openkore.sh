#!/usr/bin/env bash
# Idempotent OpenKore bootstrap for Cursor Cloud Agent environments.
# Runs from /workspace after checkout. Must terminate successfully.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK_SRC="${ROOT}/openkore"
OK_HOME="${OPENKORE_HOME:-$HOME/openkore}"

echo "[setup-openkore] root=$ROOT"

# Symlink live OpenKore home → repo pack (profiles + control live here)
if [[ -L "$OK_HOME" ]]; then
  :
elif [[ -d "$OK_HOME" && ! -L "$OK_HOME" ]]; then
  echo "[setup-openkore] warning: $OK_HOME exists as a real dir; leaving it"
else
  ln -sfn "$OK_SRC" "$OK_HOME"
  echo "[setup-openkore] linked $OK_HOME → $OK_SRC"
fi

# Ensure executable bits on fleet scripts
chmod +x "$OK_SRC"/scripts/*.sh "$OK_SRC"/scripts/*.py 2>/dev/null || true
chmod +x "$ROOT"/scripts/*.sh 2>/dev/null || true

# Best-effort deps for headless Cursor pods (OpenKore core + expect + cron)
if command -v apt-get >/dev/null 2>&1; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    build-essential scons python-is-python3 libreadline-dev libcurl4-openssl-dev \
    cpanminus expect cron rsync 2>/dev/null || true
  sudo service cron start 2>/dev/null || true
fi

# Bootstrap OpenKore core into pack tree when openkore.pl is missing (gitignored)
if [[ ! -f "$OK_SRC/openkore.pl" ]]; then
  echo "[setup-openkore] openkore.pl missing — cloning/building OpenKore core"
  STAGE="${TMPDIR:-/tmp}/openkore-upstream"
  if [[ ! -f "$STAGE/openkore.pl" ]]; then
    rm -rf "$STAGE"
    git clone --depth 1 https://github.com/OpenKore/openkore.git "$STAGE" || true
  fi
  if [[ -f "$STAGE/openkore.pl" ]]; then
    (cd "$STAGE" && scons -j"$(nproc)" >/tmp/openkore-scons.log 2>&1) || true
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --exclude '.git' --exclude 'profiles/' --exclude 'scripts/' \
        --exclude 'fleet_panel/' --exclude 'fleet_shards/' --exclude 'fresh_grind/' \
        --exclude 'assassin/' --exclude 'assassin_clean/' --exclude 'knight/' \
        --exclude 'knight_clean/' --exclude 'wizard/' --exclude 'wizard_clean/' \
        --exclude 'hunter/' --exclude 'hunter_clean/' --exclude 'priest/' \
        --exclude 'priest_clean/' --exclude 'blacksmith/' --exclude 'blacksmith_clean/' \
        --exclude 'extras/' --exclude 'control/' --exclude 'logs/' \
        --exclude 'CLASSES.md' --exclude 'README.md' --exclude 'install-into-openkore.sh' \
        "$STAGE/" "$OK_SRC/" || true
    fi
    # Essential control files (do not overwrite FreshGrind shared files)
    mkdir -p "$OK_SRC/control"
    for f in sys.txt timeouts.txt avoid.txt chat_resp.txt consolecolors.txt \
             responses.txt priority.txt overallAuth.txt buyer_shop.txt shop.txt \
             arrowcraft.txt poseidon.txt; do
      if [[ ! -f "$OK_SRC/control/$f" && -f "$STAGE/control/$f" ]]; then
        cp -a "$STAGE/control/$f" "$OK_SRC/control/$f"
      fi
    done
    mkdir -p "$OK_SRC/plugins"
    [[ -d "$STAGE/plugins/profiles" ]] && cp -a "$STAGE/plugins/profiles" "$OK_SRC/plugins/" || true
    if [[ -f "$OK_SRC/control/sys.txt" ]]; then
      python3 - "$OK_SRC/control/sys.txt" <<'PY' || true
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); text = p.read_text()
def set_key(text, key, value):
    pat = re.compile(rf'^{re.escape(key)}\s+.*$', re.M)
    return pat.sub(f'{key} {value}', text, count=1) if pat.search(text) else text + f'\n{key} {value}\n'
text = set_key(text, 'loadPlugins', '2')
text = set_key(text, 'loadPlugins_list',
  'macro,profiles,breakTime,raiseStat,raiseSkill,map,reconnect,eventMacro,item_weight_recorder,xconf')
p.write_text(text)
PY
    fi
    if [[ -f "$OK_SRC/tables/servers.txt" ]] && ! grep -q '^\[RagnaOne\]' "$OK_SRC/tables/servers.txt"; then
      python3 - "$OK_SRC/tables/servers.txt" <<'PY' || true
from pathlib import Path
import sys
p = Path(sys.argv[1])
entry = """[RagnaOne]
ip 173.208.138.84
port 6900
master_version 14
version 55
serverType kRO_RagexeRE_2018_06_20e
serverEncoding Western
charBlockSize 155
addTableFolders kRO/RagexeRE_2018_06_21a;translated/kRO_english;kRO
addSize 0
charNameFilter
pinCode 0
storageEncryptKey 0x050B6F79, 0x0202C179, 0x0E20120, 0x04EA75D2, 0x02562C65, 0x04089E4A, 0x0171F82E, 0x0C635F4
sendCryptKeys 0x00000000, 0x00000000, 0x00000000
gameGuard 0
secureLogin 0
secureLogin_type 0
secureLogin_requestCode
secureLogin_account 0
OTP_ip
OTP_port 0
recvpackets recvpackets.txt
private 1
dead 0
title RagnaOne Pre-RE

"""
text = p.read_text(errors='replace')
marker = '[Localhost]'
p.write_text(text.replace(marker, entry + marker, 1) if marker in text else entry + text)
PY
    fi
    [[ -x "$OK_SRC/scripts/patch-attack-min-distance.sh" ]] && bash "$OK_SRC/scripts/patch-attack-min-distance.sh" "$OK_SRC/src/Misc.pm" || true
    [[ -x "$OK_SRC/scripts/patch-allow-ks.sh" ]] && bash "$OK_SRC/scripts/patch-allow-ks.sh" "$OK_SRC/src/Misc.pm" || true
    echo "[setup-openkore] OpenKore core ready: $(test -f "$OK_SRC/openkore.pl" && echo yes || echo NO)"
  fi
fi

# Perl deps commonly needed by OpenKore (best-effort; ignore if already present)
if command -v cpanm >/dev/null 2>&1; then
  cpanm --local-lib="$HOME/perl5" --notest Time::HiRes IO::Socket::INET 2>/dev/null || true
elif command -v cpan >/dev/null 2>&1; then
  true
fi

# Shared FreshGrind control into control/
if [[ -x "$OK_SRC/scripts/install-shared-control.sh" ]]; then
  bash "$OK_SRC/scripts/install-shared-control.sh" || true
fi

# Fleet panel password (local only; never commit)
PANEL_PASS="$OK_SRC/fleet_panel/panel.pass"
mkdir -p "$OK_SRC/fleet_panel"
if [[ ! -f "$PANEL_PASS" ]]; then
  python3 -c 'import secrets; print("fg-" + secrets.token_urlsafe(10))' > "$PANEL_PASS"
  chmod 600 "$PANEL_PASS"
  echo "[setup-openkore] created fleet panel password → $PANEL_PASS"
fi

# cloudflared binary for public panel tunnel (optional)
if [[ ! -x /tmp/cloudflared ]]; then
  curl -fsSL -o /tmp/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    && chmod +x /tmp/cloudflared \
    || echo "[setup-openkore] cloudflared download skipped"
fi

# Prefer persisted shard env when present (multi-VM fleet shards)
if [[ -f "$OK_HOME/logs/fleet.env" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$OK_HOME/logs/fleet.env"; set +a
fi
SHARD_ENV="FLEET_SHARD=${FLEET_SHARD:-0} FLEET_SHARD_FILE=${FLEET_SHARD_FILE:-$OK_HOME/fleet_shards/shard${FLEET_SHARD:-0}.txt}"

# User cron heal (Cursor pods have no systemd; cron keeps fleet alive while VM lives)
if command -v crontab >/dev/null 2>&1; then
  CRON_TMP=$(mktemp)
  {
    echo "SHELL=/bin/bash"
    echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    echo "OPENKORE_HOME=$OK_HOME"
    echo "TMUX_CONF=${TMUX_CONF:-/exec-daemon/tmux.portal.conf}"
    echo "FLEET_SHARD=${FLEET_SHARD:-0}"
    echo "FLEET_SHARD_FILE=${FLEET_SHARD_FILE:-$OK_HOME/fleet_shards/shard${FLEET_SHARD:-0}.txt}"
    echo "* * * * * $SHARD_ENV OPENKORE_HOME=$OK_HOME TMUX_CONF=${TMUX_CONF:-/exec-daemon/tmux.portal.conf} $ROOT/scripts/fleet-daemon.sh heal >>$OK_HOME/logs/fleet-cron.log 2>&1"
    echo "*/5 * * * * $SHARD_ENV OPENKORE_HOME=$OK_HOME TMUX_CONF=${TMUX_CONF:-/exec-daemon/tmux.portal.conf} $ROOT/scripts/fleet-daemon.sh start >>$OK_HOME/logs/fleet-cron.log 2>&1"
  } >"$CRON_TMP"
  crontab "$CRON_TMP" || true
  rm -f "$CRON_TMP"
  echo "[setup-openkore] installed fleet heal crontab (shard=${FLEET_SHARD:-0})"
fi

echo "[setup-openkore] done"
