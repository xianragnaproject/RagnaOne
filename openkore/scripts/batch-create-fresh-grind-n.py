#!/usr/bin/env python3
"""Create N FreshGrind OpenKore accounts (solo shared pack) and register chars.

Keeps existing Grind* accounts. Creates additional thin profiles until TOTAL
FreshGrind bots exist (default 40), or create exactly --count new ones.

Hercules auto-register: first login as username_M / username_F.
On success, username is rewritten without the sex suffix.

Hair style (1-23) and hair color (0-8) are randomized per char.

Usage:
  python3 openkore/scripts/batch-create-fresh-grind-n.py [total=40]
  python3 openkore/scripts/batch-create-fresh-grind-n.py --count 10
  python3 openkore/scripts/batch-create-fresh-grind-n.py --retry-only
"""
from __future__ import annotations

import argparse
import os
import random
import re
import secrets
import subprocess
import time
from pathlib import Path

HOME = Path.home()
OK = HOME / "openkore"
PROFILES = OK / "profiles"
CREATE_EXP = OK / "scripts" / "create-char.exp"
ACCOUNT_MAP = PROFILES / "ACCOUNT_MAP.txt"
RESULTS = Path("/tmp/fresh-grind-n-results.txt")
PENDING = Path("/tmp/fresh-grind-n-pending.txt")
LIVE_PACK = OK / "fresh_grind" / "control"
WS_PACK = Path(__file__).resolve().parents[1] / "fresh_grind" / "control"

JOBS = ["Swordman", "Magician", "Archer", "Acolyte", "Merchant", "Thief"]

FIRST = [
    "Alden", "Bram", "Cass", "Dorian", "Ellis", "Felix", "Gareth", "Hugo",
    "Ivan", "Jonas", "Kurt", "Leif", "Milo", "Niall", "Owen", "Piers",
    "Quinn", "Rolf", "Seth", "Thane", "Ulric", "Vance", "Wade", "Xavier",
    "Yale", "Zane", "Aric", "Blake", "Cole", "Drake", "Erik", "Flint",
    "Gage", "Heath", "Igor", "Jace", "Kane", "Lars", "Mark", "Nash",
    "Orin", "Pike", "Reed", "Saul", "Tate", "Vern", "Wynn", "York",
    "Ava", "Brynn", "Cora", "Dana", "Elsa", "Faye", "Gwen", "Hana",
    "Iris", "Jade", "Kara", "Lena", "Mira", "Nora", "Opal", "Page",
    "Rhea", "Sage", "Tess", "Uma", "Vera", "Willa", "Yara", "Zara",
]
LAST = [
    "Ash", "Beck", "Croft", "Dale", "Edge", "Ford", "Gale", "Holt",
    "Ives", "Jay", "Kerr", "Lane", "Moss", "North", "Oak", "Park",
    "Quill", "Ridge", "Stone", "Thorn", "Under", "Vale", "West", "York",
    "Bramble", "Creek", "Flint", "Grove", "Harbor", "Marsh", "Pine", "Reed",
]


def set_key(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)}(?:\s+.*)?$", re.M)
    if pat.search(text):
        return pat.sub(f"{key} {value}", text, count=1)
    return text.rstrip() + f"\n{key} {value}\n"


def get_key(text: str, key: str) -> str | None:
    m = re.search(rf"^{re.escape(key)}\s+(.*)$", text, re.M)
    if not m:
        if re.search(rf"^{re.escape(key)}\s*$", text, re.M):
            return ""
        return None
    return m.group(1).strip()


def rand_user(used: set[str]) -> str:
    while True:
        u = "g" + secrets.token_hex(4)
        if u not in used and len(u) <= 23:
            return u


def rand_pass() -> str:
    return secrets.token_urlsafe(9)[:12]


def rand_char(used: set[str]) -> str:
    for _ in range(200):
        name = f"{random.choice(FIRST)}{random.choice(LAST)}"
        if len(name) > 23:
            name = name[:23]
        if name not in used:
            return name
    while True:
        name = "Bot" + secrets.token_hex(4)
        if name not in used:
            return name


