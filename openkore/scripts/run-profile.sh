#!/usr/bin/env bash
# Run OpenKore profile forever: auto-answer prompts on login AND reconnect.
# Movement/hunt/AFK is owned by eventMacros — do not force lockMap here.
set -uo pipefail
PROFILE="${1:-}"
[[ -n "$PROFILE" ]] || { echo "Usage: $0 <ProfileName>"; exit 1; }
cd "${HOME}/openkore"
export PERL5LIB="${HOME}/perl5/lib/perl5:${PERL5LIB:-}"

attempt=0
while true; do
  attempt=$((attempt + 1))
  echo "[run-profile] $(date -u +%Y-%m-%dT%H:%M:%SZ) starting $PROFILE (attempt $attempt)"
  # Unquoted EXP so $PROFILE expands; escape expect/$ for Tcl.
  expect <<EXP || true
set timeout -1
log_user 1
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
  -re {You are now in the game} {
    puts "\\n\[run-profile\] in-game — macros own movement; holding"
    exp_continue
  }
  -re {Timeout on Map Server|Disconnected from Map Server|connecting to Account Server} {
    puts "\\n\[run-profile\] disconnect — waiting for auto-relog"
    exp_continue
  }
  eof
}
EXP
  code=$?
  echo "[run-profile] $(date -u +%Y-%m-%dT%H:%M:%SZ) $PROFILE exited code=$code — restarting in 8s"
  sleep 8
done
