# RagnaOne OpenKore — Human-like Leveler

OpenKore control pack for your Hercules pre-RE server (`PACKETVER 20180620`).

Behavior goals:
- Level toward **base 99**
- Hunt, loot, **sell** junk, **buy** potions
- Sit when low HP/SP, rest in town, take breaks
- Change hunting maps as level rises (acts more like a normal player)

## 1) Install OpenKore

On the bot PC or Linux host:

```bash
git clone https://github.com/OpenKore/openkore.git
cd openkore
```

Copy this pack over OpenKore’s `control/` (and servers table):

```bash
# from your RagnaOne checkout
cp -r openkore/control/* /path/to/openkore/control/
cp openkore/tables/servers.txt /path/to/openkore/tables/servers.txt
# optional macros
cp openkore/control/eventMacros.txt /path/to/openkore/control/eventMacros.txt
```

## 2) Create an account on your server

Register a normal account on Hercules, create a **Novice → Thief → Assassin** character (config is tuned for Assassin).

Edit `control/config.txt`:

```txt
username YOUR_ACCOUNT
password YOUR_PASSWORD
char 0
```

Server IP is already set for `173.208.138.84` in `tables/servers.txt`.

## 3) Run

```bash
cd /path/to/openkore
# Linux
./openkore.pl
# or Windows: start.exe
```

Select **RagnaOne** from the master server list.

## Job Master + equips

**Job Master** is assumed at Prontera `153,193` (stock Hercules Euphy script).

Flow:
1. Novice Job 10+ → Job Master → **Thief**
2. Thief Job 40+ (Base 40+) → Job Master → **Assassin**

If your menu order differs, edit responses in `control/eventMacros.txt` (`r5` for Thief, `r0` for Assassin).

**Equips:** buys Knife → Main Gauche → Jur/Katar from Prontera weapon NPC and auto-equips better Assassin gear as base level rises. Keep-list prevents selling those weapons/armors.

## 5) Important notes

- This is for **your own private server** testing/population.
- Map NPC coordinates may need tuning if your custom NPCs differ from stock Hercules.
- If login fails, set `serverType` in `servers.txt` to match OpenKore’s closest type for `20180620` (try `kRO_RagexeRE_2018_06_20e` or nearest listed type).
- Raise rates slowly; if one-shotting everything, lower `attackAuto` aggression or pick harder maps in `eventMacros.txt`.

## 6) Quick tuning

- Stop at a level: set `dcOnLevel 99` (disconnect at 99) or leave blank to keep farming.
- Safer / slower: increase `sitAuto_hp_lower` / `sitAuto_sp_lower`.
- More human: enable break times in `config.txt` (`autoBreakTime`).