def rand_look() -> tuple[int, int]:
    """Random hair style (1-23) and color (0-8)."""
    return random.randint(1, 23), random.randint(0, 8)


def load_map() -> tuple[set[str], set[str], set[str]]:
    users: set[str] = set()
    chars: set[str] = set()
    profiles: set[str] = set()
    if not ACCOUNT_MAP.exists():
        return users, chars, profiles
    for line in ACCOUNT_MAP.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 5:
            continue
        profiles.add(parts[1])
        chars.add(parts[2])
        users.add(parts[3].replace("_M", "").replace("_F", ""))
    return users, chars, profiles


def list_grind_profiles() -> list[Path]:
    if not PROFILES.exists():
        return []
    return sorted(
        p for p in PROFILES.iterdir() if p.is_dir() and p.name.startswith("Grind")
    )


def next_profile_names(need: int, existing: set[str]) -> list[str]:
    """Allocate Grind01.. skipping taken names."""
    names: list[str] = []
    n = 1
    while len(names) < need:
        cand = f"Grind{n:02d}"
        if cand not in existing and not (PROFILES / cand).exists():
            names.append(cand)
        n += 1
        if n > 999:
            raise SystemExit("Could not allocate profile names")
    return names


def ensure_pack() -> None:
    LIVE_PACK.mkdir(parents=True, exist_ok=True)
    src = WS_PACK if WS_PACK.is_dir() else LIVE_PACK
    if src.is_dir():
        for f in src.iterdir():
            if f.is_file():
                (LIVE_PACK / f.name).write_bytes(f.read_bytes())


def link_shared(prof: Path) -> None:
    for name in (
        "eventMacros.txt",
        "items_control.txt",
        "mon_control.txt",
        "pickupitems.txt",
        "routeweights.txt",
    ):
        dst = prof / name
        if dst.is_symlink() or dst.is_file():
            dst.unlink()


def write_thin(
    prof: Path,
    *,
    username: str,
    password: str,
    job: str,
    char_name: str,
    sex: str,
    hair_style: int = 1,
    hair_color: int = 1,
    fresh: bool = True,
) -> None:
    """Login-only config; shared pack + macros own behavior."""
    cfg_path = prof / "config.txt"
    lines = [
        "######## Account only — macros + shared control own everything else ########",
        "!include ../../control/config.txt",
        "!include ../../fresh_grind/control/config-shared.txt",
        f"username {username}",
        f"password {password}",
        "",
    ]
    cfg_path.write_text("\n".join(lines) + "\n")
    (prof / "class.meta").write_text(
        f"label={job}\nchar_name={char_name}\nsex={sex}\n"
        f"hair_style={hair_style}\nhair_color={hair_color}\n"
        f"account={username}\npack=fresh_grind\n"
    )
    link_shared(prof)


def create_char(
    profile: str,
    char_name: str,
    sex: str,
    hair_style: int = 1,
    hair_color: int = 1,
) -> tuple[int, str]:
    log = Path(f"/tmp/ok-create-{profile}.log")
    if log.exists():
        log.unlink()
    proc = subprocess.run(
        [
            "timeout",
            "75",
            "expect",
            str(CREATE_EXP),
            profile,
            char_name,
            sex,
            str(hair_style),
            str(hair_color),
        ],
        cwd=str(OK),
        capture_output=True,
        text=True,
        timeout=90,
        env=os.environ.copy(),
    )
    out = (proc.stdout or "") + "\n" + (proc.stderr or "")
    if log.exists():
        out += "\n" + log.read_text(errors="replace")[-5000:]
    return proc.returncode, out


