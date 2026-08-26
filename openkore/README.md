# RagnaOne OpenKore packs (2-1 jobs only)

Human-like levelers for the Hercules pre-RE server (`PACKETVER 20180620`, `93.127.139.197`).

**Scope: classic 2-1 second jobs only** (no 2-2: Crusader / Sage / Monk / Alchemist / Rogue / Bard / Dancer).

| Pack | Path | Job path |
|------|------|----------|
| **Assassin** | `openkore/assassin/` (also default `openkore/control/`) | Novice → Thief → Assassin |
| **Knight** | `openkore/knight/` | Novice → Swordman → Knight |
| **Wizard** | `openkore/wizard/` | Novice → Magician → Wizard |
| **Hunter** | `openkore/hunter/` | Novice → Archer → Hunter |
| **Priest** | `openkore/priest/` | Novice → Acolyte → Priest |
| **Blacksmith** | `openkore/blacksmith/` | Novice → Merchant → Blacksmith |

## Install

```bash
./openkore/install-into-openkore.sh /path/to/openkore assassin
# classes: assassin knight wizard hunter priest blacksmith
```

For multi-bot, copy each class `control/*` into `~/openkore/profiles/<Name>/`, set credentials, then:

```bash
~/openkore/scripts/start-bot.sh Wizard
```

## Job Master (live)

NPC: **Prontera `150,180`** (`Job Master#ep2`)

First jobs: Swordman=`r0`, Magician=`r1`, Archer=`r2`, Acolyte=`r3`, Merchant=`r4`, Thief=`r5`

Second job (2-1 only): always `r0` (Knight / Wizard / Hunter / Priest / Blacksmith / Assassin).

## Shared map route (base → 99)

| Base Lv | Map |
|--------|-----|
| 1–11 | prt_fild08 |
| 12–20 | pay_fild08 |
| 21–30 | gef_fild00 |
| 31–40 | pay_dun00 |
| 41–50 | pay_dun01 |
| 51–60 | moc_pryd02 |
| 61–70 | moc_pryd03 |
| 71–80 | in_sphinx2 |
| 81–90 | in_sphinx3 |
| 91–99 | in_sphinx4 |

## Notes

- Set `username` / `password` / `char 0` per profile
- buyAuto/storage often disabled at low zeny — re-enable after bots have money
- `dcOnLevel 99` disconnects at base 99
