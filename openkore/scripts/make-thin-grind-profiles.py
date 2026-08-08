#!/usr/bin/env python3
"""Build thin Grind profiles: login only + !include shared pack (solo, no party)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Fixed class targets for existing fleet accounts (still solo lockMap hunters)
JOB_BY_PROFILE = {
    "GrindSword": "Swordman",
    "GrindPrt08": "Thief",
    "GrindMage": "Magician",
    "GrindArcher": "Archer",
    "GrindAco": "Acolyte",
    "GrindMerch": "Merchant",
}

SOLO_KEYS = {
    "grindPartyMode": "0",
    "grindPartyRole": "solo",
    "follow": "0",
    "followTarget": "",
    "followBot": "0",
    "partyAuto": "0",
    "lockMap": "pay_fild03",
    "route_randomWalk": "1",
    "attackAuto_inLockOnly": "1",
    "attackAuto_followTarget": "0",
    "attackAuto_party": "0",
    "sellAuto": "1",
    "teleportAuto_deadly": "0",
}

SHARED_LINKS = (
    "eventMacros.txt",
    "items_control.txt",
    "mon_control.txt",
    "pickupitems.txt",
    "routeweights.txt",
)

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
        "######## Thin login profile — shared FreshGrind pack (SOLO) ########",
        "# Edit login here. Macros/combat: openkore/fresh_grind/control/",
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


def link_shared(prof: Path, pack_control: Path) -> None:
    for name in SHARED_LINKS:
        src = pack_control / name
        dst = prof / name
        if not src.exists():
            continue
        if dst.is_symlink() or dst.exists():
            dst.unlink()
        dst.symlink_to(Path("../../fresh_grind/control") / name)


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

        job = JOB_BY_PROFILE.get(prof.name, "random")
        existing_job = get_key(old, "grindTargetJob")
        if existing_job and existing_job.lower() == "random":
            job = "random"

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
        link_shared(prof, live_pack)
        print(f"thin  {prof.name} job={job} mode=solo")
        n += 1

    print(f"Made {n} thin solo Grind profiles -> {live_pack}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
