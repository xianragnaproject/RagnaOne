#!/usr/bin/env python3
"""Apply class-specific skillsAddAuto + attack/party/self skill blocks to grind profiles."""
from __future__ import annotations

import re
import sys
from pathlib import Path

PROFILES = Path.home() / "openkore" / "profiles"

CLASS_SKILLS = {
    "Swordman": {
        "skillsAddAuto_list": (
            "Basic Skill 9, Sword Mastery 10, Bash 10, Magnum Break 10, "
            "Provoke 5, Endure 5, Increase HP Recovery 5"
        ),
        "blocks": """
attackSkillSlot Bash {
	lvl 10
	dist 1
	maxDist 2
	sp > 5
	notInTown 1
	timeout 1
	disabled 0
}
attackSkillSlot Magnum Break {
	lvl 10
	dist 1
	maxDist 2
	sp > 12
	notInTown 1
	timeout 2
	disabled 0
}
attackSkillSlot Provoke {
	lvl 5
	dist 1
	maxDist 9
	sp > 5
	notInTown 1
	timeout 3
	disabled 0
}
""",
    },
    "Magician": {
        "skillsAddAuto_list": (
            "Basic Skill 9, Increase SP Recovery 8, Sight 1, Fire Bolt 10, "
            "Cold Bolt 5, Lightning Bolt 5, Napalm Beat 5, Fire Ball 5"
        ),
        "blocks": """
attackSkillSlot Fire Bolt {
	lvl 10
	dist 9
	maxDist 9
	sp > 8
	notInTown 1
	timeout 1
	disabled 0
}
attackSkillSlot Cold Bolt {
	lvl 5
	dist 9
	maxDist 9
	sp > 8
	notInTown 1
	timeout 1
	disabled 0
}
attackSkillSlot Lightning Bolt {
	lvl 5
	dist 9
	maxDist 9
	sp > 8
	notInTown 1
	timeout 1
	disabled 0
}
attackSkillSlot Napalm Beat {
	lvl 5
	dist 9
	maxDist 9
	sp > 8
	notInTown 1
	timeout 1
	disabled 0
}
""",
    },
    "Archer": {
        "skillsAddAuto_list": (
            "Basic Skill 9, Owl's Eye 5, Vulture's Eye 5, Double Strafe 10, "
            "Owl's Eye 10, Vulture's Eye 10, Improve Concentration 5, "
            "Arrow Shower 10, Charge Arrow 1"
        ),
        "blocks": """
attackSkillSlot Double Strafe {
	lvl 10
	dist 9
	maxDist 9
	sp > 8
	notInTown 1
	timeout 1
	disabled 0
}
attackSkillSlot Arrow Shower {
	lvl 10
	dist 9
	maxDist 9
	sp > 8
	notInTown 1
	timeout 2
	disabled 0
}
attackSkillSlot Charge Arrow {
	lvl 1
	dist 9
	maxDist 9
	sp > 8
	notInTown 1
	timeout 2
	disabled 0
}
useSelf_skill Improve Concentration {
	lvl 5
	sp > 8
	whenStatusInactive Improve Concentration
	notInTown 1
	timeout 60
	disabled 0
}
""",
    },
    "Acolyte": {
        "skillsAddAuto_list": (
            "Basic Skill 9, Heal 10, Increase Agility 10, Blessing 10, Angelus 5, "
            "Cure 1, Divine Protection 5, Demon Bane 3, Holy Light 1, Ruwach 1"
        ),
        "blocks": """
attackSkillSlot Holy Light {
	lvl 1
	dist 9
	maxDist 9
	sp > 8
	notInTown 1
	timeout 1
	disabled 0
}
useSelf_skill Heal {
	lvl 10
	sp > 8
	hp < 70%
	timeout 1
	disabled 0
}
useSelf_skill Angelus {
	lvl 5
	sp > 12
	whenStatusInactive Angelus
	notInTown 1
	timeout 30
	disabled 0
}
useSelf_skill Blessing {
	lvl 10
	sp > 12
	whenStatusInactive Blessing
	notInTown 1
	timeout 30
	disabled 0
}
useSelf_skill Increase Agility {
	lvl 10
	sp > 12
	whenStatusInactive Increase Agility
	notInTown 1
	timeout 30
	disabled 0
}
partySkill Heal {
	lvl 10
	dist 1
	maxDist 8
	sp > 8
	target_hp < 80%
	notPartyOnly 0
	isSelfSkill 0
	timeout 1
	disabled 0
}
partySkill Blessing {
	lvl 10
	dist 1
	maxDist 8
	sp > 15
	target_whenStatusInactive Blessing
	notPartyOnly 0
	timeout 20
	disabled 0
}
partySkill Increase Agility {
	lvl 10
	dist 1
	maxDist 8
	sp > 15
	target_whenStatusInactive Increase Agility
	notPartyOnly 0
	timeout 20
	disabled 0
}
""",
    },
    "Merchant": {
        "skillsAddAuto_list": (
            "Basic Skill 9, Enlarge Weight Limit 10, Mammonite 10, Discount 5, "
            "Overcharge 5, Pushcart 10, Item Appraisal 1, Vending 1"
        ),
        "blocks": """
attackSkillSlot Mammonite {
	lvl 10
	dist 1
	maxDist 2
	sp > 8
	notInTown 1
	timeout 1
	disabled 0
}
""",
    },
    "Thief": {
        "skillsAddAuto_list": (
            "Basic Skill 9, Double Attack 10, Improve Dodge 10, Envenom 5, "
            "Steal 4, Hiding 2, Detoxify 1"
        ),
        "blocks": """
attackSkillSlot Envenom {
	lvl 5
	dist 1
	maxDist 2
	sp > 8
	notInTown 1
	timeout 2
	disabled 0
}
""",
    },
}

