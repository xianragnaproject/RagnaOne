#!/usr/bin/env python3
"""Apply party-follower follow settings to grind profiles (everyone except GrindSword)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

LEADER = "GrindSword"
FOLLOW_KEYS = {
    "follow": "1",
    "followTarget": "Cedric",
    "followBot": "1",
    "followDistanceMin": "1",
    "followDistanceMax": "10",
    "followLostStep": "12",
    "lockMap": "",
    "route_randomWalk": "0",
    "attackAuto": "2",
    "attackAuto_inLockOnly": "0",
    "attackAuto_followTarget": "1",
    "attackAuto_party": "1",
    "sellAuto": "0",
    "teleportAuto_deadly": "0",
    "teleportAuto_maxDmg": "0",
    "teleportAuto_atkMiss": "0",
    "teleportAuto_useSkill": "0",
    "teleportAuto_dropTargetEngaged": "0",
    "grindPartyMode": "1",
    "grindPartyLeader": "Cedric",
}


def set_key(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)}\s+.*$", re.M)
    line = f"{key} {value}" if value != "" else key
    if pat.search(text):
        return pat.sub(line, text, count=1)
    return text + f"\n{line}\n"


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "openkore" / "profiles")
    n = 0
    for prof in sorted(root.iterdir()):
        if not prof.is_dir() or not prof.name.startswith("Grind"):
            continue
        if prof.name == LEADER:
            continue
        cfg_path = prof / "config.txt"
        if not cfg_path.exists():
            continue
        text = cfg_path.read_text()
        for k, v in FOLLOW_KEYS.items():
            text = set_key(text, k, v)
        cfg_path.write_text(text)
        print(f"follower-follow {prof.name}")
        n += 1
    print(f"Applied party-follow to {n} profiles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
