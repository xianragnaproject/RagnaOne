# Phase 1 macros (Novice base 1–15)

Installed into `openkore/control/eventMacros.txt` by `scripts/setup-openkore.sh`
(or `scripts/install-phase1.sh`).

| # | Behavior | Trigger |
|---|---|---|
| 1 | `lockMap prt_fild08` (**run-once**, `phase1LockDone`) | Novice, base 1–15 |
| 2 | Save @ Prontera south Kafra `151,29` (**run-once**, `phase1SaveDone`) | Novice, base 1–15 |
| 3 | Sell @ tool dealer `prt_in 126,76` | Novice 1–15, OW ≥ 50% |
| 4 | Buy **50 Red Potion** | Novice, zeny ≥ 5000, stock 0 |
| 5 | *(removed)* Fountain AFK idle | caused GM idle kicks |
| 6 | Job change (random 1st job) | **Job ≥ 10 and Base ≥ 15** |
| 7 | Keep hunting `prt_fild08` | Base ≥ 15 **and** jobbed |

### Auto skills / stats
Enabled via `raiseSkill` + `raiseStat` plugins (`skillsAddAuto` / `statsAddAuto`):

- **Novice:** `Basic Skill 9` + generic hunt stats (`dex`/`agi`/`str`/`vit`)
- **After job change:** class-specific skill + stat lists from `Phase1_ApplyJobBuild()`

**No idle park / no AFK sits.** RagnaOne force-disconnects idle characters (“forced to disconnect by a GM”). Bots stay hunting after job change; `sitAuto_idle` is off.

Force a specific job instead of random:

```bash
# in OpenKore console, before job change:
conf grindTargetJob Thief
# Swordman | Magician | Archer | Acolyte | Merchant | Thief | random
```
