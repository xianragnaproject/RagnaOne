#!/usr/bin/env bash
# Add a FreshGrind account: creates profiles/<Name>/config.txt ONLY.
# All macros/items/monsters live in openkore/control/ (shared).
#
# Usage:
#   ./scripts/add-fresh-account.sh <ProfileName> <username> <password> [job=random]
# Example:
#   ./scripts/add-fresh-account.sh Grind02 myuser mypass random
set -euo pipefail
NAME="${1:-}"
USER="${2:-}"
PASS="${3:-}"
JOB="${4:-random}"
OK="${OPENKORE_HOME:-$HOME/openkore}"
DST="$OK/profiles/$NAME"

if [[ -z "$NAME" || -z "$USER" || -z "$PASS" ]]; then
  echo "Usage: $0 <ProfileName> <username> <password> [job=random]"
  echo "  job: Swordman|Magician|Archer|Acolyte|Merchant|Thief|random"
  exit 1
fi

# Ensure shared control is installed
bash "$OK/scripts/install-shared-control.sh" || bash "$(dirname "$0")/install-shared-control.sh"

if [[ -d "$DST" ]]; then
  echo "Profile already exists: $DST"
  exit 1
fi
mkdir -p "$DST"

cat > "$DST/config.txt" <<EOF
######## Account config only — everything else is shared in control/ ########
# Macros/items/monsters: openkore/control/ (from fresh_grind pack)
# grindTargetJob: Swordman|Magician|Archer|Acolyte|Merchant|Thief|random
!include ../../fresh_grind/control/config-shared.txt

username $USER
password $PASS
char 0

grindTargetJob $JOB
grindPartyMode 0
grindPartyRole solo
follow 0
followTarget
followBot 0
partyAuto 0
lockMap prt_fild08
route_randomWalk 1
attackAuto 2
attackAuto_followTarget 0
attackAuto_party 0
sellAuto 1
teleportAuto_deadly 0

grindLeftTraining 0
grindAfk 0
grindSelling 0
grindJobbing 0
grindJob1st 0
grindGearDone 0
grindDone15 0
grindDone25 0
grindDone35 0
EOF

# Append ACCOUNT_MAP if present
MAP="$OK/profiles/ACCOUNT_MAP.txt"
if [[ ! -f "$MAP" ]]; then
  printf '%s\n' '# profile_label	ProfileDir	CharName	username	password	sex' > "$MAP"
fi
echo -e "FreshGrind\t$NAME\t\t$USER\t$PASS\t" >> "$MAP"

echo "Created $DST/config.txt (shared control, job=$JOB)"
echo "Start: $OK/scripts/start-bot.sh $NAME"
echo "If the account has no char yet: expect $OK/scripts/create-char.exp $NAME <CharName> M"
