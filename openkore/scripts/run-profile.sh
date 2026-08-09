#!/usr/bin/env bash
# Run OpenKore profile forever: auto-answer prompts, then nudge south gate after login.
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
    puts "\\n\[run-profile\] in-game — nudge south gate then hold"
    # Give map/AI a moment, then walk Prontera south gate and arm hunt lock
    sleep 5
    send "stand\r"
    sleep 1
    # "none" unsets via conf command (not a map name)
    send "conf lockMap none\r"
    sleep 1
    send "conf attackAuto 0\r"
    sleep 1
    send "conf route_randomWalk 0\r"
    sleep 1
    send "conf clientSight\r"
    sleep 1
    send "move 156 22\r"
    # Wait for gate / field, then arm hunt lock
    set timeout 180
    expect {
      -re {Map Change: prt_fild08|Coordinates: 156, 2[0-9]|Stuck at prontera \\(156,2} {
        puts "\\n\[run-profile\] near south / field — arm lockMap"
        send "conf lockMap prt_fild08\r"
        send "conf attackAuto 2\r"
        send "conf route_randomWalk 1\r"
      }
      timeout {
        puts "\\n\[run-profile\] gate walk timeout — arm lockMap anyway"
        send "conf lockMap prt_fild08\r"
        send "conf attackAuto 2\r"
        send "conf route_randomWalk 1\r"
      }
      eof
    }
    set timeout -1
    expect eof
  }
  eof
}
EXP
  code=$?
  echo "[run-profile] $(date -u +%Y-%m-%dT%H:%M:%SZ) $PROFILE exited code=$code — restarting in 8s"
  sleep 8
done
