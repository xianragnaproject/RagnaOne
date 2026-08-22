#!/usr/bin/env bash
# Ping = keep-alive for Cursor Cloud Agents.
#
# Cursor tears down the VM when the agent goes IDLE/ARCHIVED.
# Internal cron cannot save a dead pod. This script runs OUTSIDE Cursor
# (your PC, phone cron, always-on VPS, or GitHub Actions) and sends a
# short follow-up via the Cloud Agents API so the agent stays RUNNING.
#
# Setup:
#   1) Create an API key: https://cursor.com/dashboard → Cloud Agents → API Keys
#   2) export CURSOR_API_KEY='...'
#   3) export CURSOR_AGENT_ID='bc-44af0d07-7e5a-499a-a294-839d21459cac'  # this fleet agent
#   4) Run once:  bash scripts/cloud-agent-ping-keepalive.sh
#   5) Cron every 20 min (example):
#        */20 * * * * CURSOR_API_KEY=... CURSOR_AGENT_ID=bc-... \
#          /path/to/repo/scripts/cloud-agent-ping-keepalive.sh >>/tmp/cursor-ping.log 2>&1
#
# GitHub Actions: see .github/workflows/cloud-agent-ping-keepalive.yml
#
# Docs: https://cursor.com/docs/cloud-agent/api/endpoints  (POST /v1/agents/{id}/runs)
set -euo pipefail

API_BASE="${CURSOR_API_BASE:-https://api.cursor.com}"
AGENT_ID="${CURSOR_AGENT_ID:-bc-44af0d07-7e5a-499a-a294-839d21459cac}"
KEY="${CURSOR_API_KEY:-${CURSOR_API_KEY_BASIC:-}}"
INTERVAL_SEC="${CURSOR_PING_INTERVAL_SEC:-0}"   # 0 = single shot; >0 = loop
PROMPT_TEXT="${CURSOR_PING_PROMPT:-PING_KEEPALIVE: keep this Cloud Agent RUNNING. Run: cd /home/ubuntu/openkore && ./run-bots.sh heal; ./run-bots.sh status | grep running=; date -u. Reply with one line: running=N. Do not archive. Do not stop the fleet.}"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "[$(ts)] $*"; }

if [[ -z "$KEY" ]]; then
  cat >&2 <<'EOF'
Missing CURSOR_API_KEY.

Create a key at https://cursor.com/dashboard (Cloud Agents → API Keys), then:
  export CURSOR_API_KEY='key_...'
  export CURSOR_AGENT_ID='bc-44af0d07-7e5a-499a-a294-839d21459cac'
  bash scripts/cloud-agent-ping-keepalive.sh
EOF
  exit 2
fi

ping_once() {
  local url status body code
  url="$API_BASE/v1/agents/$AGENT_ID/runs"
  log "ping agent=$AGENT_ID"

  # Basic auth: API key as username, empty password (per Cursor docs: -u KEY:)
  body=$(curl -sS -u "${KEY}:" \
    -H 'Content-Type: application/json' \
    -X POST "$url" \
    --data "$(python3 - <<'PY'
import json, os
print(json.dumps({"prompt": {"text": os.environ["PROMPT_TEXT"]}}))
PY
)" \
    -w '\n%{http_code}' \
    -A 'RagnaOne-cloud-agent-ping-keepalive/1.0' \
    --connect-timeout 20 --max-time 60) || {
      log "ERROR curl failed"
      return 1
    }

  code=$(echo "$body" | tail -n1)
  status=$(echo "$body" | sed '$d')
  case "$code" in
    200|201|202)
      log "OK http=$code $(echo "$status" | python3 -c 'import sys,json; d=json.load(sys.stdin); r=d.get("run") or d; print("run="+str(r.get("id","?"))+" status="+str(r.get("status","?")))' 2>/dev/null || echo "$status" | head -c 200)"
      return 0
      ;;
    409)
      log "BUSY http=409 (agent already running a turn — treat as alive)"
      return 0
      ;;
    401|403)
      log "AUTH http=$code — check CURSOR_API_KEY"
      echo "$status" | head -c 400 >&2
      return 2
      ;;
    404)
      log "NOT_FOUND http=404 — agent archived/killed? id=$AGENT_ID"
      echo "$status" | head -c 400 >&2
      return 3
      ;;
    *)
      log "FAIL http=$code"
      echo "$status" | head -c 400 >&2
      return 1
      ;;
  esac
}

export PROMPT_TEXT

if [[ "${INTERVAL_SEC}" -gt 0 ]]; then
  log "loop every ${INTERVAL_SEC}s → agent $AGENT_ID"
  while true; do
    ping_once || true
    sleep "$INTERVAL_SEC"
  done
else
  ping_once
fi
