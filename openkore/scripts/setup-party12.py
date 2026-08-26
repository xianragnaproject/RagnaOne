#!/usr/bin/env python3
"""Create 12 party bots: 2 per class, per-class config packs, follow/assist leader.

Classes: Swordman, Magician, Archer, Acolyte, Merchant, Thief (2 each).
Leader = first Swordman. Members follow + assist only.
Job change at JobLevel 10 via shared eventMacros + grindTargetJob.
Sell on overweight + equip loot via shared pack. Target base 99 on prt_fild08.
"""
from __future__ import annotations

import os
import random
import re
import secrets
import subprocess
import time
from pathlib import Path

OK = Path(os.environ.get("OPENKORE_HOME", Path.home() / "openkore")).resolve()
PROFILES = OK / "profiles"
CLASS_PACKS = OK / "class_packs"
CREATE_EXP = OK / "scripts" / "create-char.exp"
ACCOUNT_MAP = PROFILES / "PARTY12_MAP.txt"
PENDING = Path("/tmp/party12-pending.txt")
RESULTS = Path("/tmp/party12-results.txt")

CLASSES = [
    "Swordman",
    "Magician",
    "Archer",
    "Acolyte",
    "Merchant",
    "Thief",
]

# profile, class, is_leader
ROSTER = [
    ("PSwdLead", "Swordman", True),
    ("PSwd2", "Swordman", False),
    ("PMag1", "Magician", False),
    ("PMag2", "Magician", False),
    ("PArc1", "Archer", False),
    ("PArc2", "Archer", False),
    ("PAco1", "Acolyte", False),
    ("PAco2", "Acolyte", False),
    ("PMer1", "Merchant", False),
    ("PMer2", "Merchant", False),
    ("PThf1", "Thief", False),
    ("PThf2", "Thief", False),
]

FIRST = [
    "Alden", "Bram", "Cass", "Dorian", "Ellis", "Felix", "Gareth", "Hugo",
    "Ivan", "Jonas", "Kurt", "Leif", "Milo", "Niall", "Owen", "Piers",
    "Ava", "Brynn", "Cora", "Dana", "Elsa", "Faye", "Gwen", "Hana",
]
LAST = [
    "Ash", "Beck", "Croft", "Dale", "Edge", "Ford", "Gale", "Holt",
    "Ives", "Jay", "Kerr", "Lane", "Moss", "North", "Oak", "Park",
]

CLASS_SKILLS = {
    "Swordman": (
        "Basic Skill 9, Sword Mastery 10, Bash 10, Magnum Break 10, "
        "Provoke 5, Endure 5, Increase HP Recovery 5"
    ),
    "Magician": (
        "Basic Skill 9, Increase SP Recovery 8, Sight 1, Fire Bolt 10, "
        "Cold Bolt 5, Lightning Bolt 5, Napalm Beat 5"
    ),
    "Archer": (
        "Basic Skill 9, Owl's Eye 10, Vulture's Eye 10, Double Strafe 10, "
        "Improve Concentration 5, Arrow Shower 10"
    ),
    "Acolyte": (
        "Basic Skill 9, Heal 10, Increase Healing 5, Blessing 10, "
        "Increase AGI 10, Angelus 5, Ruwach 1, Teleport 2, Warp Portal 1"
    ),
    "Merchant": (
        "Basic Skill 9, Enlarge Weight Limit 10, Discount 10, Overcharge 10, "
        "Pushcart 10, Vending 1, Mammonite 10, Item Appraisal 1"
    ),
    "Thief": (
        "Basic Skill 9, Double Attack 10, Improve Dodge 10, Steal 10, "
        "Hiding 10, Envenom 10, Detoxify 1"
    ),
}

CLASS_DIST = {
    "Swordman": "1",
    "Magician": "9",
    "Archer": "9",
    "Acolyte": "2",
    "Merchant": "1",
    "Thief": "1",
}


