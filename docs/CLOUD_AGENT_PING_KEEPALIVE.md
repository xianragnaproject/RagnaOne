# Cloud Agent ping = keep-alive

Cursor **will shut the VM** when the agent goes IDLE / ARCHIVED.
Pinging the game server or curling localhost inside the pod does **nothing** after that.

**Ping keep-alive** means: something *outside* Cursor sends a follow-up to this agent on a timer via the Cloud Agents API (`POST /v1/agents/{id}/runs`). That keeps status **RUNNING** so the 40-bot fleet pod stays up.

## This fleet agent

- URL: https://cursor.com/agents/bc-44af0d07-7e5a-499a-a294-839d21459cac
- ID: `bc-44af0d07-7e5a-499a-a294-839d21459cac`

## One-time setup

1. Create an API key: [Cursor Dashboard → Cloud Agents → API Keys](https://cursor.com/dashboard)
2. Never commit the key.

### Option A — GitHub Actions (easiest)

1. Repo → **Settings → Secrets** → add `CURSOR_API_KEY`
2. Optional: **Variables** → `CURSOR_AGENT_ID` = `bc-44af0d07-7e5a-499a-a294-839d21459cac`
3. Enable Actions; workflow `.github/workflows/cloud-agent-ping-keepalive.yml` runs every **20 minutes**
4. Test: **Actions → cloud-agent-ping-keepalive → Run workflow**

### Option B — Your PC / VPS cron

```bash
export CURSOR_API_KEY='key_...'
export CURSOR_AGENT_ID='bc-44af0d07-7e5a-499a-a294-839d21459cac'
bash scripts/cloud-agent-ping-keepalive.sh   # single ping

# every 20 minutes
crontab -e
*/20 * * * * CURSOR_API_KEY=key_... CURSOR_AGENT_ID=bc-44af0d07-7e5a-499a-a294-839d21459cac \
  /path/to/RagnaOne/scripts/cloud-agent-ping-keepalive.sh >>/tmp/cursor-ping.log 2>&1
```

Loop on a spare always-on box:

```bash
CURSOR_PING_INTERVAL_SEC=1200 bash scripts/cloud-agent-ping-keepalive.sh
```

### Option C — Cursor Automations

Create a scheduled automation at https://cursor.com/automations that every ~20–30 min prompts this repo with:

`PING_KEEPALIVE: keep Cloud Agent RUNNING; heal fleet; reply running=N`

(Same effect as the API ping.)

## What the agent does on ping

The follow-up text starts with `PING_KEEPALIVE`. The agent should:

1. `cd /home/ubuntu/openkore && ./run-bots.sh heal`
2. Print `running=N`
3. Not archive, not stop the fleet

## Limits

| Method | Keeps VM up? |
|---|---|
| Ping via API / Automation / cron (outside) | **Yes** (while pings continue) |
| `always-on-24x7.sh` / cron **inside** the pod | Only while agent is already RUNNING |
| Archiving / killing the agent | **No** — pod dies immediately |
| Real VPS + `scripts/vps-install-fleet.sh` | **Yes** — true 24/7 without Cursor |

For a week-long test: enable Option A or B **and** do not archive this agent.
