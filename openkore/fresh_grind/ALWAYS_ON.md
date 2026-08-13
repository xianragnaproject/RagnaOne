# FreshGrind 24/7 — Cursor vs VPS

## Why bots go “all offline again”

This fleet currently runs inside a **Cursor Cloud Agent VM**. That VM is **not** a dedicated always-on server:

| What happens | Result |
|---|---|
| Agent goes **IDLE** / you stop chatting | VM can sleep or recycle → all bots die |
| Agent is **archived** / killed | Everything offline until a new agent boots |
| Cloudflare **quick tunnel** rotates / 501s | Panel looks “down” even if bots are still up |
| Load average ~30–40 with ~46 bots | Map login timeouts / disconnects (watchdog relogs) |

Watchdogs inside the VM only help **while the VM is up**. They cannot outlive Cursor archiving the agent.

## Right now (this agent)

While [this agent](https://cursor.com/agents/bc-37ff1c98-aff1-4847-8fa1-31ac359229f7) is **RUNNING**:

```bash
bash ~/openkore/scripts/fleet-status.sh
cat ~/openkore/fleet_panel/PUBLIC_URL.txt
```

Panel password: `~/openkore/fleet_panel/panel.pass`

## True 24/7: cheap Linux VPS

1. Rent any always-on Ubuntu VPS (2–4 vCPU / 4–8 GB RAM recommended for ~40 bots).
2. Clone this repo and run:

```bash
sudo bash scripts/vps-install-fleet.sh
```

That installs a **systemd** unit `openkore-fleet` which:

- starts all Grind* bots + fleet watchdog + web panel + Cloudflare tunnel
- runs `fleet-supervisor.sh` forever and **restarts on reboot / crash**

```bash
sudo systemctl status openkore-fleet
bash ~/openkore/scripts/fleet-status.sh
```

3. Open the panel URL from `~/openkore/fleet_panel/PUBLIC_URL.txt` (or bind `:8787` behind your own reverse proxy / named Cloudflare tunnel for a stable hostname).

## Cursor auto-start (best-effort only)

`.cursor/environment.json` has:

```json
{
  "install": "./scripts/setup-openkore.sh",
  "start": "./scripts/start-openkore-fleet.sh"
}
```

That only helps when a **new** Cursor agent boots this repo. It does **not** keep bots online after the agent idles out. Merge this to `main` and keep the agent RUNNING if you want Cursor-side recovery — still not real 24/7.

## Recommendation

Use the **VPS systemd path** for production grinding. Keep Cursor agents for coding / macro fixes, not hosting.
