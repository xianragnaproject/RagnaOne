# RagnaOne

Hercules / rAthena pre-renewal Episode 4 private server + OpenKore client setup.

| Setting | Value |
|---|---|
| Host | `173.208.138.84` |
| Login port | `6900` |
| Char port | `6121` |
| Map port | `5121` |
| Client / PACKETVER | `20180620` (`kRO_RagexeRE_2018_06_20e`) |
| Type | Pre-renewal Ep4 |
| MD5 passwords | OFF |
| PIN | OFF |
| Packet obfuscation | OFF |

Web client: http://173.208.138.84/

## OpenKore

### Cloud phone (Termux worker)

Download then run (avoids a harmless proot stdin warning from `curl | bash`):

```bash
curl -fsSL -o ~/termux-worker.sh \
  https://raw.githubusercontent.com/xianragnaproject/RagnaOne/cursor/termux-openkore-worker-db18/scripts/termux-worker.sh
bash ~/termux-worker.sh
```

After install, helpers appear in Termux home:

```bash
~/ok-start.sh MyBot_M mypassword   # start bot in tmux
~/ok-attach.sh                     # watch console
~/ok-status.sh                     # status + last logs
~/ok-login.sh                      # Ubuntu shell (repo at /root/RagnaOne)
```

Disable Termux battery optimization / keep a wake lock so the phone does not kill the bot.

If you already saw `can't sanitize binding "/proc/self/fd/0"`: that warning alone is OK. If install stopped, Ctrl+C and use the download-then-run commands above.

### Setup (Linux / Cursor VM)

```bash
bash ./scripts/setup-openkore.sh
```

Clones [OpenKore](https://github.com/OpenKore/openkore), installs build deps if needed, compiles `XSTools`, and adds the **RagnaOne** entry to `tables/servers.txt`.

### Connect one account

```bash
export RO_USERNAME='your_account'
export RO_PASSWORD='your_password'
# optional: RO_CHAR=0  RO_SERVER=0
bash ./scripts/run-openkore.sh
```

Credentials are injected at runtime and are **not** written into tracked config.

New accounts on this server can usually be created by logging in with a username ending in `_M` or `_F` (sex) if auto-registration is enabled.

### Manual config (applied by setup)

In `openkore/tables/servers.txt`:

```
[RagnaOne]
ip 173.208.138.84
port 6900
master_version 1
version 55
serverType kRO_RagexeRE_2018_06_20e
serverEncoding Western
charBlockSize 155
addTableFolders kRO/RagexeRE_2018_06_21a;translated/kRO_english;kRO
private 1
pinCode 0
sendCryptKeys 0x00000000, 0x00000000, 0x00000000
```

In `openkore/control/config.txt`: `master RagnaOne`

## Phase 1 macros (Novice 1–15)

```bash
bash ./scripts/install-phase1.sh   # also installs Phase 2
```

Macros set their own config (lockMap, save, sellAuto, buyAuto). See `openkore-config/phase1/README.md`.

| # | Macro does | When |
|---|---|---|
| 1 | Lock `prt_fild08` (run-once) | Novice base 1–15 |
| 2 | Save Prontera south (run-once) | Novice base 1–15 |
| 3 | Sell @ tool dealer | Novice, OW ≥ 50% |
| 4 | Buy 50 Red Potion | Novice, zeny ≥ 5000, stock 0 |
| 5 | Fountain AFK 5–15 min | ~every 30 min |
| 6 | Random 1st job change | Job ≥ 10 and Base ≥ 15 |
| 7 | Sit by fountain | Base ≥ 15 and jobbed (until Phase2) |

## Phase 2 macros (1st class 15–30)

Auto-triggers for JobID 1–6. See `openkore-config/phase2/README.md`.

| # | Macro does | When |
|---|---|---|
| 1 | Save @ Payon middle Kafra `181,104` (run-once) | 1st class 15–30 |
| 2 | Lock `pay_fild08` (run-once) | after Payon save |
| 3 | Sell/buy potions @ Payon `159,96` | OW ≥ 50% / low pots |
| 4 | AFK near Payon middle Kafra | ~every 30 min |
| 5–6 | Pure class stats + auto skills | Mage INT+DEX, Archer DEX+AGI, … |

```bash
bash ./scripts/install-phase2.sh
```

### Verified

Fresh OpenKore install connected to RagnaOne and entered the game:

- Account auto-created via `_M` suffix registration
- Character: **OKFresh1** (now Mage after Phase1 job change)
- Spawn / hunt: Prontera → `prt_fild08`
- Login `6900` → Char `6121` → Map `5121`
## 24/7 keep-alive

```bash
bash ./scripts/start-24x7.sh          # cron every minute + tmux watchdog loop
bash ./scripts/watchdog-openkore.sh status
bash ./scripts/watchdog-openkore.sh ensure   # restart if down
```

## Multi-bot

```bash
# Create + start another account (auto-reg, char, Phase1 macros)
bash ./scripts/create-and-start-bot.sh Fresh4 FreshFour M

# Status / keep-alive for all mapped bots
bash ./scripts/watchdog-openkore.sh status
bash ./scripts/start-24x7.sh
```

Credentials live in gitignored `accounts/*.env` + `accounts/ACCOUNT_MAP.txt`.
