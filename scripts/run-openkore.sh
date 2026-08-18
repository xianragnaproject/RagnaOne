#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="/home/ubuntu/.local/bin:${PATH}"
export LD_LIBRARY_PATH="/home/ubuntu/.local/lib:/home/ubuntu/.local/sysroot/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$ROOT"
exec perl ./openkore.pl "$@"
