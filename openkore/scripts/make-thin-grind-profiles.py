#!/usr/bin/env python3
"""Ensure Grind profiles are login-only config.txt (shared control/ + macros)."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

KEEP = {"config.txt", "class.meta"}


def get_key(text: str, key: str) -> str | None:
    m = re.search(rf"^{re.escape(key)}\s+(.*)$", text, re.M)
    if not m:
        if re.search(rf"^{re.escape(key)}\s*$", text, re.M):
            return ""
        return None
    return m.group(1).strip()


def write_login_only(path: Path, username: str, password: str) -> None:
    path.write_text(
        "\n".join(
            [
                "######## Account only — macros + shared control own everything else ########",
                # profiles/ plugin loads THIS file instead of control/config.txt —
                # include the full base first or defaults (clientSight, etc.) are missing.
                "!include ../../control/config.txt",
                "!include ../../fresh_grind/control/config-shared.txt",
                f"username {username}",
                f"password {password}",
                "",
            ]
        )
    )


def strip_extras(prof: Path) -> None:
    for p in list(prof.iterdir()):
        if p.name in KEEP:
            continue
        if p.is_symlink() or p.is_file():
            p.unlink()
            print(f"  rm  {prof.name}/{p.name}")


def main() -> int:
    openkore = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "openkore")
    workspace_pack = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    profiles = openkore / "profiles"
    live_pack = openkore / "fresh_grind" / "control"

    if workspace_pack and workspace_pack.is_dir():
        live_pack.mkdir(parents=True, exist_ok=True)
        for f in workspace_pack.iterdir():
            if f.is_file():
                (live_pack / f.name).write_bytes(f.read_bytes())
                print(f"pack  {f.name}")

    install = Path(__file__).resolve().parent / "install-shared-control.sh"
    if install.exists():
        subprocess.run(["bash", str(install), str(live_pack)], check=False)

    n = 0
    for prof in sorted(profiles.iterdir()):
        if not prof.is_dir() or not prof.name.startswith("Grind"):
            continue
        cfg_path = prof / "config.txt"
        old = cfg_path.read_text() if cfg_path.exists() else ""
        user = get_key(old, "username") or "CHANGE_ME"
        passwd = get_key(old, "password") or "CHANGE_ME"
        if user == "CHANGE_ME":
            raise SystemExit(f"REFUSING {prof.name}: no username")
        write_login_only(cfg_path, user, passwd)
        strip_extras(prof)
        print(f"login {prof.name} user={user}")
        n += 1

    print(f"Made {n} login-only profiles; behavior → control/ + macros")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
