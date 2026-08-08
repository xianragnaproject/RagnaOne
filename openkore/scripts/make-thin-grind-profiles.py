#!/usr/bin/env python3
"""Build thin Grind profiles: login/role only + !include shared pack.

Shared pack: openkore/fresh_grind/control/
  - config-shared.txt   (combat, buy/equip, all class skills disabled by default)
  - eventMacros.txt     (job-gated macros)
  - items/mon/pickup/routeweights

Each profiles/Grind*/config.txt becomes:
  !include ../../fresh_grind/control/config-shared.txt
  username / password / char
  grindTargetJob (fixed party role OR 'random')
  grindPartyRole leader|follower
  follow / lockMap overrides

Other control files are symlinked to the shared pack so one edit updates all accounts.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

PARTY = {
    "GrindSword": {
        "grindTargetJob": "Swordman",
        "grindPartyRole": "leader",
        "follow": "0",
        "followTarget": "",
        "lockMap": "pay_fild03",
        "route_randomWalk": "1",
        "attackAuto_inLockOnly": "1",
        "attackAuto_followTarget": "0",
        "sellAuto": "1",
    },
    "GrindPrt08": {"grindTargetJob": "Thief", "grindPartyRole": "follower"},
    "GrindMage": {"grindTargetJob": "Magician", "grindPartyRole": "follower"},
    "GrindArcher": {"grindTargetJob": "Archer", "grindPartyRole": "follower"},
    "GrindAco": {"grindTargetJob": "Acolyte", "grindPartyRole": "follower"},
    "GrindMerch": {"grindTargetJob": "Merchant", "grindPartyRole": "follower"},
}

FOLLOWER_DEFAULTS = {
    "grindPartyRole": "follower",
    "follow": "1",
    "followTarget": "Cedric",
    "followBot": "0",
    "lockMap": "",
    "route_randomWalk": "0",
    "attackAuto_inLockOnly": "0",
    "attackAuto_followTarget": "1",
    "sellAuto": "0",
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
        # bare key with empty value
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
    role: dict[str, str],
    state: dict[str, str],
) -> None:
    lines = [
        "######## Thin login profile — shared FreshGrind pack ########",
        "# Edit login here (or ACCOUNT_MAP + sync). Macros/combat live in:",
        "#   openkore/fresh_grind/control/",
        "# grindTargetJob: Swordman|Magician|Archer|Acolyte|Merchant|Thief|random",
        "# grindPartyRole: leader|follower",
        "!include ../../fresh_grind/control/config-shared.txt",
        "",
        f"username {username}",
        f"password {password}",
        f"char {char}",
        "",
    ]
    for k in (
        "grindTargetJob",
        "grindPartyRole",
        "follow",
        "followTarget",
        "followBot",
        "lockMap",
        "route_randomWalk",
        "attackAuto_inLockOnly",
        "attackAuto_followTarget",
        "sellAuto",
        "teleportAuto_deadly",
    ):
        if k not in role:
            continue
        v = role[k]
        lines.append(f"{k} {v}" if v != "" else k)

    lines.append("")
    lines.append("# Runtime grind flags (preserved across sync)")
    for k in PRESERVE_STATE:
        if k in state and state[k] is not None:
            lines.append(f"{k} {state[k]}")

    lines.append("")
    lines.append("grindPartyMode 1")
    lines.append("grindPartyLeader Cedric")
    path.write_text("\n".join(lines) + "\n")


def link_shared(prof: Path, pack_control: Path) -> None:
    for name in SHARED_LINKS:
        src = pack_control / name
        dst = prof / name
        if not src.exists():
            continue
        if dst.is_symlink() or dst.exists():
            dst.unlink()
        # Relative symlink from profiles/GrindX/ -> ../../fresh_grind/control/file
        rel = Path("../../fresh_grind/control") / name
        dst.symlink_to(rel)


def main() -> int:
    openkore = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "openkore")
    workspace_pack = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    profiles = openkore / "profiles"
    live_pack = openkore / "fresh_grind" / "control"

    if workspace_pack and workspace_pack.is_dir():
        live_pack.parent.mkdir(parents=True, exist_ok=True)
        live_pack.mkdir(parents=True, exist_ok=True)
        for f in workspace_pack.iterdir():
            if f.is_file():
                target = live_pack / f.name
                target.write_bytes(f.read_bytes())
                print(f"pack  {f.name}")

    if not live_pack.is_dir():
        raise SystemExit(f"missing shared pack: {live_pack}")

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

        role = dict(FOLLOWER_DEFAULTS)
        role.update(PARTY.get(prof.name, {"grindTargetJob": "random", "grindPartyRole": "follower"}))
        # Preserve intentional grindTargetJob if already random
        existing_job = get_key(old, "grindTargetJob")
        if existing_job and existing_job.lower() == "random":
            role["grindTargetJob"] = "random"

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
            role=role,
            state=state,
        )
        link_shared(prof, live_pack)
        print(f"thin  {prof.name} job={role['grindTargetJob']} role={role['grindPartyRole']}")
        n += 1

    print(f"Made {n} thin Grind profiles -> {live_pack}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