def write_class_packs() -> None:
    CLASS_PACKS.mkdir(parents=True, exist_ok=True)
    for cls in CLASSES:
        d = CLASS_PACKS / cls
        d.mkdir(parents=True, exist_ok=True)
        dist = CLASS_DIST[cls]
        skills = CLASS_SKILLS[cls]
        parts = [
            f"######## Class pack: {cls} ########",
            f"grindTargetJob {cls}",
            "skillsAddAuto 1",
            f"skillsAddAuto_list {skills}",
            f"attackDistance {dist}",
            f"attackMaxDistance {dist}",
            "attackDistanceAuto 0",
            "",
        ]
        if cls == "Magician":
            parts += [
                "attackSkillSlot Fire Bolt {",
                "\tlvl 10",
                "\tdist 9",
                "\tmaxDist 9",
                "\tsp > 8",
                "\tnotInTown 1",
                "\ttimeout 1",
                "}",
                "",
            ]
        elif cls == "Archer":
            parts += [
                "attackSkillSlot Double Strafe {",
                "\tlvl 10",
                "\tdist 9",
                "\tmaxDist 9",
                "\tsp > 8",
                "\tnotInTown 1",
                "\ttimeout 1",
                "}",
                "",
            ]
        elif cls == "Swordman":
            parts += [
                "attackSkillSlot Bash {",
                "\tlvl 10",
                "\tdist 1",
                "\tmaxDist 2",
                "\tsp > 5",
                "\tnotInTown 1",
                "\ttimeout 1",
                "}",
                "",
            ]
        elif cls == "Acolyte":
            parts += [
                "useSelf_skill Heal {",
                "\tlvl 10",
                "\thp < 60%",
                "\tsp > 10",
                "\ttimeout 1",
                "}",
                "partySkill Blessing {",
                "\tlvl 5",
                "\ttarget_whenStatusInactive Blessing",
                "\tsp > 20",
                "\tnotInTown 1",
                "\ttimeout 8",
                "}",
                "partySkill Increase AGI {",
                "\tlvl 5",
                "\ttarget_whenStatusInactive Increase AGI",
                "\tsp > 20",
                "\tnotInTown 1",
                "\ttimeout 8",
                "}",
                "",
            ]
        elif cls == "Merchant":
            parts += [
                "attackSkillSlot Mammonite {",
                "\tlvl 10",
                "\tdist 1",
                "\tmaxDist 2",
                "\tsp > 8",
                "\tnotInTown 1",
                "\ttimeout 2",
                "}",
                "",
            ]
        elif cls == "Thief":
            parts += [
                "attackSkillSlot Envenom {",
                "\tlvl 5",
                "\tdist 1",
                "\tmaxDist 2",
                "\tsp > 8",
                "\tnotInTown 1",
                "\ttimeout 2",
                "}",
                "",
            ]
        (d / "config-class.txt").write_text("\n".join(parts) + "\n")
        (d / "README.md").write_text(
            f"# {cls}\n\nPer-class OpenKore pack. Party profiles `!include` this file.\n"
        )
        print(f"class_pack {cls}")


def rand_user(used: set[str]) -> str:
    while True:
        u = "p" + secrets.token_hex(4)
        if u not in used:
            return u


def rand_pass() -> str:
    return secrets.token_urlsafe(9)[:12]


def rand_char(used: set[str], tag: str) -> str:
    for _ in range(200):
        name = f"{random.choice(FIRST)}{random.choice(LAST)}{tag}"
        if len(name) > 23:
            name = name[:23]
        if name not in used:
            return name
    return ("Bot" + secrets.token_hex(4))[:23]


def write_profile(
    profile: str,
    *,
    username: str,
    password: str,
    job: str,
    char_name: str,
    sex: str,
    is_leader: bool,
    leader_char: str,
) -> None:
    prof = PROFILES / profile
    prof.mkdir(parents=True, exist_ok=True)
    role = "LEADER" if is_leader else "MEMBER"
    lines = [
        f"######## Party12 {role} — {job} / {char_name} ########",
        "!include ../../control/config.txt",
        "!include ../../fresh_grind/control/config-shared.txt",
        f"!include ../../class_packs/{job}/config-class.txt",
        f"username {username}",
        f"password {password}",
        "char 0",
        "",
        f"grindTargetJob {job}",
        "grindKeepHunting 1",
        "grindAfk 0",
        "grindPhase2 0",
        "grindP2Gear 0",
        "dcOnLevel 99",
        "itemsMaxWeight 89",
        "itemsMaxWeight_sellOrStore 50",
        "",
    ]
    if is_leader:
        lines += [
            "######## LEADER ########",
            "follow 0",
            "partyAuto 1",
            "partyAutoShare 1",
            "partyAutoShareItem 1",
            "attackAuto 2",
            "attackAuto_party 1",
            "route_randomWalk 1",
            "route_randomWalk_inLockOnly 1",
            "lockMap prt_fild08",
            "grindHuntMap prt_fild08",
            "teleportAuto_idle 0",
            "sitAuto_idle 0",
            "partyRole leader",
            f"partyLeaderName {char_name}",
        ]
    else:
        lines += [
            "######## MEMBER HARD follow+assist (attackAuto 1) ########",
            "follow 1",
            f"followTarget {leader_char}",
            "followBot 1",
            "followDistanceMax 4",
            "followDistanceMin 1",
            "partyAuto 2",
            "attackAuto 1",
            "attackAuto_party 1",
            "attackAuto_followTarget 1",
            "attackChangeTarget 1",
            "route_randomWalk 0",
            "itemsGatherAuto 2",
            "itemsTakeAuto 2",
            "itemsTakeAuto_party 1",
            "itemsMaxWeight 89",
            "itemsMaxWeight_sellOrStore 50",
            "lockMap",
            "teleportAuto_idle 0",
            "sitAuto_idle 0",
            "partyRole member",
            f"partyLeaderName {leader_char}",
        ]
    (prof / "config.txt").write_text("\n".join(lines) + "\n")
    (prof / "class.meta").write_text(
        f"label={job}\nchar_name={char_name}\nsex={sex}\n"
        f"account={username}\nrole={'leader' if is_leader else 'member'}\n"
        f"leader={leader_char}\npack=party12\n"
    )