# Alias job names used in grindTargetJob
ALIASES = {
    "Swordman": "Swordman",
    "Swordsman": "Swordman",
    "Magician": "Magician",
    "Mage": "Magician",
    "Archer": "Archer",
    "Acolyte": "Acolyte",
    "Merchant": "Merchant",
    "Thief": "Thief",
}

MARKER_BEGIN = "######## FreshGrind class skills (auto) ########"
MARKER_END = "######## End FreshGrind class skills ########"


def set_key(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)}\s+.*$", re.M)
    line = f"{key} {value}"
    if pat.search(text):
        return pat.sub(line, text, count=1)
    return text + f"\n{line}\n"


def strip_old_skill_section(text: str) -> str:
    if MARKER_BEGIN in text and MARKER_END in text:
        return re.sub(
            re.escape(MARKER_BEGIN) + r".*?" + re.escape(MARKER_END) + r"\n?",
            "",
            text,
            count=1,
            flags=re.S,
        )
    return text


def upsert_named_blocks(text: str, blocks: str) -> str:
    """Remove prior FreshGrind skill section and append new blocks."""
    text = strip_old_skill_section(text)
    # Disable empty template blocks so they don't compete with named skills
    text = re.sub(
        r"^attackSkillSlot\s*\{",
        "attackSkillSlot {\n\tdisabled 1",
        text,
        count=1,
        flags=re.M,
    )
    text = re.sub(
        r"^useSelf_skill\s*\{",
        "useSelf_skill {\n\tdisabled 1",
        text,
        count=1,
        flags=re.M,
    )
    text = re.sub(
        r"^partySkill\s*\{",
        "partySkill {\n\tdisabled 1",
        text,
        count=1,
        flags=re.M,
    )
    section = f"\n{MARKER_BEGIN}\n{blocks.strip()}\n{MARKER_END}\n"
    return text.rstrip() + "\n" + section


def apply_profile(path: Path) -> str | None:
    text = path.read_text()
    m = re.search(r"^grindTargetJob\s+(\S+)", text, re.M)
    if not m:
        return None
    job_raw = m.group(1)
    job = ALIASES.get(job_raw)
    if not job or job not in CLASS_SKILLS:
        return f"skip unknown job {job_raw}"
    spec = CLASS_SKILLS[job]
    text = set_key(text, "skillsAddAuto", "1")
    text = set_key(text, "skillsAddAuto_list", spec["skillsAddAuto_list"])
    text = upsert_named_blocks(text, spec["blocks"])
    path.write_text(text)
    return job


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else PROFILES
    for prof in sorted(root.iterdir()):
        cfg = prof / "config.txt"
        if not cfg.is_file() or not prof.name.startswith("Grind"):
            continue
        result = apply_profile(cfg)
        print(f"{prof.name}: {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
