#!/usr/bin/env python3
"""Assertion-guarded fold: the bow row into the glossary candidates
(science-writer seat).  v19 -> v20, every hunk asserted.

Lands on the founder word ("up", 2026-10-15), with the aero desk's ruling-
consistent third sentence and the ground re-read at the tip.
"""
import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "docs/reporting/glossary-candidates.md"
BASE = ROOT / "scratch/sw_bow_base.md"
NEW = ROOT / "scratch/sw_bow_new.md"

BASE_MD5 = "c0d82058355ce53118d675ed30162b43"
BOW_MD5 = "c0d82058355ce53118d675ed30162b43"

STATUS_OLD = "**Status** PREP v19, numbers-free by construction (no measurement values, no"
STATUS_NEW = "**Status** PREP v20, numbers-free by construction (no measurement values, no"

ANCHOR = (
    "| destructive resonance | The shaft failure mode of an earlier gain sweep. "
    "The twist ripple grows and does not settle. The shaft snaps between states, "
    "and the power falls to zero in intervals. The report names the term for that "
    "earlier round only. That round and this campaign share no number. "
    "| `docs/NOTES_MPPT_TWIST.md` section 3, the 2026-09-25 Tulloch plan section 9 "
    "| supply |"
)

BOW_ROW = (
    "| bow | The lateral sag of the column axis off the design line, in the tilted "
    "plane. The perpendicular part of the hub weight causes it. The stack does not "
    "translate sideways: the bow is a rearrangement in which the lines reorient at "
    "near-constant length. The report holds it as an output, not a constraint. "
    "The settle calculation and the run must agree on it. "
    "| `DECISIONS.md` [2026-09-15] ruling 2, 2026-09-12 handover sections 2 and 5 "
    "| supply |"
)

RETIRE_ANCHOR = (
    "| \"physics-validation era\" | the wind-authority era, or the era label "
    "`post-95c385d_wind-authority`. A physics-validation ledger is a record, not an era. "
    "| register header, the provenance stamps, CONTEXT.md:255 |"
)

GUARD_ROW = (
    "| \"bow\" as a sideways move, or a stack translation "
    "| bow: a line rearrangement at near-constant length. The stack does not translate sideways. "
    "| `DECISIONS.md` [2026-09-15] ruling 2 |"
)

V19_TAIL = (
    "  The status line takes v19, from a header that the v18 pass left at v17.\n"
    "  The bow row does not land and waits on a ruling from the founder.\n"
    "  No other change.\n"
)

V20_DELTA = (
    "\n- **v20 (2026-10-15):** the bow row lands at the science-writer seat, on the founder word.\n"
    "  Section 2 takes the bow row after the destructive-resonance row.\n"
    "  Section 7 takes its guard row after the era retire row.\n"
    "  The ground reads `DECISIONS.md` ruling 2 of 2026-09-15 and the 2026-09-12 handover, sections 2 and 5.\n"
    "  The row carries no value, so the winner read stays a binding slot for the register.\n"
    "  No other change.\n"
)

checks = []


def check(name, cond):
    checks.append((name, bool(cond)))
    if not cond:
        print(f"FAIL  {name}")
        sys.exit(1)
    print(f"ok    {name}")


base = BASE.read_text()
check("base md5 pins", hashlib.md5(base.encode()).hexdigest() == BASE_MD5)
check("base carries no bow row", "| bow |" not in base)
check("worktree file == base (no drift since the pin)", SRC.read_text() == base)
check("base status line reads PREP v19", base.count(STATUS_OLD) == 1)
check("status token v20 is absent at base", "PREP v20" not in base)
check("destructive-resonance anchor is unique", base.count(ANCHOR) == 1)
check("era retire-row anchor is unique", base.count(RETIRE_ANCHOR) == 1)
check("v19 delta tail is unique", base.count(V19_TAIL) == 1)
check("base carries no bow guard row", "\"bow\" as a sideways move" not in base)
check("base row census reads 141", sum(1 for l in base.splitlines() if l.startswith("|")) == 141)
check("base line count reads 400", len(base.splitlines()) == 400)

