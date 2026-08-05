# RagnaOne

Hercules pre-renewal private server + OpenKore client setup.

| Setting | Value |
|---|---|
| Host | `173.208.138.84` |
| Login port | `6900` |
| Client / PACKETVER | `20180620` (2018-06-20e) |
| Emulator | Hercules (pre-renewal) |
| OpenKore serverType | `kRO_RagexeRE_2018_06_20e` |

Web client: http://173.208.138.84/ (roBrowser)

## OpenKore

### Setup

```bash
./scripts/setup-openkore.sh
```

This clones [OpenKore](https://github.com/OpenKore/openkore), installs build deps if needed, compiles `XSTools`, and adds the **RagnaOne** entry to `tables/servers.txt`.

### Connect

```bash
export RO_USERNAME='your_account'
export RO_PASSWORD='your_password'
# optional: RO_CHAR=0  RO_SERVER=0
./scripts/run-openkore.sh
```

Credentials are injected at runtime and are **not** written into the tracked config.

### Manual config (already applied by setup)

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
```

In `openkore/control/config.txt`: `master RagnaOne`

### Verified

OpenKore reaches the account server and receives a proper login response (invalid probe accounts return “Account name doesn't exist”).
### Verified in-game

Connected successfully with a test character:

- Character: **OKTest** (Novice, Male, Base/Job 1/1)
- Spawn: Prontera `(155, 183)`
- Char server `6121`, map server `5121`

