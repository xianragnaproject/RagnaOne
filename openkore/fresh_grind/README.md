# FreshGrind — one OpenKore, login-only account configs

**Per account `config.txt` = username + password only.**  
Everything else is shared (`control/` + `config-shared.txt`) and **macros** change runtime state with `do conf …`.

## Layout

```
~/openkore/
  control/                 # SHARED macros/items/monsters/… + full config.txt defaults
  fresh_grind/control/     # pack + config-shared.txt
  profiles/Grind01/
    config.txt             # login only:
                           #   !include ../../control/config.txt
                           #   !include …/config-shared.txt
                           #   username …
                           #   password …
```

## Account config

`--profile=X` makes OpenKore load `profiles/X/config.txt` **instead of**
`control/config.txt`. Always include the full base config first, then shared
overrides, then credentials:

```
!include ../../control/config.txt
!include ../../fresh_grind/control/config-shared.txt
username myuser
password mypass
```

## Add account

```bash
bash ~/openkore/scripts/add-fresh-account.sh Grind02 myuser mypass
expect ~/openkore/scripts/create-char.exp Grind02 CharName M
bash ~/openkore/scripts/start-bot.sh Grind02
```

## Phase 1 macros (base 1–15)

1. **Red Potion autobuy** @ Prontera tool dealer — Novice only, zeny > 2000, stock 0  
2. **Autosell** at **30%** weight  
3. **Random fountain AFK** — random tile, **5–10 min** breaks while grinding  
4. **Auto stats / skills** (`statsAddAuto` / `skillsAddAuto` in config-shared)  
5. **Job change at Job Level 10** (Novice, high priority, random 1st job)  

After **base 15 + job change** → Prontera fountain AFK (`grindPhase1Done 1`).  
Non-Swordman stay AFK here.

## Phase 2 macros (Swordman only)

Triggers when **JobID 1 (Swordsman) + base ≥ 15** (`grindPhase2 1`):

1. **Alberta** — buy **Guard** (`alberta_in` armor shop)  
2. **Payon Kafra** — set **savepoint** (181,104)  
3. **Payon shops** — buy **Blade / Shoes / Wooden Mail / Manteau**  
4. Hunt **`pay_fild08`**; potions + sell at Payon tool dealer  
5. AFK breaks near **Payon Kafra**

## What macros own

- `grindTargetJob random` → pick job at Job Master  
- lockMap / hunt map (`prt_fild08`; phase2 Swordman → `pay_fild08`)  
- potions, skills, sell, AFK, unstuck, solo flags  

## Sync pack → control/

```bash
bash ~/openkore/scripts/install-shared-control.sh
```
