# RagnaOne OpenKore packs

Human-like levelers for your Hercules pre-RE server (`PACKETVER 20180620`, `173.208.138.84`).

| Pack | Path | Job path |
|------|------|----------|
| **Assassin** | `openkore/assassin/` (also `openkore/control/`) | Novice → Thief → Assassin |
| **Knight** | `openkore/knight/` | Novice → Swordman → Knight |

## Install on the OpenKore host (multi-bot)

```bash
git clone https://github.com/OpenKore/openkore.git ~/openkore-assassin
git clone https://github.com/OpenKore/openkore.git ~/openkore-knight

git clone -b cursor/openkore-human-leveler-159c https://github.com/xianragnaproject/RagnaOne.git ~/RagnaOne
cd ~/RagnaOne

./openkore/install-into-openkore.sh ~/openkore-assassin assassin
./openkore/install-into-openkore.sh ~/openkore-knight knight
```

Edit each config:

```bash
nano ~/openkore-assassin/control/config.txt   # account A
nano ~/openkore-knight/control/config.txt     # account B
```

Set `username` / `password` (different accounts).

Start separately:

```bash
tmux new -s ok-assassin -d "cd ~/openkore-assassin && perl ./openkore.pl"
tmux new -s ok-knight  -d "cd ~/openkore-knight  && perl ./openkore.pl"
```

## Knight map route

| Base Lv | Map |
|--------|-----|
| 1–11 | prt_fild08 |
| 12–20 | pay_fild08 |
| 21–30 | gef_fild00 |
| 31–40 | pay_dun00 |
| 41–50 | pay_dun01 |
| 51–60 | gef_fild10 (Orcs) |
| 61–70 | orcsdun01 |
| 71–80 | c_tower1 |
| 81–90 | gl_step |
| 91–99 | gl_knt01 |

Job Master: Prontera `153,193` → Swordman (`r0`) → Knight (`r0`).

Equips: Knife → Sword+Guard → Bastard Sword+Shield → Two-Handed Sword / Broad Sword.

## Assassin map route

See `assassin/control/eventMacros.txt` (Pyramid / Sphinx path).

## Notes

- Enable Job Master on Hercules: `npc/custom/jobmaster.txt` in `scripts_custom.conf`
- Tune Job Master `r#` and weapon NPC `175,126` if your scripts differ
- `dcOnLevel 99` disconnects at base 99
