# Phase 1 macros (Novice base 1–15)

Installed into `openkore/control/eventMacros.txt` by `scripts/setup-openkore.sh`
(or `scripts/install-phase1.sh`).

| # | Behavior | Trigger |
|---|---|---|
| 1 | `lockMap prt_fild08` (**run-once**, `phase1LockDone`) | Novice, base 1–15 |
| 2 | Save @ Prontera south Kafra `151,29` (**run-once**, `phase1SaveDone`) | Novice, base 1–15 |
| 3 | Sell @ tool dealer `prt_in 126,76` | Novice 1–15, OW ≥ 50% |
| 4 | Buy **50 Red Potion** | Novice, zeny ≥ 5000, stock 0 |
| 5 | Fountain AFK 5–15 min | ~every 30 min while hunting |
| 6 | Job change (random 1st job) | **Job ≥ 10 and Base ≥ 15** |
| 7 | Sit near Prontera fountain | Base ≥ 15 **and** jobbed |

### Auto skills / stats
Enabled via `raiseSkill` + `raiseStat` plugins (`skillsAddAuto` / `statsAddAuto`):

- **Novice:** `Basic Skill 9` + generic hunt stats (`dex`/`agi`/`str`/`vit`)
- **After job change:** class-specific skill + stat lists from `Phase1_ApplyJobBuild()`

AFK / done sit always picks a **random plaza tile** and takes a **random facing step** (not always north) before sitting.

Force a specific job instead of random:

```bash
# in OpenKore console, before job change:
conf grindTargetJob Thief
# Swordman | Magician | Archer | Acolyte | Merchant | Thief | random
```
