# RagnaOne — 40-bot Cloud VM (shard0)

This branch runs **FreshGrind shard0** on a single Cursor Cloud Agent VM:
- **40 bots:** `Grind01`–`Grind40` (`openkore/fleet_shards/shard0.txt`)
- **Panel:** port `8787` (password in `~/openkore/fleet_panel/panel.pass`)
- **Keep the agent RUNNING** — archiving/killing the agent stops the VM and all bots

```bash
export FLEET_SHARD=0
bash ./scripts/setup-openkore.sh
bash ./openkore/scripts/materialize-profiles-from-map.sh
bash ./scripts/start-openkore-fleet.sh
bash ~/openkore/scripts/fleet-status.sh
```

# RagnaOne

Private Hercules pre-renewal server tooling.

See [`openkore/README.md`](openkore/README.md) for OpenKore **2-1 second job** bot packs (Assassin, Knight, Wizard, Hunter, Priest, Blacksmith).

## Source copy (required)

Working Phase 1/2 bots live on `administrator@93.127.139.197:/home/administrator/openkore`
(local branch `cursor/phase1-auto-stats-skills-4ed6`). **Do not** bootstrap from upstream OpenKore alone.

```bash
# After SOURCE_SSH_PRIVATE_KEY or SOURCE_SSH_PASSWORD is available:
export FLEET_TARGET=40
bash ./scripts/rsync-from-source.sh
# then follow SETUP_NOTES.md, build XSTools if needed, and:
cd ~/openkore && ./run-bots.sh start && ./run-bots.sh status
```

Tuned source settings to preserve: `itemsMaxWeight_sellOrStore 28`, Hats sell,
`storageAuto 0` while broke, sit 20%→90%, sell Butcher `prontera 64,125`,
buy Red Potion `prt_in 126,76`. Console: use `ai on` (never bare `ai`).

