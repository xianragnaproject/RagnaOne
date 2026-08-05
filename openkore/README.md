# RagnaOne OpenKore packs

Human-like levelers for the Hercules pre-RE server (`PACKETVER 20180620`, `173.208.138.84`).

| Pack | Path | Job path |
|------|------|----------|
| **Assassin** | `openkore/assassin/` (also default `openkore/control/`) | Novice → Thief → Assassin |
| **Knight** | `openkore/knight/` | Novice → Swordman → Knight |
| **Crusader** | `openkore/crusader/` | Novice → Swordman → Crusader |
| **Wizard** | `openkore/wizard/` | Novice → Magician → Wizard |
| **Sage** | `openkore/sage/` | Novice → Magician → Sage |
| **Hunter** | `openkore/hunter/` | Novice → Archer → Hunter |
| **Bard** | `openkore/bard/` | Novice → Archer → Bard (male) |
| **Dancer** | `openkore/dancer/` | Novice → Archer → Dancer (female) |
| **Priest** | `openkore/priest/` | Novice → Acolyte → Priest |
| **Monk** | `openkore/monk/` | Novice → Acolyte → Monk |
| **Blacksmith** | `openkore/blacksmith/` | Novice → Merchant → Blacksmith |
| **Alchemist** | `openkore/alchemist/` | Novice → Merchant → Alchemist |
| **Rogue** | `openkore/rogue/` | Novice → Thief → Rogue |

## Install (multi-bot / profiles)

Recommended: one OpenKore install + OpenKore `profiles/` plugin (one folder per account).

```bash
git clone https://github.com/OpenKore/openkore.git ~/openkore
# build XSTools as usual, then:
cd ~/RagnaOne
for c in assassin knight blacksmith wizard hunter priest crusader sage monk alchemist rogue bard dancer; do
  mkdir -p ~/openkore/profiles/${c^} 2>/dev/null || true
done
# Or copy packs into profiles/<Name>/ directly from each class control/ folder.
./openkore/install-into-openkore.sh ~/openkore assassin   # seeds control/ + servers.txt
```

For profile-based multi-bot, copy each class `control/*` into `~/openkore/profiles/<Name>/` and set credentials.

```bash
~/openkore/scripts/start-bot.sh Wizard
# tmux attach -t ok-Wizard
```

## Job Master (live)

NPC: **Prontera `150,180`** (`Job Master#ep2`)

First jobs: Swordman=`r0`, Magician=`r1`, Archer=`r2`, Acolyte=`r3`, Merchant=`r4`, Thief=`r5`

Second jobs (typical Euphy order): 2-1=`r0`, 2-2=`r1` (Bard/Dancer gender-locked).

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
- Dancer requires a **female** character
- buyAuto/storage often disabled at low zeny — re-enable after bots have money
- `dcOnLevel 99` disconnects at base 99
- Tune Job Master `r#` if your script menu differs
