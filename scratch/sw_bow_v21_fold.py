#!/usr/bin/env python3
"""Assertion-guarded fold: the bow row meets the closed bow chain
(science-writer seat).  v20 -> v21, every hunk asserted, STE pinned.

Base: git HEAD:docs/reporting/glossary-candidates.md
  md5 8a4bcbf75a42a8ee6a87e3e097bc9d6d (rev 8ffb803)

Two reader-facing gaps close here, both from the printed report:
  1. the draft (v0.57, c825a01) prints "sagging straight down under gravity";
     the v20 row never names gravity or the direction.
  2. the draft prints the settle/run disagreement as an instrument finding;
     the v20 row stops at the rule ("must agree"), which reads as settled.

No value enters the row.  NR-059 stays the sole carrier of the numbers.
The STE gate is an assertion: every category count must hold.
"""
import difflib
import hashlib
import importlib.util
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
REL = "docs/reporting/glossary-candidates.md"
SRC = ROOT / REL
OUT_BASE = ROOT / "scratch/sw_bow_v21_base.md"
OUT_NEW = ROOT / "scratch/sw_bow_v21_new.md"

BASE_MD5 = "8a4bcbf75a42a8ee6a87e3e097bc9d6d"
BASE_REV = "HEAD"

STATUS_OLD = "**Status** PREP v20, numbers-free by construction (no measurement values, no"
STATUS_NEW = "**Status** PREP v21, numbers-free by construction (no measurement values, no"

BOW_OLD = (
    "| bow | The lateral sag of the column axis off the design line, in the tilted plane. "
    "The perpendicular part of the hub weight causes it. The stack does not translate "
    "sideways: the bow is a rearrangement in which the lines reorient at near-constant "
    "length. The report holds it as an output, not a constraint. The settle calculation "
    "and the run must agree on it. | `DECISIONS.md` [2026-09-15] ruling 2, 2026-09-12 "
    "handover sections 2 and 5 | supply |"
)
BOW_NEW = (
    "| bow | The lateral sag of the column axis off the design line, in the tilted plane. "
    "The perpendicular part of the hub weight causes it. Gravity pulls the sag straight "
    "down. The stack does not translate sideways: the bow is a rearrangement in which the "
    "lines reorient at near-constant length. The report holds it as an output, not a "
    "constraint. A disagreement on the bowed shape reads as an instrument finding, not a "
    "design question. The settle calculation and the run must agree on it. | "
    "`DECISIONS.md` [2026-09-15] ruling 2, 2026-09-12 handover sections 2 and 5 | supply |"
)
GUARD_ROW = (
    "| \"bow\" as a sideways move, or a stack translation | bow: a line rearrangement "
    "at near-constant length. The stack does not translate sideways. | "
    "`DECISIONS.md` [2026-09-15] ruling 2 |"
)
ANCHOR_LAST = "  No other change.\n"
V20_BULLET = "- **v20 (2026-10-15):** the bow row lands at the science-writer seat, on the founder word."
V21_BULLET = (
    "\n- **v21 (2026-10-16):** the bow row meets the closed chain at the science-writer seat.\n"
    "  The row takes the founder gravity form of 2026-10-16: gravity pulls the sag straight down.\n"
    "  It takes the instrument-finding clause too, so the rule reads beside the printed disagreement (2026-09-15 ruling 2).\n"
    "  The row stays numbers-free, so the winner read stays a binding slot for the register (NR-059). No other change.\n"
)

checks = []


def check(name, cond, detail=""):
    checks.append((name, bool(cond), detail))
    print(("PASS  " if cond else "FAIL  ") + name + (("  | " + detail) if detail else ""))


def md5(b):
    return hashlib.md5(b).hexdigest()


spec = importlib.util.spec_from_file_location("ste", ROOT / "ste-lint.py")
assert spec is not None and spec.loader is not None
ste = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ste)

