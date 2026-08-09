# FreshGrind — one OpenKore folder, shared everything except account config

All bots use the same OpenKore install. **Shared** macros/items/monsters live in
`control/`. Each account is only a thin `profiles/<Name>/config.txt`.

**Solo grind** — no party / no follow. Job defaults to **random**.

## Progression

1. Leave novice training → Prontera  
2. Farm `prt_fild08` until Novice base 15 / job 10  
3. Job Master → `grindTargetJob` (**random** or a fixed 1st job)  
4. Buy class gear + enable class skills  
5. Farm `prt_fild08` until base 25  
6. Solo hunt `pay_fild03` until base 35  
7. Sell @ 40% OW, resume hunt  

## Layout

```
~/openkore/                         # ONE OpenKore
  openkore.pl
  control/                          # SHARED (eventMacros, items, mon, …)
  fresh_grind/control/              # pack source + config-shared.txt
  profiles/
    Grind01/
      config.txt                    # ONLY per-account file (login + job)
    Grind02/
      config.txt
```

OpenKore `--profile=Grind01` loads `profiles/Grind01/` first, then falls back to
`control/` for every other file.

## Add an account

```bash
bash openkore/scripts/install-shared-control.sh   # once / after pack edits
bash openkore/scripts/add-fresh-account.sh Grind02 myuser mypass random
# create char (Hercules auto-create via user_M on first login):
expect ~/openkore/scripts/create-char.exp Grind02 MyCharName M
# then strip _M from username in config if create script left it, and:
bash ~/openkore/scripts/start-bot.sh Grind02
```

Minimal `config.txt`:

```
!include ../../fresh_grind/control/config-shared.txt
username myuser
password mypass
char 0
grindTargetJob random
follow 0
grindPartyMode 0
lockMap prt_fild08
```

## Sync pack → control/

```bash
bash openkore/scripts/install-shared-control.sh
# or
python3 openkore/scripts/make-thin-grind-profiles.py ~/openkore openkore/fresh_grind/control
```
