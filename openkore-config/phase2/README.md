# Phase 2 macros (1st class base 15–30)

Installed into `openkore/control/eventMacros.txt` (appended after Phase 1)
by `scripts/install-phase1.sh` / `scripts/install-phase2.sh`.

Triggers for **JobID 1–6** (Swordman, Mage, Archer, Acolyte, Merchant, Thief)
at **Base 15–30**, after Phase 1 has finished (`phase1Done` = arrived in Payon):

| # | Behavior | Notes |
|---|---|---|
| 0 | Bootstrap | Requires `phase1Done`; sets `phase2Active`, Payon shop/build |
| 1 | Save @ Payon middle Kafra `181,104` | **run-once**; already in Payon from Phase 1 (Kafra teleport if needed) |
| 2 | `lockMap pay_fild08` | **run-once** (`phase2LockDone`) |
| 3 | Sell & buy Red Potion @ Payon `159,96` | OW ≥ 50% sell; restock pots |
| 4 | AFK near Payon middle Kafra | ~every 30 min, sit 5–15 min |
| 5 | Class-pure stats | Mage INT+DEX, Archer DEX+AGI, etc. |
| 6 | Auto skill points | Class skill lists via `skillsAddAuto` |

**Payon travel:** Phase 1 ends by warping to Payon. Phase 2 only uses Kafra Teleport Service if it still needs to re-enter town (never field-walk). From `pay_fild08` only the short town portal `17,75` is used.

Phase1 fountain AFK / hunt macros stop once `phase2Active` is set.