base = subprocess.run(
    ["git", "show", f"{BASE_REV}:{REL}"], cwd=ROOT, capture_output=True, text=True
).stdout
check("base reads from git", bool(base), BASE_REV)
check("base md5 pins", md5(base.encode()) == BASE_MD5, md5(base.encode()))
check("base line count 409", base.count("\n") == 409, str(base.count("\n")))
check("status v20 present exactly once", base.count(STATUS_OLD) == 1, str(base.count(STATUS_OLD)))
check("bow row present exactly once", base.count(BOW_OLD) == 1, str(base.count(BOW_OLD)))
check("bow row carries no digit", not any(c.isdigit() for c in BOW_OLD.split("|")[2]))
check("guard row present exactly once", base.count(GUARD_ROW) == 1, str(base.count(GUARD_ROW)))
check("v20 bullet present", V20_BULLET in base)
check("file ends at the delta block", base.endswith(ANCHOR_LAST))
OUT_BASE.write_bytes(base.encode())

new = base.replace(STATUS_OLD, STATUS_NEW)
check("one status replace", new.count(STATUS_NEW) == 1)
new = new.replace(BOW_OLD, BOW_NEW)
check("one bow-row replace", BOW_NEW in new and BOW_OLD not in new)
check("guard row byte-held", GUARD_ROW in new)
check("v20 bullet byte-held", V20_BULLET in new)
new = new + V21_BULLET
check("v21 bullet appended once at the tail", new.count(V21_BULLET) == 1 and new.endswith(V21_BULLET))
check("v21 bullet is its own paragraph",
      ("\n\n- **v21" in new) and not re.search(r"- \*\*v21[^\n]*\n\s*\n", new))

# line-level diff: the two replaces and the tail insert, nothing else moves
bl, nl = base.splitlines(), new.splitlines()
sm = difflib.SequenceMatcher(None, bl, nl)
opcodes = [o for o in sm.get_opcodes() if o[0] != "equal"]
check("3 changed hunks only", len(opcodes) == 3, str(opcodes))
if len(opcodes) == 3:
    check("hunk kinds replace/replace/insert", [o[0] for o in opcodes] == ["replace", "replace", "insert"])
    check("status hunk one line to one", (opcodes[0][2] - opcodes[0][1], opcodes[0][4] - opcodes[0][3]) == (1, 1))
    check("bow hunk one line to one", (opcodes[1][2] - opcodes[1][1], opcodes[1][4] - opcodes[1][3]) == (1, 1))
    check("insert sits at EOF", opcodes[2][1] == len(bl) == opcodes[2][3], f"{opcodes[2][1]}/{len(bl)}")
check("all unchanged lines byte-held in order",
      all(bl[i1:i2] == nl[j1:j2] for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag == "equal"))

rows_base = sum(1 for l in bl if l.startswith("| "))
rows_new = sum(1 for l in nl if l.startswith("| "))
check("row lines unchanged", rows_base == rows_new, f"{rows_base} -> {rows_new}")
check("line count 409 -> 414", (len(bl), len(nl)) == (409, 414), f"{len(bl)} -> {len(nl)}")
check("row cells 4 on the bow row", BOW_NEW.count("|") == 5, str(BOW_NEW.count("|")))
check("no new em dash, no semicolon",
      BOW_NEW.count("\u2014") == BOW_OLD.count("\u2014") and ";" not in BOW_NEW)
check("no digit in the definition cell", not any(c.isdigit() for c in BOW_NEW.split("|")[2]))
check("ground cell byte-held", BOW_NEW.split("|")[3] == BOW_OLD.split("|")[3])

# STE gate as an assertion: every category count must hold
lb, ln = ste.lint(base), ste.lint(new)
check("STE category counts unchanged", lb["violations"] == ln["violations"],
      f"base {lb['total']} -> new {ln['total']}")
check("STE total unchanged", lb["total"] == ln["total"], f"{lb['total']} -> {ln['total']}")
check("STE per100w under 2.0", ln["total_per100w"] < 2.0, str(ln["total_per100w"]))
check("v21 bullet paragraph holds 6 sentences or fewer",
      len(ste.sentences(V21_BULLET.strip())) <= 6, str(len(ste.sentences(V21_BULLET.strip()))))

OUT_NEW.write_bytes(new.encode())
SRC.write_bytes(new.encode())
check("candidate written to the tree", md5(SRC.read_bytes()) == md5(new.encode()))

bad = [c for c in checks if not c[1]]
print(f"\n{len(checks)} checks, {len(bad)} fail")
sys.exit(1 if bad else 0)
