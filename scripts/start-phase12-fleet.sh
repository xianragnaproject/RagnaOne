#!/usr/bin/env bash
set -euo pipefail
OK="${OPENKORE_HOME:-$HOME/openkore}"
if [[ ! -x "$OK/run-bots.sh" ]]; then
  echo "missing $OK/run-bots.sh — apply ragnaone-openkore-settings.tar.gz first" >&2
  exit 1
fi
cd "$OK"
bash ./run-bots.sh start-all || bash ./run-bots.sh start
