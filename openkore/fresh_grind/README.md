# Fresh grind pack — prt_fild08 1→25

Clean profile (no AssassinClean quest macros).

## Behavior
1. Aggressive farm on `prt_fild08` until Novice **base 15 + job 10**
2. Job change at Prontera Job Master (`155, 180`) — target from `grindTargetJob`
3. After 1st job only: auto-buy class gear (dagger / sword+shield / bow+arrow / etc.)
4. Keep grinding **`prt_fild08` until base 25**
5. Sell at ≥40% OW; occasional fountain AFK

## `grindTargetJob` values
`Swordman` | `Magician` | `Archer` | `Acolyte` | `Merchant` | `Thief`

## Profiles (example fleet)
| Profile | Class | Notes |
|---------|-------|-------|
| GrindPrt08 | Thief | original |
| GrindSword | Swordman | |
| GrindMage | Magician | |
| GrindArcher | Archer | |
| GrindAco | Acolyte | |
| GrindMerch | Merchant | |

Credentials live in `~/openkore/profiles/ACCOUNT_MAP.txt`.

## Create more class accounts
```bash
python3 openkore/scripts/batch-create-fresh-grind.py
```
