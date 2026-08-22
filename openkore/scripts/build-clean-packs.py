#!/usr/bin/env python3
"""Build class-specific *_clean packs from assassin_clean (AssassinClean settings)."""
from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assassin_clean" / "control"

# first job after Novice; Job Master reply; weapon to buy/equip
CLASSES = {
    "assassin": {
        "label": "Assassin",
        "first": "Thief",
        "first_id": 6,
        "reply": "r5",
        "weapon": "Knife [3]",
        "extra_buys": [],
        "attack_ranged": False,
    },
    "knight": {
        "label": "Knight",
        "first": "Swordman",
        "first_id": 1,
        "reply": "r0",
        "weapon": "Sword [3]",
        "extra_buys": [],
        "attack_ranged": False,
    },
    "wizard": {
        "label": "Wizard",
        "first": "Magician",
        "first_id": 2,
        "reply": "r1",
        "weapon": "Rod [3]",
        "extra_buys": [],
        "attack_ranged": False,
    },
    "hunter": {
        "label": "Hunter",
        "first": "Archer",
        "first_id": 3,
        "reply": "r2",
        "weapon": "Bow [3]",
        "extra_buys": [
            (
                "Arrow",
                """buyAuto Arrow {
	npc prt_in 126 76
	standpoint prt_in 126 74
	distance 5
	minAmount 50
	maxAmount 300
	zeny > 50
	disabled 0
}
""",
            )
        ],
        "attack_ranged": True,
    },
    "priest": {
        "label": "Priest",
        "first": "Acolyte",
        "first_id": 4,
        "reply": "r3",
        "weapon": "Mace",
        "extra_buys": [],
        "attack_ranged": False,
    },
    "blacksmith": {
        "label": "Blacksmith",
        "first": "Merchant",
        "first_id": 5,
        "reply": "r4",
        "weapon": "Axe [3]",
        "extra_buys": [],
        "attack_ranged": False,
    },
}