def classify(rc: int, out: str) -> str:
    low = out.lower()
    if any(
        t in out
        for t in (
            "IN_GAME",
            "CREATE_OK",
            "DONE_SOFT",
            "DONE_EXISTING",
            "STATUS_OK",
            "SENT_CREATE",
            "SELECT_AFTER_CREATE",
            "ALREADY_HAS_TARGET",
        )
    ):
        return "OK" if rc in (0, 124) else "OK_SOFT"
    if (
        "SERVER_CLOSED" in out
        or "server is closed" in low
        or "denied your connection" in low
    ):
        return "SERVER_CLOSED"
    if "BAD_LOGIN" in out:
        return "BAD_LOGIN"
    if "BANNED" in out:
        return "BANNED"
    if "NAME_TAKEN" in out and ("CREATE_OK" in out or "IN_GAME" in out or "DONE" in out):
        return "OK_RENAMED"
    if rc == 0 and "DONE" in out:
        return "OK"
    return f"FAIL:{rc}"


def append_map(job: str, profile: str, char: str, user: str, passwd: str, sex: str) -> None:
    if not ACCOUNT_MAP.exists():
        ACCOUNT_MAP.write_text(
            "# profile_label\tProfileDir\tCharName\tusername\tpassword\tsex\n"
        )
    text = ACCOUNT_MAP.read_text()
    if re.search(rf"\t{re.escape(profile)}\t", text):
        return
    with ACCOUNT_MAP.open("a") as f:
        f.write(f"FreshGrind-{job}\t{profile}\t{char}\t{user}\t{passwd}\t{sex}\n")


def pending_rows() -> list[dict[str, str]]:
    rows = []
    if not PENDING.exists():
        return rows
    for line in PENDING.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) >= 6:
            row = {
                "profile": parts[0],
                "char": parts[1],
                "sex": parts[2],
                "user": parts[3],
                "pass": parts[4],
                "job": parts[5],
            }
            if len(parts) >= 8:
                row["hair_style"] = parts[6]
                row["hair_color"] = parts[7]
            rows.append(row)
    return rows


def write_pending(rows: list[dict[str, str]]) -> None:
    PENDING.write_text(
        "# profile\tchar\tsex\tuser\tpass\tjob\thair_style\thair_color\n"
        + "\n".join(
            f"{r['profile']}\t{r['char']}\t{r['sex']}\t{r['user']}\t{r['pass']}\t{r['job']}\t"
            f"{r.get('hair_style', '1')}\t{r.get('hair_color', '1')}"
            for r in rows
        )
        + ("\n" if rows else "")
    )


