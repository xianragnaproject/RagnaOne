# Phase 1 macros (Novice base 1–15)

Installed into `openkore/control/eventMacros.txt` by `scripts/setup-openkore.sh`
(or `scripts/install-phase1.sh`).

| # | Behavior | Trigger |
|---|---|---|
| 1 | `lockMap prt_fild08` (**run-once**, `phase1LockDone`) | Novice, base 1–15 |
| 2 | Save @ Prontera south Kafra `151,29` (**run-once**, `phase1SaveDone`) | Novice, base 1–15 |
| 3 | Sell @ tool dealer `prt_in 126,76` | Novice 1–15, OW ≥ 50% |
| 4 | Buy **50 Red Potion** | Novice, zeny ≥ 5000, stock 0 |
| 5 | Fountain AFK 45–90s (short — GM kicks long idle) | ~every 30 min while hunting |
| 6 | Job change (random 1st job) | **Job ≥ 10 and Base ≥ 15** |
| 7 | Park near Prontera fountain with anti-idle walks | Base ≥ 15 **and** jobbed |

### Auto skills / stats
Enabled via `raiseSkill` + `raiseStat` plugins (`skillsAddAuto` / `statsAddAuto`):

- **Novice:** `Basic Skill 9` + generic hunt stats (`dex`/`agi`/`str`/`vit`)
- **After job change:** class-specific skill + stat lists from `Phase1_ApplyJobBuild()`

Done bots **do not forever-sit** (that triggered GM kicks). They wander a few tiles near the fountain about every 75s. Short AFK breaks during grind sit 45–90s only.

Force a specific job instead of random:

```bash
# in OpenKore console, before job change:
conf grindTargetJob Thief
# Swordman | Magician | Archer | Acolyte | Merchant | Thief | random
```