def write_pack(key: str, meta: dict) -> Path:
    dst = ROOT / f"{key}_clean" / "control"
    dst.mkdir(parents=True, exist_ok=True)

    # Copy shared files
    for name in ("items_control.txt", "mon_control.txt", "fieldScout_macros.txt"):
        src = SRC / name
        if src.exists():
            shutil.copy2(src, dst / name)

    # --- config.txt ---
    cfg = (SRC / "config.txt").read_text()
    first = meta["first"]
    weapon = meta["weapon"]
    wid = meta["first_id"]

    cfg = cfg.replace(
        "######## AssassinClean — Novice prt_fild08 → Thief gear → Payon / pay_fild08 ########",
        f"######## {meta['label']}Clean — Novice prt_fild08 → {first} gear → Payon / pay_fild08 ########",
    )
    # Weapon buyAuto: replace Knife [3] block name/contents
    cfg = re.sub(
        r"buyAuto Knife \[3\] \{",
        f"buyAuto {weapon} {{",
        cfg,
        count=1,
    )
    # equipAuto Knife → weapon
    cfg = cfg.replace("rightHand Knife [3]", f"rightHand {weapon}")
    # Remove Main Gauche equip for non-thief; keep for assassin
    if key != "assassin":
        cfg = re.sub(
            r"equipAuto \{\n\trightHand Main Gauche\n\tJobID 6\n\tdisabled 0\n\}\n",
            "",
            cfg,
        )
        cfg = cfg.replace("JobID 6", f"JobID {wid}")

    # Flags: unify on ragnaJob1st (keep ragnaJobThief aliases for assassin compat)
    if "ragnaJob1st" not in cfg:
        cfg = cfg.replace("ragnaJobThief 0", "ragnaJobThief 0\nragnaJob1st 0")
        # duplicate block at end also
        cfg = re.sub(
            r"(ragnaJobThief 0\nragnaThiefGear 0)",
            r"ragnaJobThief 0\nragnaJob1st 0\nragnaThiefGear 0",
            cfg,
        )

    if meta["attack_ranged"]:
        cfg = re.sub(r"^attackDistance \d+", "attackDistance 5", cfg, count=1, flags=re.M)
        cfg = re.sub(r"^attackMaxDistance \d+", "attackMaxDistance 9", cfg, count=1, flags=re.M)
        cfg = re.sub(r"^attackDistanceAuto \d+", "attackDistanceAuto 1", cfg, count=1, flags=re.M)

    # Insert extra buyAutos after weapon block
    for _name, block in meta["extra_buys"]:
        if f"buyAuto {_name}" not in cfg:
            cfg = cfg.replace(
                f"buyAuto {weapon} {{",
                block + f"buyAuto {weapon} {{",
                1,
            )

    (dst / "config.txt").write_text(cfg)

    # --- eventMacros.txt ---
    em = (SRC / "eventMacros.txt").read_text()
    # Job change talk reply
    em = em.replace("do talknpc 150 180 c c c r5 c r0", f"do talknpc 150 180 c c c {meta['reply']} c r0")
    em = em.replace("for Thief", f"for {first}")
    em = em.replace("to Thief", f"to {first}")
    em = em.replace("Job change to Thief", f"Job change to {first}")
    em = em.replace("Now Thief", f"Now {first}")
    em = em.replace("Thief buy", f"{first} buy")
    em = em.replace("Thief gear", f"{first} gear")
    em = em.replace("Thief set save", f"{first} set save")
    em = em.replace("Thief hunting", f"{first} hunting")
    em = em.replace("buy Knife [3]", f"buy {weapon}")
    em = em.replace('InInventory "Knife [3]"', f'InInventory "{weapon}"')
    em = em.replace("do eq Knife [3]", f"do eq {weapon}")
    em = em.replace("Knife [3] at Prontera", f"{weapon} at Prontera")
    em = em.replace("Knife [3] + Cotton Shirt", f"{weapon} + Cotton Shirt")
    # JobID after change
    em = re.sub(
        r"(automacro Ragna_Job_ToThief_Done \{\n\t)JobID 6",
        rf"\1JobID {wid}",
        em,
    )
    em = re.sub(
        r"(automacro Ragna_Thief_BuyKnife \{\n\t)JobID 6",
        rf"\1JobID {wid}",
        em,
    )
    em = re.sub(
        r"(automacro Ragna_Thief_BuyShirt \{\n\t)JobID 6",
        rf"\1JobID {wid}",
        em,
    )
    em = re.sub(
        r"(automacro Ragna_Thief_GearDone \{\n\t)JobID 6",
        rf"\1JobID {wid}",
        em,
    )
    em = re.sub(
        r"(automacro Ragna_Thief_SavePayon \{\n\t)JobID 6",
        rf"\1JobID {wid}",
        em,
    )
    em = re.sub(
        r"(automacro Ragna_Thief_ShopsPayon \{\n\t)JobID 6",
        rf"\1JobID {wid}",
        em,
        count=0,
    )
    em = re.sub(
        r"(automacro Ragna_Thief_HuntPayFild08 \{\n\t)JobID 6",
        rf"\1JobID {wid}",
        em,
    )
    # Fix ShopsPayon - it doesn't have JobID 6 in assassin_clean; Hunt does
    # Rename macros/flags Thief → Job1st for clarity while keeping keys working
    # Use ragnaJob1st alongside ragnaJobThief (set both on done)
    em = em.replace(
        "do conf ragnaJobThief 1",
        "do conf ragnaJobThief 1\n\t\t\tdo conf ragnaJob1st 1",
    )
    # Gate post-job on ragnaJob1st for non-assassin; keep dual check
    if key != "assassin":
        em = em.replace("ConfigKey ragnaJobThief 1", "ConfigKey ragnaJob1st 1")
        em = em.replace("ConfigKeyNot ragnaJobThief 1", "ConfigKeyNot ragnaJob1st 1")
        em = em.replace("$config{ragnaJobThief}", "$config{ragnaJob1st}")
        # Rename ToThief macros in comments only is fine; keep names for less churn
        em = em.replace("automacro Ragna_Thief_BuyKnife", f"automacro Ragna_{first}_BuyWeapon")
        em = em.replace("automacro Ragna_Thief_BuyShirt", f"automacro Ragna_{first}_BuyShirt")
        em = em.replace("automacro Ragna_Thief_GearDone", f"automacro Ragna_{first}_GearDone")
        em = em.replace("automacro Ragna_Thief_SavePayon", f"automacro Ragna_{first}_SavePayon")
        em = em.replace("automacro Ragna_Thief_ShopsPayon", f"automacro Ragna_{first}_ShopsPayon")
        em = em.replace("automacro Ragna_Thief_HuntPayFild08", f"automacro Ragna_{first}_HuntPayFild08")
        em = em.replace("automacro Ragna_Job_ToThief_Go", f"automacro Ragna_Job_To{first}_Go")
        em = em.replace("automacro Ragna_Job_ToThief_Talk", f"automacro Ragna_Job_To{first}_Talk")
        em = em.replace("automacro Ragna_Job_ToThief_Done", f"automacro Ragna_Job_To{first}_Done")

    # ApplyPayonShops: weapon items go to weapon dealer (non-potion non-shirt)
    # Knife pattern already falls through to else → weapon dealer. Good.
    # For Arrow (potion pattern has ^Arrow$) → tool dealer. Good.

    (dst / "eventMacros.txt").write_text(em)
    print(f"OK {key}_clean  first={first} id={wid} weapon={weapon} reply={meta['reply']}")
    return dst


def main():
    for key, meta in CLASSES.items():
        if key == "assassin":
            # assassin_clean is the source template — do not overwrite in-place
            print(f"SKIP assassin_clean (template)")
            continue
        write_pack(key, meta)
    print("Done.")


if __name__ == "__main__":
    main()
