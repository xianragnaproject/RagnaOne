# FreshGrind shared control pack (SOLO)

One shared folder for all grind accounts. Per-account files only hold **login + job**.
**No party / no follow** — every bot lockMaps and hunts alone.

## Progression

1. Leave novice training → Prontera  
2. Farm `prt_fild08` until Novice base 15 / job 10  
3. Job Master → `grindTargetJob` (or `random`)  
4. Buy class gear + enable class skills  
5. Farm `prt_fild08` until base 25  
6. Solo hunt `pay_fild03` until base 35  
7. Sell @ 40% OW, resume hunt  

## Layout

```
openkore/fresh_grind/control/     # SOURCE OF TRUTH
  config-shared.txt
  eventMacros.txt
  items_control.txt / mon_control.txt / ...

openkore/profiles/GrindSword/
  config.txt                      # thin: !include + username/password/job
  eventMacros.txt -> shared symlink
```

## Add a new account

```
!include ../../fresh_grind/control/config-shared.txt
username myuser
password mypass
char 0
grindTargetJob random
follow 0
grindPartyMode 0
lockMap pay_fild03
```

```bash
python3 openkore/scripts/make-thin-grind-profiles.py ~/openkore openkore/fresh_grind/control
```

## Sync

```bash
python3 openkore/scripts/make-thin-grind-profiles.py ~/openkore openkore/fresh_grind/control
# or
bash openkore/scripts/sync-all-profiles.sh
```
