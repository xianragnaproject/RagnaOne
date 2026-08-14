#!/usr/bin/env bash
# Load credentials and connect one OpenKore account to RagnaOne.
# Prefers already-exported RO_* ; else accounts/$RO_BOT_NAME.env ; else .env
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -z "${RO_USERNAME:-}" || -z "${RO_PASSWORD:-}" ]]; then
  if [[ -n "${RO_BOT_NAME:-}" && -f "$ROOT/accounts/${RO_BOT_NAME}.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ROOT/accounts/${RO_BOT_NAME}.env"
    set +a
  elif [[ -f "$ROOT/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$ROOT/.env"
    set +a
  fi
fi

exec bash "$ROOT/scripts/run-openkore.sh"
