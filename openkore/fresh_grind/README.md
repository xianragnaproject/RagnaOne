# FreshGrind shared control pack

One shared folder for all grind accounts. Per-account files only hold **login + role**.

## Layout

```
openkore/fresh_grind/control/     # SOURCE OF TRUTH (edit here)
  config-shared.txt               # combat, buy/equip, all 1st-job skills
  eventMacros.txt                 # JobID-gated macros
  items_control.txt / mon_control.txt / ...

openkore/profiles/GrindSword/
  config.txt                      # thin: !include + username/password/role
  eventMacros.txt -> ../../fresh_grind/control/eventMacros.txt
  ...
```

## Add a new account

1. Create a blank profile folder (or copy any `Grind*`).
2. Put credentials in `profiles/ACCOUNT_MAP.txt` or the thin `config.txt`:
   ```
   !include ../../fresh_grind/control/config-shared.txt
   username myuser
   password mypass
   char 0
   grindTargetJob random
   grindPartyRole follower
   follow 1
   followTarget Cedric
   ```
3. Run:
   ```bash
   python3 openkore/scripts/make-thin-grind-profiles.py ~/openkore openkore/fresh_grind/control
   ```
4. Start: `./scripts/run-profile.sh GrindNewName`

## Job selection

| `grindTargetJob` | Behavior |
|------------------|----------|
| `Swordman` / `Magician` / `Archer` / `Acolyte` / `Merchant` / `Thief` | Fixed class at Job Master |
| `random` (or empty) | Macro picks a random 1st job, then enables that class’s skills/gear |

Macros that buy swords, cast Mammonite, heal, etc. are **JobID-gated** — they only fire for the matching class.

## Party fleet (current)

Fixed roles (not random), so Cedric stays tank leader:

| Profile | Job | Role |
|---------|-----|------|
| GrindSword | Swordman | leader |
| GrindPrt08 | Thief | follower |
| GrindMage | Magician | follower |
| GrindArcher | Archer | follower |
| GrindAco | Acolyte | follower |
| GrindMerch | Merchant | follower |

## Sync from repo → live OpenKore

```bash
python3 openkore/scripts/make-thin-grind-profiles.py ~/openkore openkore/fresh_grind/control
# or via sync-all-profiles.sh (calls the thin builder for Grind*)
bash openkore/scripts/sync-all-profiles.sh
```

Edit **macros/combat once** under `fresh_grind/control/` — every Grind account picks it up (symlinks / include).
