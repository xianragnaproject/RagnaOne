#!/usr/bin/env python3
"""Force all Grind profiles to solo hunt (no party follow)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

SOLO = {
    "follow": "0",
    "followTarget": "",
    "followBot": "0",
    "grindPartyMode": "0",
    "partyAuto": "0",
    "partyAutoShare": "0",
    "attackAuto": "2",
    "attackAuto_inLockOnly": "1",
    "attackAuto_followTarget": "0",
    "attackAuto_party": "0",
    "route_randomWalk": "1",
    "sellAuto": "1",
}


def set_key(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)}\s*.*$", re.M)
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
        cfg = prof / "config.txt"
        if not cfg.exists():
            continue
        text = cfg.read_text()
        for k, v in SOLO.items():
            text = set_key(text, k, v)
        # Ensure lockMap for paid hunt if already past 25 flags
        if re.search(r"^grindDone25\s+1\b", text, re.M) or re.search(
            r"^grindHuntMap\s+pay_fild03\b", text, re.M
        ):
            text = set_key(text, "lockMap", "pay_fild03")
            text = set_key(text, "grindHuntMap", "pay_fild03")
        cfg.write_text(text)
        print(f"solo {prof.name}")
        n += 1
    print(f"Applied solo hunt to {n} profiles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
