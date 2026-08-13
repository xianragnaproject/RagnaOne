#!/usr/bin/env bash
# Add a FreshGrind account: profiles/<Name>/config.txt = LOGIN ONLY.
# All behavior comes from shared control/ + macros (do conf …).
#
# Usage:
#   ./scripts/add-fresh-account.sh <ProfileName> <username> <password>
set -euo pipefail
NAME="${1:-}"
USER="${2:-}"
PASS="${3:-}"
OK="${OPENKORE_HOME:-$HOME/openkore}"
DST="$OK/profiles/$NAME"

if [[ -z "$NAME" || -z "$USER" || -z "$PASS" ]]; then
  echo "Usage: $0 <ProfileName> <username> <password>"
  exit 1
fi

bash "$OK/scripts/install-shared-control.sh" 2>/dev/null \
  || bash "$(dirname "$0")/install-shared-control.sh"

if [[ -d "$DST" ]]; then
  echo "Profile already exists: $DST"
  exit 1
fi
mkdir -p "$DST"

cat > "$DST/config.txt" <<EOF
######## Account only — macros + shared control own everything else ########
# profiles/ plugin loads THIS config.txt instead of control/config.txt,
# so include the full base config first or defaults (clientSight, etc.) are missing.
!include ../../control/config.txt
!include ../../fresh_grind/control/config-shared.txt
username $USER
password $PASS
EOF

MAP="$OK/profiles/ACCOUNT_MAP.txt"
if [[ ! -f "$MAP" ]]; then
  printf '%s\n' '# profile_label	ProfileDir	CharName	username	password	sex' > "$MAP"
fi
echo -e "FreshGrind\t$NAME\t\t$USER\t$PASS\t" >> "$MAP"

echo "Created $DST/config.txt (login only)"
echo "Start: $OK/scripts/start-bot.sh $NAME"
