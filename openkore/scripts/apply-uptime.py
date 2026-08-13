#!/usr/bin/env python3
"""Ensure grind profiles stay auto-login capable (char slot + never DC forever)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

KEYS = {
    "char": "0",
    "dcOnDeath": "0",
    "dcOnDisconnect": "0",
    "dcOnDualLogin": "0",
    "dcOnMaxReconnections": "0",
    "dcOnServerShutDown": "0",
    "dcOnServerClose": "0",
    "dcOnStorageFull": "0",
}


def set_key(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)}\s+.*$", re.M)
    line = f"{key} {value}"
    if pat.search(text):
        return pat.sub(line, text, count=1)
    # Prefer near username if present
    if re.search(r"^username\s+", text, re.M):
        return re.sub(r"^(username\s+.*)$", rf"\1\n{line}", text, count=1, flags=re.M)
    return text + f"\n{line}\n"


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "openkore" / "profiles")
    n = 0
    for prof in sorted(root.iterdir()):
        if not prof.is_dir():
            continue
        if not (prof.name.startswith("Grind") or prof.name in ("FreshGrind", "ChatIdle")):
            continue
        cfg_path = prof / "config.txt"
        if not cfg_path.exists():
            continue
        text = cfg_path.read_text()
        for k, v in KEYS.items():
            text = set_key(text, k, v)
        cfg_path.write_text(text)
        print(f"uptime {prof.name}")
        n += 1
    print(f"Applied uptime keys to {n} profiles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
