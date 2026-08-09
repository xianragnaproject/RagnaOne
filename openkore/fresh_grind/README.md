# FreshGrind — one OpenKore, login-only account configs

**Per account `config.txt` = username + password only.**  
Everything else is shared (`control/` + `config-shared.txt`) and **macros** change runtime state with `do conf …`.

## Layout

```
~/openkore/
  control/                 # SHARED macros/items/monsters/…
  fresh_grind/control/     # pack + config-shared.txt
  profiles/Grind01/
    config.txt             # ONLY:
                           #   !include …/config-shared.txt
                           #   username …
                           #   password …
```

## Account config

```
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

## What macros own

- `grindTargetJob random` → pick job at Job Master  
- lockMap / hunt map (`prt_fild08` → `pay_fild03`)  
- gear buy, skills, sell, unstuck, solo flags  

## Sync pack → control/

```bash
bash ~/openkore/scripts/install-shared-control.sh
```
