#!/usr/bin/env python3
"""Ensure Grind profiles are config.txt-only (shared files live in openkore/control/)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

SOLO_KEYS = {
    "grindPartyMode": "0",
    "grindPartyRole": "solo",
    "follow": "0",
    "followTarget": "",
    "followBot": "0",
    "partyAuto": "0",
    "lockMap": "prt_fild08",
    "route_randomWalk": "1",
    "attackAuto": "2",
    "attackAuto_followTarget": "0",
    "attackAuto_party": "0",
    "sellAuto": "1",
    "teleportAuto_deadly": "0",
}

# Only login-related files belong in the profile dir
KEEP = {"config.txt", "class.meta"}

PRESERVE_STATE = (
    "grindLeftTraining",
    "grindAfk",
    "grindSelling",
    "grindJobbing",
    "grindJob1st",
    "grindGearDone",
    "grindDone15",
    "grindDone25",
    "grindDone35",
    "grindBuyingArrows",
    "grindHuntMap",
)


def get_key(text: str, key: str) -> str | None:
    m = re.search(rf"^{re.escape(key)}\s+(.*)$", text, re.M)
    if not m:
        if re.search(rf"^{re.escape(key)}\s*$", text, re.M):
            return ""
        return None
    return m.group(1).strip()


def write_thin_config(
    path: Path,
    *,
    username: str,
    password: str,
    char: str,
    job: str,
    state: dict[str, str],
) -> None:
    lines = [
        "######## Account config only — shared files in openkore/control/ ########",
        "# Macros/items/monsters: control/  |  pack source: fresh_grind/control/",
        "# grindTargetJob: Swordman|Magician|Archer|Acolyte|Merchant|Thief|random",
        "!include ../../fresh_grind/control/config-shared.txt",
        "",
        f"username {username}",
        f"password {password}",
        f"char {char}",
        "",
        f"grindTargetJob {job}",
    ]
    for k, v in SOLO_KEYS.items():
        lines.append(f"{k} {v}" if v != "" else k)

    lines.append("")
    lines.append("# Runtime grind flags (preserved across sync)")
    for k in PRESERVE_STATE:
        if k in state and state[k] is not None:
            lines.append(f"{k} {state[k]}")

    path.write_text("\n".join(lines) + "\n")


def strip_profile_extras(prof: Path) -> None:
    for p in list(prof.iterdir()):
        if p.name in KEEP:
            continue
        if p.is_symlink() or p.is_file():
            p.unlink()
            print(f"  rm  {prof.name}/{p.name}")
        # leave unexpected subdirs alone


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

    # Install shared files into control/
    import subprocess

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
        char = get_key(old, "char") or "0"
        if user == "CHANGE_ME":
            raise SystemExit(f"REFUSING {prof.name}: no username")

        # Prefer existing job; default random for new/unknown
        job = get_key(old, "grindTargetJob") or "random"

        state = {}
        for k in PRESERVE_STATE:
            v = get_key(old, k)
            if v is not None:
                state[k] = v

        write_thin_config(
            cfg_path,
            username=user,
            password=passwd,
            char=char,
            job=job,
            state=state,
        )
        strip_profile_extras(prof)
        print(f"thin  {prof.name} job={job} (config.txt only)")
        n += 1

    print(f"Made {n} config-only Grind profiles; shared → {openkore / 'control'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
