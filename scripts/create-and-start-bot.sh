#!/usr/bin/env bash
# Create a new RagnaOne account (auto-reg _M/_F), make a Novice char, start bot.
# Usage: create-and-start-bot.sh <BotName> [CharName] [sex:M|F]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK="${OPENKORE_HOME:-$ROOT/openkore}"
MAP="$ROOT/accounts/ACCOUNT_MAP.txt"
LOG_DIR="${OK_LOG_DIR:-/tmp/ok-run}"
TMUX_CFG="/exec-daemon/tmux.portal.conf"
[[ -f "$TMUX_CFG" ]] || TMUX_CFG=""

BOT_NAME="${1:-}"
CHAR_NAME="${2:-}"
SEX="${3:-M}"
SEX="$(echo "$SEX" | tr '[:lower:]' '[:upper:]')"
[[ "$SEX" == "F" ]] || SEX="M"

if [[ -z "$BOT_NAME" ]]; then
  echo "Usage: $0 <BotName> [CharName] [sex:M|F]" >&2
  exit 1
fi

if [[ -z "$CHAR_NAME" ]]; then
  CHAR_NAME="$BOT_NAME"
fi
CHAR_NAME="$(echo "$CHAR_NAME" | tr -cd 'A-Za-z0-9' | cut -c1-16)"
[[ -n "$CHAR_NAME" ]] || CHAR_NAME="Bot$(date +%s | tail -c 5)"

mkdir -p "$ROOT/accounts" "$LOG_DIR" "$OK/control"
chmod 700 "$ROOT/accounts" 2>/dev/null || true

[[ -f "$OK/openkore.pl" ]] || bash "$ROOT/scripts/setup-openkore.sh"
[[ -f "$OK/control/eventMacros.txt" ]] || bash "$ROOT/scripts/install-phase1.sh"

SUFFIX="$(openssl rand -hex 2)"
USER_BASE="ok$(echo "$BOT_NAME" | tr '[:upper:]' '[:lower:]')${SUFFIX}"
USER_BASE="$(echo "$USER_BASE" | tr -cd 'a-z0-9' | cut -c1-20)"
REG_USER="${USER_BASE}_${SEX}"
PASSWORD="Ok$(openssl rand -hex 5)"
SESSION="ok-$(echo "$BOT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"

ENV_FILE="$ROOT/accounts/${BOT_NAME}.env"
printf 'RO_USERNAME=%s\nRO_PASSWORD=%s\nRO_CHAR=0\nRO_BOT_NAME=%s\nRO_CHAR_NAME=%s\n' \
  "$USER_BASE" "$PASSWORD" "$BOT_NAME" "$CHAR_NAME" > "$ENV_FILE"
chmod 600 "$ENV_FILE"

if [[ ! -f "$MAP" ]]; then
  printf '%s\n' '# bot_name	session	username	password	char_name	sex' > "$MAP"
  chmod 600 "$MAP"
fi
grep -v "^${BOT_NAME}	" "$MAP" > "${MAP}.tmp" || true
mv "${MAP}.tmp" "$MAP"
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$BOT_NAME" "$SESSION" "$USER_BASE" "$PASSWORD" "$CHAR_NAME" "$SEX" >> "$MAP"

echo "Creating account $REG_USER / char $CHAR_NAME (session $SESSION)"

BASE_CFG="$OK/control/config.txt"
TMP_CFG="$(mktemp -p "$OK/control" config.create.XXXXXX.txt)"
cp "$BASE_CFG" "$TMP_CFG"
python3 - "$TMP_CFG" "$REG_USER" "$PASSWORD" <<'PY'
import re, sys
path, user, pw = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
def set_key(text, key, value):
    pat = re.compile(rf'^{re.escape(key)}(?:\s+.*)?$', re.M)
    if pat.search(text):
        return pat.sub(f'{key} {value}', text, count=1)
    return text + f'\n{key} {value}\n'
for k, v in [
    ('master', 'RagnaOne'), ('server', '0'), ('char', ''),
    ('username', user), ('password', pw),
    ('attackAuto', '0'), ('route_randomWalk', '0'), ('lockMap', ''),
]:
    text = set_key(text, k, v)
open(path, 'w').write(text)
PY

CREATE_LOG="$LOG_DIR/create-${BOT_NAME}.log"
EXPECT_SCRIPT="$LOG_DIR/create-${BOT_NAME}.exp"
rm -f "$CREATE_LOG"

