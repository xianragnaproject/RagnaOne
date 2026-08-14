#!/usr/bin/env bash
# Load .env (if present) and connect one OpenKore account to RagnaOne.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
exec bash "$ROOT/scripts/run-openkore.sh"