def create_char(profile: str, char_name: str, sex: str, hs: int, hc: int) -> tuple[int, str]:
    log = Path(f"/tmp/ok-create-{profile}.log")
    if log.exists():
        log.unlink()
    proc = subprocess.run(
        [
            "timeout",
            "180",
            "expect",
            str(CREATE_EXP),
            profile,
            char_name,
            sex,
            str(hs),
            str(hc),
        ],
        cwd=str(OK),
        capture_output=True,
        text=True,
        timeout=200,
        env=os.environ.copy(),
    )
    out = (proc.stdout or "") + "\n" + (proc.stderr or "")
    if log.exists():
        out += "\n" + log.read_text(errors="replace")[-4000:]
    return proc.returncode, out


def classify(rc: int, out: str) -> str:
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
            "DONE",
        )
    ):
        return "OK"
    if "SERVER_CLOSED" in out or "denied your connection" in out.lower():
        return "SERVER_CLOSED"
    if "BAD_LOGIN" in out:
        return "BAD_LOGIN"
    return f"FAIL:{rc}"


def append_party_macros(leader_char: str, member_chars: list[str]) -> None:
    """Ensure LeaderInvite roster + StopAt99 exist; preserve other Party12 macros."""
    invite_body = "\t\t[\n\t\t\tlog Party12: create/invite party\n\t\t\tdo party create P99\n\t\t\tpause 2\n\t\t]\n"
    for ch in member_chars:
        invite_body += f"\t\t[\n\t\t\tdo party request {ch}\n\t\t\tpause 3\n\t\t]\n"

    invite_block = f"""automacro Party12_LeaderInvite {{
	exclusive 1
	timeout 45
	priority 2
	ConfigKey partyRole leader
	BaseLevel >= 1
	JobLevel >= 7
	call {{
{invite_body}	}}
}}
"""

    stop_block = f"""automacro Party12_StopAt99 {{
	exclusive 1
	timeout 120
	priority 0
	BaseLevel >= 99
	call {{
		[
			log Party12: base 99 reached — park
			do conf attackAuto 0
			do conf route_randomWalk 0
			do conf follow 0
			do conf lockMap prontera
			do move 156 190
			do sit
		]
	}}
}}
"""

    refollow_block = f"""automacro Party12_MemberRefollow {{
	exclusive 1
	timeout 15
	priority 3
	ConfigKey partyRole member
	ConfigKeyNot follow 1
	call {{
		[
			log Party12: re-enable HARD follow/assist
			do conf follow 1
			do conf followBot 1
			do conf followTarget {leader_char}
			do conf attackAuto 1
			do conf attackAuto_party 1
			do conf attackAuto_followTarget 1
			do conf followDistanceMax 4
			do conf followDistanceMin 1
			do conf route_randomWalk 0
			do conf itemsGatherAuto 0
		]
	}}
}}
"""

    def replace_automacro(text: str, name: str, new_block: str) -> str:
        marker = f"automacro {name} {{"
        start = text.find(marker)
        if start < 0:
            return text.rstrip() + "\n\n" + new_block
        # find matching closing brace at automacro top-level
        i = start + len(marker)
        depth = 1
        while i < len(text) and depth:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        return text[:start] + new_block + text[i:]

    for rel in (
        OK / "fresh_grind" / "control" / "eventMacros.txt",
        OK / "control" / "eventMacros.txt",
    ):
        if not rel.exists():
            continue
        text = rel.read_text()
        text = replace_automacro(text, "Party12_LeaderInvite", invite_block)
        text = replace_automacro(text, "Party12_MemberRefollow", refollow_block)
        # migrate StopAt60 -> StopAt99
        if "automacro Party12_StopAt60 {" in text:
            text = replace_automacro(text, "Party12_StopAt60", stop_block)
        else:
            text = replace_automacro(text, "Party12_StopAt99", stop_block)
        text = re.sub(
            r"(# Party12 — leader invites; members follow/assist )\S+",
            rf"\1{leader_char}",
            text,
            count=1,
        )
        rel.write_text(text)
        print(f"updated Party12 macros in {rel}")