def attempt_register(row: dict[str, str]) -> str:
    """Login as user_SEX, create char, strip suffix on success."""
    profile = row["profile"]
    user = row["user"]
    passwd = row["pass"]
    sex = row["sex"]
    char = row["char"]
    job = row["job"]
    hair_style = int(row.get("hair_style") or 1)
    hair_color = int(row.get("hair_color") or 1)
    prof = PROFILES / profile
    login_user = f"{user}_{sex}"

    write_thin(
        prof,
        username=login_user,
        password=passwd,
        job=job,
        char_name=char,
        sex=sex,
        hair_style=hair_style,
        hair_color=hair_color,
        fresh=False,
    )
    print(
        f"=== CREATE {profile} job={job} user={login_user} char={char} "
        f"look=h{hair_style}/c{hair_color} ===",
        flush=True,
    )
    rc, out = create_char(profile, char, sex, hair_style, hair_color)
    status = classify(rc, out)
    print(f"  rc={rc} status={status}", flush=True)
    if status.startswith("OK"):
        write_thin(
            prof,
            username=user,
            password=passwd,
            job=job,
            char_name=char,
            sex=sex,
            hair_style=hair_style,
            hair_color=hair_color,
            fresh=False,
        )
        append_map(job, profile, char, user, passwd, sex)
    else:
        write_thin(
            prof,
            username=login_user,
            password=passwd,
            job=job,
            char_name=char,
            sex=sex,
            hair_style=hair_style,
            hair_color=hair_color,
            fresh=False,
        )
        if "SERVER_CLOSED" in status or status.startswith("FAIL"):
            print(out[-1200:], flush=True)
    return status


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "total",
        nargs="?",
        type=int,
        default=None,
        help="Target total Grind* profiles (default: current + --count or 40)",
    )
    ap.add_argument(
        "--count",
        type=int,
        default=None,
        help="Create this many NEW accounts",
    )
    ap.add_argument(
        "--retry-only",
        action="store_true",
        help="Only retry pending registrations",
    )
    args = ap.parse_args()

    if not CREATE_EXP.exists():
        raise SystemExit(f"Missing create-char.exp: {CREATE_EXP}")

    ensure_pack()
    used_users, used_chars, mapped_profiles = load_map()
    existing = list_grind_profiles()
    existing_names = {p.name for p in existing} | mapped_profiles

    results: list[str] = []
    pending = pending_rows()

    if args.retry_only:
        still = []
        for row in pending:
            status = attempt_register(row)
            results.append(
                f"{row['profile']}\t{row['job']}\t{status}\t{row['user']}\t{row['pass']}\t"
                f"{row['char']}\th{row.get('hair_style', '?')}/c{row.get('hair_color', '?')}"
            )
            if not status.startswith("OK"):
                still.append(row)
            time.sleep(3)
        write_pending(still)
        RESULTS.write_text(
            "profile\tjob\tstatus\tuser\tpass\tchar\tlook\n" + "\n".join(results) + "\n"
        )
        print(RESULTS.read_text())
        print(f"pending={len(still)} → {PENDING}")
        return 0

    have = len(existing)
    if args.count is not None:
        need = max(0, args.count)
        total = have + need
    elif args.total is not None:
        total = args.total
        need = max(0, total - have)
    else:
        total = 40
        need = max(0, total - have)
    print(f"Have {have} Grind profiles; creating {need} more to reach {total}", flush=True)

    new_names = next_profile_names(need, existing_names)
    job_cycle = ["random"] * need

    new_rows: list[dict[str, str]] = []
    for profile, job in zip(new_names, job_cycle):
        sex = random.choice(["M", "F"])
        user = rand_user(used_users)
        used_users.add(user)
        char = rand_char(used_chars)
        used_chars.add(char)
        passwd = rand_pass()
        hair_style, hair_color = rand_look()
        prof = PROFILES / profile
        prof.mkdir(parents=True, exist_ok=False)
        write_thin(
            prof,
            username=f"{user}_{sex}",
            password=passwd,
            job=job,
            char_name=char,
            sex=sex,
            hair_style=hair_style,
            hair_color=hair_color,
            fresh=True,
        )
        new_rows.append(
            {
                "profile": profile,
                "char": char,
                "sex": sex,
                "user": user,
                "pass": passwd,
                "job": job,
                "hair_style": str(hair_style),
                "hair_color": str(hair_color),
            }
        )
        print(
            f"prepared {profile} {job} {char} {user}_{sex} look=h{hair_style}/c{hair_color}",
            flush=True,
        )

    queue = pending + new_rows
    seen = set()
    deduped = []
    for r in queue:
        if r["profile"] in seen:
            continue
        seen.add(r["profile"])
        deduped.append(r)
    queue = deduped

    still: list[dict[str, str]] = []
    ok = fail = 0
    for i, row in enumerate(queue, 1):
        print(f"[{i}/{len(queue)}] registering {row['profile']}", flush=True)
        status = attempt_register(row)
        results.append(
            f"{row['profile']}\t{row['job']}\t{status}\t{row['user']}\t{row['pass']}\t"
            f"{row['char']}\th{row.get('hair_style', '?')}/c{row.get('hair_color', '?')}"
        )
        if status.startswith("OK"):
            ok += 1
        else:
            fail += 1
            still.append(row)
        time.sleep(3)

    write_pending(still)
    RESULTS.write_text(
        "profile\tjob\tstatus\tuser\tpass\tchar\tlook\n" + "\n".join(results) + "\n"
    )
    print(RESULTS.read_text())
    print(
        f"Done. ok={ok} fail={fail} grind_dirs={len(list_grind_profiles())} pending={len(still)}",
        flush=True,
    )
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
