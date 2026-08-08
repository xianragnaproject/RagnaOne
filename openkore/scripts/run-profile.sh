#!/usr/bin/env bash
# Run OpenKore profile forever: auto-answer portal compile + char select, restart on exit.
# After login, interact forwards tmux/console input to OpenKore.
set -uo pipefail
PROFILE="${1:-}"
[[ -n "$PROFILE" ]] || { echo "Usage: $0 <ProfileName>"; exit 1; }
cd "${HOME}/openkore"
export PERL5LIB="${HOME}/perl5/lib/perl5:${PERL5LIB:-}"

attempt=0
while true; do
  attempt=$((attempt + 1))
  echo "[run-profile] $(date -u +%Y-%m-%dT%H:%M:%SZ) starting $PROFILE (attempt $attempt)"
  expect <<EXP || true
set timeout -1
spawn perl ./openkore.pl --profile=$PROFILE --interface=Console
expect {
  -re {Compile portals} {
    expect -re {Enter your answer:}
    send "1\r"
    exp_continue
  }
  -re {Please choose a character} {
    expect -re {Enter your answer:}
    send "0\r"
    exp_continue
  }
  -re {Please choose a server} {
    expect -re {Enter your answer:}
    send "0\r"
    exp_continue
  }
  -re {You are now in the game|Map loaded|Your Coordinates:} {
    # In-game: forward console keys; still auto-answer rare prompts from spawn output
    interact {
      -o
      -re {Please choose a character} {
        send "0\r"
      }
      -re {Please choose a server} {
        send "0\r"
      }
      -re {Compile portals} {
        send "1\r"
      }
      -re {Enter your answer:} {
        send "0\r"
      }
    }
  }
  eof
}
EXP
  code=$?
  echo "[run-profile] $(date -u +%Y-%m-%dT%H:%M:%SZ) $PROFILE exited code=$code — restarting in 8s"
  sleep 8
done
