#!/usr/bin/env python3
"""
Create N bot accounts with AssassinClean-style settings and random 2-1 job classes.

Steps:
  1) Pick random class per slot
  2) Generate username/password/char/sex
  3) Write OpenKore profile from {class}_clean pack (username = user_SEX for Hercules auto-create)
  4) Run create-char.exp
  5) Rewrite username without _M/_F suffix
  6) Append ACCOUNT_MAP.txt

Usage:
  python3 openkore/scripts/batch-create-clean-accounts.py [count=40]
"""
from __future__ import annotations

import os
import random
import re
import secrets
import shutil
import string
import subprocess
import sys
import time
from pathlib import Path

COUNT = int(sys.argv[1]) if len(sys.argv) > 1 else 40
HOME = Path.home()
OK = HOME / "openkore"
PROFILES = OK / "profiles"
PACKS = Path("/workspace/openkore")
CREATE_EXP = OK / "scripts" / "create-char.exp"
ACCOUNT_MAP = PROFILES / "ACCOUNT_MAP.txt"
BATCH_TSV = Path("/tmp/batch4-clean-create.txt")
RESULTS = Path("/tmp/batch4-clean-results.txt")

CLASSES = [
    ("Assassin", "assassin_clean", "Assassin"),
    ("Knight", "knight_clean", "Knight"),
    ("Wizard", "wizard_clean", "Wizard"),
    ("Hunter", "hunter_clean", "Hunter"),
    ("Priest", "priest_clean", "Priest"),
    ("Blacksmith", "blacksmith_clean", "Blacksmith"),
]

PREFIX = {
    "Assassin": "As",
    "Knight": "Kn",
    "Wizard": "Wz",
    "Hunter": "Hu",
    "Priest": "Pr",
    "Blacksmith": "Bs",
}


def rand_alnum(n: int) -> str:
    alphabet = string.ascii_lowercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(n))


def next_profile_num(label: str) -> int:
    """Next free N for {Label}Clean{N} (AssassinClean has no number → treat as 1 taken conceptually)."""
    taken = set()
    for p in PROFILES.iterdir():
        if not p.is_dir():
            continue
        name = p.name
        if label == "Assassin" and name == "AssassinClean":
            taken.add(1)
            continue
        m = re.fullmatch(rf"{re.escape(label)}Clean(\d+)", name)
        if m:
            taken.add(int(m.group(1)))
        # also avoid colliding with non-clean fleet numbers when using Label+N? we use LabelCleanN
    n = 2 if label == "Assassin" else 1
    while n in taken:
        n += 1
    return n


def set_key(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)}(?:\s+.*)?$", re.M)
    if pat.search(text):
        return pat.sub(f"{key} {value}", text, count=1)
    return text + f"\n{key} {value}\n"


def get_key(text: str, key: str) -> str | None:
    m = re.search(rf"^{re.escape(key)}\s+(.*)$", text, re.M)
    return m.group(1).strip() if m else None


def make_profile(label: str, pack: str, profile: str, user: str, passwd: str, sex: str) -> Path:
    src = PACKS / pack / "control"
    dst = PROFILES / profile
    if dst.exists():
        raise SystemExit(f"Profile exists: {dst}")
    dst.mkdir(parents=True)
    for f in ("config.txt", "eventMacros.txt", "items_control.txt", "mon_control.txt"):
        shutil.copy2(src / f, dst / f)
    cfg = (dst / "config.txt").read_text()
    # Hercules auto-create: login as user_M / user_F once
    login_user = f"{user}_{sex}"
    cfg = set_key(cfg, "username", login_user)
    cfg = set_key(cfg, "password", passwd)
    cfg = set_key(cfg, "master", "RagnaOne")
    cfg = set_key(cfg, "char", "0")
    # Reset progression flags for fresh novices
    for k in (
        "ragnaSaveProntera",
        "ragnaJobThief",
        "ragnaJob1st",
        "ragnaThiefGear",
        "ragnaSavePayon",
        "ragnaShopsPayon",
        "ragnaFieldScoutOff",
    ):
        if get_key(cfg, k) is not None:
            cfg = set_key(cfg, k, "0")
    cfg = set_key(cfg, "ragnaShop", "1")
    cfg = set_key(cfg, "lockMap", "prt_fild08")
    (dst / "config.txt").write_text(cfg)
    (dst / "class.meta").write_text(
        f"label={label}\nchar_name=\nsex={sex}\naccount={login_user}\nsecond={label}\npack={pack}\n"
    )
    return dst


def finalize_username(profile: str, user: str, char_name: str, sex: str, label: str, pack: str):
    cfg_path = PROFILES / profile / "config.txt"
    cfg = cfg_path.read_text()
    cfg = set_key(cfg, "username", user)
    cfg_path.write_text(cfg)
    (PROFILES / profile / "class.meta").write_text(
        f"label={label}\nchar_name={char_name}\nsex={sex}\naccount={user}_{sex}\nsecond={label}\npack={pack}\n"
    )


