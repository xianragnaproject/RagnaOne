#!/usr/bin/env bash
# Allow OpenKore bots to attack monsters other players are already fighting.
# Adds early-return when config attackAuto_allowKS is enabled.
set -euo pipefail
MISC="${1:-$HOME/openkore/src/Misc.pm}"
[[ -f "$MISC" ]] || { echo "Missing $MISC"; exit 1; }
python3 - "$MISC" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text()
marker = "\treturn 1 if $config{attackAuto_allowKS};\n"
if marker in text:
    print(f'already patched {path}')
    raise SystemExit(0)

old1 = """sub checkMonsterCleanness {
\tmy ($ID) = @_;
\treturn 1 if (!$config{attackAuto});
\treturn 1 if $playersList->getByID($ID) || $slavesList->getByID($ID);
"""
new1 = """sub checkMonsterCleanness {
\tmy ($ID) = @_;
\treturn 1 if (!$config{attackAuto});
\treturn 1 if $config{attackAuto_allowKS};
\treturn 1 if $playersList->getByID($ID) || $slavesList->getByID($ID);
"""
old2 = """sub slave_checkMonsterCleanness {
\tmy ($slave, $ID) = @_;
\treturn 1 if (!$config{$slave->{configPrefix}.'attackAuto'});
\treturn 1 if $playersList->getByID($ID) || $slavesList->getByID($ID);
"""
new2 = """sub slave_checkMonsterCleanness {
\tmy ($slave, $ID) = @_;
\treturn 1 if (!$config{$slave->{configPrefix}.'attackAuto'});
\treturn 1 if $config{attackAuto_allowKS} || $config{$slave->{configPrefix}.'attackAuto_allowKS'};
\treturn 1 if $playersList->getByID($ID) || $slavesList->getByID($ID);
"""
if old1 not in text or old2 not in text:
    raise SystemExit('pattern not found — OpenKore version mismatch')
text = text.replace(old1, new1, 1).replace(old2, new2, 1)
path.write_text(text)
print(f'patched {path}')
PY
