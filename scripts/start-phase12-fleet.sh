#!/usr/bin/env bash
set -euo pipefail
OK="${OPENKORE_HOME:-$HOME/openkore}"
if [[ ! -x "$OK/run-bots.sh" ]]; then
  echo "missing $OK/run-bots.sh — apply settings pack first" >&2
  exit 1
fi
cd "$OK"
bash ./run-bots.sh start-all || bash ./run-bots.sh start
bash "$OK/scripts/week-keepalive.sh" || true
