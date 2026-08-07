#!/usr/bin/env python3
"""Create 5 fresh-grind OpenKore accounts (one per 1st job except Thief).

Clones the live GrindPrt08 profile, auto-registers via username_M login,
creates a novice char, sets grindTargetJob, and appends ACCOUNT_MAP.txt.

Usage:
  python3 openkore/scripts/batch-create-fresh-grind.py
"""
from __future__ import annotations

import os
import re
import secrets
import shutil
import string
import subprocess
import time
from pathlib import Path

HOME = Path.home()
OK = HOME / "openkore"
PROFILES = OK / "profiles"
SRC = PROFILES / "GrindPrt08"
CREATE_EXP = OK / "scripts" / "create-char.exp"
ACCOUNT_MAP = PROFILES / "ACCOUNT_MAP.txt"
RESULTS = Path("/tmp/fresh-grind-5class-results.txt")

ACCOUNTS = [
    ("GrindSword", "Swordman", "GrdSw"),
    ("GrindMage", "Magician", "GrdMg"),
    ("GrindArcher", "Archer", "GrdAr"),
    ("GrindAco", "Acolyte", "GrdAc"),
    ("GrindMerch", "Merchant", "GrdMe"),
]

RESET_FLAGS = {
    "grindLeftTraining": "0",
    "grindAfk": "0",
    "grindSelling": "0",
    "grindJobbing": "0",
    "grindJob1st": "0",
    "grindGearDone": "0",
    "grindDone15": "0",
    "grindDone25": "0",
    "attackAuto": "2",
    "route_randomWalk": "1",
    "lockMap": "prt_fild08",
    "itemsMaxWeight_sellOrStore": "40",
    "aiChat": "0",
}


def rand_alnum(n: int) -> str:
    alphabet = string.ascii_lowercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(n))


def set_key(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)}(?:\s+.*)?$", re.M)
    if pat.search(text):
        return pat.sub(f"{key} {value}", text, count=1)
    return text + f"\n{key} {value}\n"


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing template profile: {SRC}")
    if not CREATE_EXP.exists():
        raise SystemExit(f"Missing create-char.exp: {CREATE_EXP}")

    used_users: set[str] = set()
    used_chars: set[str] = set()
    if ACCOUNT_MAP.exists():
        for line in ACCOUNT_MAP.read_text().splitlines():
            parts = line.split("\t")
            if len(parts) >= 5:
                used_chars.add(parts[2])
                used_users.add(parts[3].replace("_M", "").replace("_F", ""))

    rows = []
    for profile, job, prefix in ACCOUNTS:
        if (PROFILES / profile).exists():
            print(f"SKIP exists {profile}")
            rows.append((profile, job, "EXISTS", "", "", ""))
            continue

        while True:
            user = f"g{job[:3].lower()}{rand_alnum(6)}"
            if user not in used_users:
                used_users.add(user)
                break
        while True:
            char = f"{prefix}{rand_alnum(4)}"
            if char not in used_chars and len(char) <= 23:
                used_chars.add(char)
                break
        passwd = secrets.token_urlsafe(9)[:12]
        sex = "M"
        login_user = f"{user}_{sex}"

        dst = PROFILES / profile
        dst.mkdir(parents=True)
        for f in (
            "config.txt",
            "eventMacros.txt",
            "items_control.txt",
            "mon_control.txt",
            "pickupitems.txt",
        ):
            shutil.copy2(SRC / f, dst / f)

        cfg = (dst / "config.txt").read_text()
        cfg = set_key(cfg, "username", login_user)
        cfg = set_key(cfg, "password", passwd)
        cfg = set_key(cfg, "master", "RagnaOne")
        cfg = set_key(cfg, "char", "0")
        cfg = set_key(cfg, "server", "0")
        cfg = set_key(cfg, "grindTargetJob", job)
        for k, v in RESET_FLAGS.items():
            cfg = set_key(cfg, k, v)
        (dst / "config.txt").write_text(cfg)
        (dst / "class.meta").write_text(
            f"label={job}\nchar_name={char}\nsex={sex}\naccount={login_user}\npack=fresh_grind\n"
        )

        print(f"=== CREATE {profile} job={job} user={login_user} char={char} ===", flush=True)
        log = Path(f"/tmp/ok-create-{profile}.log")
        if log.exists():
            log.unlink()
        proc = subprocess.run(
            ["expect", str(CREATE_EXP), profile, char, sex],
            cwd=str(OK),
            capture_output=True,
            text=True,
            timeout=300,
            env=os.environ.copy(),
        )
        out = (proc.stdout or "") + "\n" + (proc.stderr or "")
        if log.exists():
            out += "\n" + log.read_text(errors="replace")[-3000:]
        ok = proc.returncode == 0 and any(
            t in out for t in ("IN_GAME", "CREATE_OK", "DONE", "STATUS_OK")
        )
        print(f"rc={proc.returncode} ok={ok}", flush=True)

        cfg = (dst / "config.txt").read_text()
        cfg = set_key(cfg, "username", user)
        cfg = set_key(cfg, "grindTargetJob", job)
        for k, v in RESET_FLAGS.items():
            cfg = set_key(cfg, k, v)
        (dst / "config.txt").write_text(cfg)

        with ACCOUNT_MAP.open("a") as f:
            f.write(f"FreshGrind-{job}\t{profile}\t{char}\t{user}\t{passwd}\t{sex}\n")
        rows.append((profile, job, "OK" if ok else f"FAIL:{proc.returncode}", user, passwd, char))
        time.sleep(2)

    RESULTS.write_text(
        "profile\tjob\tstatus\tuser\tpass\tchar\n"
        + "\n".join("\t".join(r) for r in rows)
        + "\n"
    )
    print(RESULTS.read_text())


if __name__ == "__main__":
    main()
