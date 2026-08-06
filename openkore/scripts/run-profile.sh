#!/usr/bin/env bash
# Run OpenKore profile; auto-skip portal compile prompts.
set -euo pipefail
PROFILE="$1"
cd ~/openkore
export PERL5LIB="${HOME}/perl5/lib/perl5:${PERL5LIB:-}"
exec expect <<EXP
set timeout -1
spawn perl ./openkore.pl --profile=$PROFILE --interface=Console
expect {
  -re {Compile portals} {
    expect -re {Enter your answer:}
    send "1\r"
    exp_continue
  }
  eof
}
EXP