def create_char(profile: str, char_name: str, sex: str) -> tuple[int, str]:
    log = Path(f"/tmp/ok-create-{profile}.log")
    if log.exists():
        log.unlink()
    env = os.environ.copy()
    proc = subprocess.run(
        ["expect", str(CREATE_EXP), profile, char_name, sex],
        cwd=str(OK),
        capture_output=True,
        text=True,
        timeout=240,
        env=env,
    )
    out = (proc.stdout or "") + "\n" + (proc.stderr or "")
    if log.exists():
        out += "\n" + log.read_text(errors="replace")[-4000:]
    return proc.returncode, out


def append_account_map(label: str, profile: str, char: str, user: str, passwd: str, sex: str):
    line = f"{label}\t{profile}\t{char}\t{user}\t{passwd}\t{sex}\n"
    with ACCOUNT_MAP.open("a") as f:
        f.write(line)


def main():
    random.seed()
    # Even-ish random distribution
    picks = [CLASSES[i % len(CLASSES)] for i in range(COUNT)]
    random.shuffle(picks)

    rows = []
    used_users = set()
    used_chars = set()
    # load existing users/chars
    if ACCOUNT_MAP.exists():
        for line in ACCOUNT_MAP.read_text().splitlines():
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) >= 5:
                used_chars.add(parts[2])
                # user field position varies
                for p in parts[3:]:
                    if p not in ("M", "F") and len(p) >= 4:
                        used_users.add(p.replace("_M", "").replace("_F", ""))

    print(f"Creating {COUNT} accounts → {BATCH_TSV}")
    taken_nums = {label: set() for label, _, _ in CLASSES}
    for p in PROFILES.iterdir():
        if not p.is_dir():
            continue
        for label, _, _ in CLASSES:
            if label == "Assassin" and p.name == "AssassinClean":
                taken_nums[label].add(1)
            m = re.fullmatch(rf"{re.escape(label)}Clean(\d+)", p.name)
            if m:
                taken_nums[label].add(int(m.group(1)))

    def alloc_num(label: str) -> int:
        n = 2 if label == "Assassin" else 1
        while n in taken_nums[label]:
            n += 1
        taken_nums[label].add(n)
        return n

    for label, pack, second in picks:
        n = alloc_num(label)
        profile = f"{label}Clean{n}"

        sex = random.choice(["M", "F"])
        user = rand_alnum(random.randint(8, 11))
        while user in used_users:
            user = rand_alnum(random.randint(8, 11))
        used_users.add(user)
        passwd = rand_alnum(random.randint(10, 12))
        char = f"{PREFIX[label]}{n}{rand_alnum(4)}"
        while char in used_chars or len(char) > 23:
            char = f"{PREFIX[label]}{n}{rand_alnum(4)}"
        used_chars.add(char)

        rows.append((label, pack, second, profile, char, sex, user, passwd))

    BATCH_TSV.write_text(
        "\n".join(
            f"{profile}\t{char}\t{sex}\t{user}\t{passwd}\t{label}\t{pack}"
            for label, pack, second, profile, char, sex, user, passwd in rows
        )
        + "\n"
    )

    RESULTS.write_text("")
    ok = fail = 0
    with ACCOUNT_MAP.open("a") as am:
        am.write(f"\n# Auto-created via Hercules _M/_F (batch 4 clean ×{COUNT})\n")

    for i, (label, pack, second, profile, char, sex, user, passwd) in enumerate(rows, 1):
        print(f"[{i}/{COUNT}] {profile} {label} {char} {sex} {user}")
        try:
            make_profile(label, pack, profile, user, passwd, sex)
            rc, out = create_char(profile, char, sex)
            finalize_username(profile, user, char, sex, label, pack)
            append_account_map(label, profile, char, user, passwd, sex)
            status = "OK" if rc == 0 and ("DONE" in out or "IN_GAME" in out or "STATUS_OK" in out) else f"RC={rc}"
            if "BAD_LOGIN" in out or "LOGIN_FAIL" in out:
                status = "BAD_LOGIN"
            if rc == 0 and "DONE" in out:
                ok += 1
            else:
                # soft-ok if char was created
                if "CREATE_OK" in out or "IN_GAME" in out or "DONE_EXISTING" in out:
                    ok += 1
                    status = "OK_SOFT"
                else:
                    fail += 1
            with RESULTS.open("a") as rf:
                rf.write(f"{profile}\t{status}\t{char}\t{user}\t{passwd}\t{sex}\t{label}\n")
            print(f"  → {status}")
        except Exception as e:
            fail += 1
            with RESULTS.open("a") as rf:
                rf.write(f"{profile}\tEXC\t{e}\n")
            print(f"  → EXC {e}")
        time.sleep(1.5)

    print(f"Done. ok={ok} fail={fail} map={ACCOUNT_MAP} results={RESULTS}")


if __name__ == "__main__":
    main()
