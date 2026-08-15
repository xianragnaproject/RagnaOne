# Phase 1 macros

Installed into `openkore/control/eventMacros.txt` by `scripts/setup-openkore.sh`.

Every gameplay setting is applied by a macro (`do conf` / `do pconf` / `do iconf`). Setup does not write lockMap, sell, loot, or stat lines into `config.txt`.

| # | Macro | When |
|---|---|---|
| 1 | `lockMap prt_fild08` | Novice, Base 1–15, **run once** |
| 2 | Random 1st job at Prontera Job Master (fountain `155,180`) | Novice, Base 15, Job 10 |
| 3 | Kafra Teleport Service → Payon, then save | 1st class, Base 15, **run once** |
| 4 | Autoloot all | **run once** |
| 5 | Sell at Prontera tool dealer (`prt_in 126,76`) | Novice, overweight ≥ 50% |
| 6 | Auto skills + stats | Novice |

Novice build (macro 6): `Basic Skill 9` and hunt stats (`dex` / `agi` / `str` / `vit`).