export OK_CREATE_CFG="$TMP_CFG"
export OK_CREATE_CHAR="$CHAR_NAME"
export OK_CREATE_SEX="$SEX"
export OK_CREATE_DIR="$OK"
export OK_CREATE_LOG="$CREATE_LOG"

cat > "$EXPECT_SCRIPT" <<'EXPECT_EOF'
#!/usr/bin/env expect
set timeout 240
set cfg $env(OK_CREATE_CFG)
set char $env(OK_CREATE_CHAR)
set sex $env(OK_CREATE_SEX)
set okdir $env(OK_CREATE_DIR)
set logfile $env(OK_CREATE_LOG)
log_file $logfile
cd $okdir
spawn perl ./openkore.pl --config=$cfg --interface=Console --ai=manual

expect {
  -re {Compile portals} {
    expect -re {Enter your answer:}
    send "1\r"
    exp_continue
  }
  -re {Password Error|password you entered is incorrect} {
    puts "BAD_PASSWORD"
    catch {send "quit\r"}
    exit 2
  }
  -re {There are no characters on this account} { puts "NO_CHARS" }
  -re {Character List|Slot 0:} { puts "HAS_CHARS" }
  -re {Please choose a character or an action} { puts "CHAR_MENU" }
  timeout { puts "TIMEOUT_LOGIN"; exit 1 }
  eof { puts "EOF_LOGIN"; exit 1 }
}

expect {
  -re {Enter your answer:} {}
  -re {You are now in the game|Map loaded|Your Coordinates:} {
    puts "ALREADY_INGAME"
    send "quit\r"
    expect eof
    exit 0
  }
  timeout { puts "TIMEOUT_MENU"; exit 1 }
}

send "0\r"
expect {
  -re {desired properties for your characters} {
    expect -re {Enter your answer:}
    send "0 \"$char\" 1 1 novice $sex\r"
    puts "SENT_CREATE $char $sex"
    expect {
      -re {Character .* created|created successfully|Character List|Slot 0:} { puts "CREATE_OK" }
      -re {Character name is already used|name is unavailable|Name already exists|Charname already exists} {
        puts "NAME_TAKEN"
        expect -re {Enter your answer:|Please choose a character}
        # unique suffix — old fleet names may still exist on the server
        set alt "B[clock seconds][pid]"
        set alt [string range $alt 0 15]
        send "0\r"
        expect -re {Enter your answer:}
        send "0 \"$alt\" 1 1 novice $sex\r"
        puts "SENT_CREATE_ALT $alt $sex"
        expect {
          -re {Character .* created|created successfully|Character List|Slot 0:} { puts "CREATE_OK_ALT" }
          -re {Charname already exists|Name already exists} { puts "NAME_TAKEN_AGAIN"; exit 5 }
          timeout { puts "TIMEOUT_CREATE_ALT"; exit 5 }
        }
      }
      timeout { puts "TIMEOUT_CREATE"; exit 5 }
    }
    expect {
      -re {Enter your answer:} {
        send "0\r"
        puts "SELECT_AFTER_CREATE"
      }
      timeout { puts "TIMEOUT_SELECT"; exit 5 }
    }
  }
  -re {Received character ID and Map IP|Connecting to Map Server|You are now in the game} {
    puts "SELECTED_EXISTING"
  }
  timeout { puts "TIMEOUT_AFTER_0"; exit 1 }
}

expect {
  -re {You are now in the game} { puts "IN_GAME" }
  -re {Map loaded|Your Coordinates:|Map Change:} { puts "IN_GAME" }
  -re {Connecting to Map Server|connected|Pausing for|Disconnecting|disconnected|Closing connection} { exp_continue }
  timeout { puts "TIMEOUT_MAP"; exit 6 }
}

sleep 3
send "quit\r"
expect {
  -re {Bye} {}
  timeout {}
  eof {}
}
puts "DONE"
exit 0
EXPECT_EOF
chmod +x "$EXPECT_SCRIPT"

set +e
expect "$EXPECT_SCRIPT"
CREATE_RC=$?
set -e
rm -f "$TMP_CFG"

if [[ "$CREATE_RC" -ne 0 ]]; then
  echo "Account/char create failed (rc=$CREATE_RC). See $CREATE_LOG" >&2
  tail -40 "$CREATE_LOG" >&2 || true
  exit "$CREATE_RC"
fi

echo "Account ready - starting bot session $SESSION"
bash "$ROOT/scripts/start-bot.sh" "$BOT_NAME"
echo "OK: $BOT_NAME user=$USER_BASE char=$CHAR_NAME session=$SESSION"
