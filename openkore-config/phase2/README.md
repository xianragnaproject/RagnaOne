# Phase 2 macros (1st class base 15–30)

Installed into `openkore/control/eventMacros.txt` (appended after Phase 1)
by `scripts/install-phase1.sh` / `scripts/install-phase2.sh`.

Triggers for **JobID 1–6** (Swordman, Mage, Archer, Acolyte, Merchant, Thief)
at **Base 15–30**:

| # | Behavior | Notes |
|---|---|---|
| 0 | Bootstrap | Leaves Phase1 Prontera park; sets `phase2Active` |
| 1 | Save @ Payon middle Kafra `181,104` | **run-once**; travel via **Kafra Teleport Service** (never field-walk to Payon) |
| 2 | `lockMap pay_fild08` | **run-once** (`phase2LockDone`) |
| 3 | Sell & buy Red Potion @ Payon `159,96` | OW ≥ 50% sell; restock pots |
| 4 | AFK near Payon middle Kafra | ~every 30 min, sit 5–15 min |
| 5 | Class-pure stats | Mage INT+DEX, Archer DEX+AGI, etc. |
| 6 | Auto skill points | Class skill lists via `skillsAddAuto` |

**Payon travel:** Prontera (or other town) → walk to local Kafra → Teleport Service `c r2 c r2` → Payon. From `pay_fild08` only the short town portal `17,75` is used (not cross-field routing).

Phase1 fountain park macros are gated with `ConfigKeyNot phase2Active 1` so they
stop once Phase2 starts.