new = base.replace(STATUS_OLD, STATUS_NEW, 1)
check("status token moved once", new.count(STATUS_NEW) == 1 and new.count(STATUS_OLD) == 0)

new = new.replace(ANCHOR, ANCHOR + "\n" + BOW_ROW, 1)
check("bow row inserted once", new.count(BOW_ROW) == 1)
check("bow row sits under the destructive-resonance row", (ANCHOR + "\n" + BOW_ROW) in new)

new = new.replace(RETIRE_ANCHOR, RETIRE_ANCHOR + "\n" + GUARD_ROW, 1)
check("guard row inserted once", new.count(GUARD_ROW) == 1)
check("guard row sits under the era retire row", (RETIRE_ANCHOR + "\n" + GUARD_ROW) in new)

new = new.replace(V19_TAIL, V19_TAIL + V20_DELTA, 1)
check("v20 delta appended once", new.count("- **v20 (2026-10-15):**") == 1)
check("v19 delta tail byte-held", V19_TAIL in new and new.count("- **v19 (2026-10-15):**") == 1)

# row-level hold: every base row survives, exactly two rows are new
base_rows = [l for l in base.splitlines() if l.startswith("|")]
new_rows = [l for l in new.splitlines() if l.startswith("|")]
added = [r for r in new_rows if r not in base_rows]
missing = [r for r in base_rows if r not in new_rows]
check("no base row lost", missing == [])
check("exactly the two new rows added", sorted(added) == sorted([BOW_ROW, GUARD_ROW]))
check("row census reads 143", len(new_rows) == 143)
check("line count reads 409", len(new.splitlines()) == 409)

# the whole file's non-added lines are byte-held, in order
V20_LINES = set(V20_DELTA.splitlines())

# line-level diff: the ONLY changes are the status replace and three inserts
import difflib

base_lines = base.splitlines()
new_lines = new.splitlines()
ops = [(tag, base_lines[i1:i2], new_lines[j1:j2])
       for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(a=base_lines, b=new_lines, autojunk=False).get_opcodes()
       if tag != "equal"]
deletes = [o for o in ops if o[0] == "delete"]
replaces = [o for o in ops if o[0] == "replace"]
inserts = [o for o in ops if o[0] == "insert"]
check("no line is deleted", deletes == [])
check("exactly one replace, the status token", replaces == [("replace", [STATUS_OLD], [STATUS_NEW])])
inserted = [l for _, _, lines in inserts for l in lines]
expected_inserted = [BOW_ROW, GUARD_ROW] + V20_DELTA.splitlines()
check("every inserted line is a specced new line", sorted(inserted) == sorted(expected_inserted))
check("three insert sites", len(inserts) == 3)
check("file ends with exactly one newline", new.endswith("\n") and not new.endswith("\n\n"))

# numbers-free: the two new definition cells carry no digit
for label, row in (("bow", BOW_ROW), ("guard", GUARD_ROW)):
    cells = row.split("|")
    body = cells[1] + cells[2]
    check(f"{label} row cells are numbers-free", not any(ch.isdigit() for ch in body))

# the aero desk's fix: the operative word survives, and the old compression is gone
check("bow row keeps 'not translate sideways'", "does not translate sideways" in BOW_ROW)
check("bow row drops the old 'stack moves little' compression", "moves little" not in BOW_ROW)
check("guard row bars the stack-translation reading", "stack translation" in GUARD_ROW)
check("guard row keeps the reorient form", "near-constant length" in GUARD_ROW)
check("no new row prints the 'translation of' nominalization",
      "translation of" not in BOW_ROW and "translation of" not in GUARD_ROW)
check("bow row cites the 2026-09-15 ruling", "[2026-09-15] ruling 2" in BOW_ROW)
check("bow row drops the physics-topology ground (no bow entry there)", "physics-topology" not in BOW_ROW)

# the landed row backs the report sentence: it names the agreement rule
check("bow row carries the settle/run agreement rule", "must agree on it" in BOW_ROW)

NEW.write_text(new)
print(f"\n{len(checks)} checks, 0 fail")
print(f"candidate: {NEW}  md5 {hashlib.md5(new.encode()).hexdigest()}")
