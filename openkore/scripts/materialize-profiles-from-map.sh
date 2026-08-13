#!/usr/bin/env bash
# Materialize thin Grind* profiles from ACCOUNT_MAP.txt (tab-separated).
# Map columns: label ProfileDir CharName username password sex
set -euo pipefail
OK="${OPENKORE_HOME:-$HOME/openkore}"
MAP="${1:-$OK/profiles/ACCOUNT_MAP.txt}"
SHARD_FILE="${FLEET_SHARD_FILE:-}"

if [[ ! -f "$MAP" ]]; then
  echo "ACCOUNT_MAP missing: $MAP" >&2
  exit 1
fi

bash "$OK/scripts/install-shared-control.sh" 2>/dev/null || true
mkdir -p "$OK/profiles"

allow() {
  local p="$1"
  [[ -z "$SHARD_FILE" || ! -f "$SHARD_FILE" ]] && return 0
  grep -qx "$p" "$SHARD_FILE"
}

n=0
while IFS=$'\t' read -r label dir char user pass sex; do
  [[ -z "${label:-}" || "$label" =~ ^# ]] && continue
  [[ -z "${dir:-}" || -z "${user:-}" || -z "${pass:-}" ]] && continue
  allow "$dir" || continue
  mkdir -p "$OK/profiles/$dir"
  cat > "$OK/profiles/$dir/config.txt" <<EOF
######## Account only — macros + shared control own everything else ########
!include ../../control/config.txt
!include ../../fresh_grind/control/config-shared.txt
username $user
password $pass
EOF
  n=$((n + 1))
  echo "profile $dir ($user)"
done < "$MAP"

echo "materialized $n profiles (shard=${SHARD_FILE:-all})"