def main() -> int:
    if not CREATE_EXP.exists():
        raise SystemExit(f"missing {CREATE_EXP}")

    subprocess.run(["bash", str(OK / "scripts" / "install-shared-control.sh")], check=False)
    write_class_packs()
    PROFILES.mkdir(parents=True, exist_ok=True)

    used_users: set[str] = set()
    used_chars: set[str] = set()
    plan: list[dict] = []
    leader_char = ""

    for profile, job, is_leader in ROSTER:
        sex = random.choice(["M", "F"])
        user = rand_user(used_users)
        used_users.add(user)
        tag = "Ld" if is_leader else profile[-2:]
        char = rand_char(used_chars, tag)
        used_chars.add(char)
        if is_leader:
            leader_char = char
        plan.append(
            {
                "profile": profile,
                "job": job,
                "leader": is_leader,
                "sex": sex,
                "user": user,
                "pass": rand_pass(),
                "char": char,
                "hs": random.randint(1, 23),
                "hc": random.randint(0, 8),
            }
        )

    member_chars = [p["char"] for p in plan if not p["leader"]]
    ACCOUNT_MAP.write_text(
        "# profile\tclass\trole\tchar\tusername\tpassword\tsex\tleader_char\n"
    )
    PENDING.write_text("# profile\tchar\tsex\tuser\tpass\tjob\ths\thc\tleader\n")
    RESULTS.write_text("")

    ok_n = 0
    for p in plan:
        login = f"{p['user']}_{p['sex']}"
        write_profile(
            p["profile"],
            username=login,
            password=p["pass"],
            job=p["job"],
            char_name=p["char"],
            sex=p["sex"],
            is_leader=p["leader"],
            leader_char=leader_char,
        )
        print(
            f"=== CREATE {p['profile']} {p['job']} {login} char={p['char']} "
            f"{'LEADER' if p['leader'] else 'member'} ===",
            flush=True,
        )
        rc, out = create_char(p["profile"], p["char"], p["sex"], p["hs"], p["hc"])
        status = classify(rc, out)
        print(f"  rc={rc} status={status}", flush=True)
        if status == "OK":
            write_profile(
                p["profile"],
                username=p["user"],
                password=p["pass"],
                job=p["job"],
                char_name=p["char"],
                sex=p["sex"],
                is_leader=p["leader"],
                leader_char=leader_char,
            )
            with ACCOUNT_MAP.open("a") as f:
                f.write(
                    f"{p['profile']}\t{p['job']}\t"
                    f"{'leader' if p['leader'] else 'member'}\t{p['char']}\t"
                    f"{p['user']}\t{p['pass']}\t{p['sex']}\t{leader_char}\n"
                )
            RESULTS.write_text(RESULTS.read_text() + f"OK {p['profile']}\n")
            ok_n += 1
        else:
            with PENDING.open("a") as f:
                f.write(
                    f"{p['profile']}\t{p['char']}\t{p['sex']}\t{p['user']}\t{p['pass']}\t"
                    f"{p['job']}\t{p['hs']}\t{p['hc']}\t{int(p['leader'])}\n"
                )
            print(out[-1000:], flush=True)
        time.sleep(2)

    append_party_macros(leader_char, member_chars)
    subprocess.run(["bash", str(OK / "scripts" / "install-shared-control.sh")], check=False)

    (PROFILES / "FLEET_PARTY12.txt").write_text("\n".join(p["profile"] for p in plan) + "\n")
    (PROFILES / "PARTY12_LEADER.txt").write_text(leader_char + "\n")

    print(f"\nCreated OK={ok_n}/12 leader_char={leader_char}")
    print(f"Map: {ACCOUNT_MAP}")
    return 0 if ok_n >= 10 else 1


if __name__ == "__main__":
    raise SystemExit(main())
