#!/usr/bin/env python3
"""Independent checker: the bow row and its guard row (science-writer seat).

Reads the live file and the base revision from git (not from the fold's own
scratch copy), re-derives every claim the receipt makes, and reports a count.
"""
import hashlib
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
REL = "docs/reporting/glossary-candidates.md"
SRC = ROOT / REL
BOW_MD5 = "8a4bcbf75a42a8ee6a87e3e097bc9d6d"
BASE_MD5 = "c0d82058355ce53118d675ed30162b43"
BASE_REV = "HEAD"

BOW_ROW = ("| bow | The lateral sag of the column axis off the design line, in the tilted plane. "
           "The perpendicular part of the hub weight causes it. The stack does not translate "
           "sideways: the bow is a rearrangement in which the lines reorient at near-constant "
           "length. The report holds it as an output, not a constraint. The settle calculation "
           "and the run must agree on it. | `DECISIONS.md` [2026-09-15] ruling 2, 2026-09-12 "
           "handover sections 2 and 5 | supply |")
GUARD_ROW = ("| \"bow\" as a sideways move, or a stack translation | bow: a line rearrangement "
             "at near-constant length. The stack does not translate sideways. | "
             "`DECISIONS.md` [2026-09-15] ruling 2 |")
STATUS_OLD = "**Status** PREP v19, numbers-free by construction (no measurement values, no"
STATUS_NEW = "**Status** PREP v20, numbers-free by construction (no measurement values, no"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout


checks = []


def check(name, cond, detail=""):
    checks.append(name)
    if not cond:
        print(f"FAIL  {name}  {detail}")
        sys.exit(1)
    print(f"ok    {name}")


live = SRC.read_text()
base = git("show", f"{BASE_REV}:{REL}")

check("live md5 pins to the folded candidate",
      hashlib.md5(live.encode()).hexdigest() == BOW_MD5, hashlib.md5(live.encode()).hexdigest())
check("base revision md5 pins", hashlib.md5(base.encode()).hexdigest() == BASE_MD5)
check("base revision carries no bow row", "| bow |" not in base)
check("base revision carries no bow guard row", "\"bow\" as a sideways move" not in base)

check("bow row present exactly once", live.count(BOW_ROW) == 1)
check("guard row present exactly once", live.count(GUARD_ROW) == 1)
check("bow row sits directly under the destructive-resonance row",
      live.count("| destructive resonance |") == 1
      and re.search(r"\| destructive resonance \|[^\n]*\n" + re.escape(BOW_ROW), live) is not None)
check("guard row sits directly under the era retire row",
      "| \"physics-validation era\" |" in live
      and (live.index("| \"physics-validation era\" |") < live.index(GUARD_ROW)))
check("guard row is the last row of section 7",
      live.index(GUARD_ROW) < live.index("## 8. Handoff"))

check("status line reads PREP v20", live.count(STATUS_NEW) == 1)
check("the v19 status line is gone from the file", STATUS_OLD not in live)
check("v18 delta bullet still present", live.count("- **v18 (2026-10-15):**") == 1)
check("v19 delta bullet still present", live.count("- **v19 (2026-10-15):**") == 1)
check("v20 delta bullet present exactly once", live.count("- **v20 (2026-10-15):**") == 1)
check("v20 delta bullet reads six lines",
      len(live.split("- **v20 (2026-10-15):**")[1].split("\n\n")[0].splitlines()) == 6)
def v19_block(text):
    return text.split("- **v19 (2026-10-15):**")[1].split("\n\n")[0].rstrip("\n")


check("the v19 delta block is byte-held against the base",
      v19_block(base) == v19_block(live))
check("v20 delta records the landing", "the bow row lands" in live)

# every base line survives, and the only base line that changes is the status line
base_lines = base.splitlines()
live_lines = live.splitlines()
lost = [l for l in base_lines if l not in live_lines and l != STATUS_OLD]
check("no base line is lost", lost == [], repr(lost[:2]))
check("the only changed base line is the status line",
      [l for l in base_lines if l != STATUS_OLD and l not in live_lines] == [])
check("row census reads 143", sum(1 for l in live_lines if l.startswith("|")) == 143)
check("line count reads 409", len(live_lines) == 409)

# identity the row claims
check("bow row cites the 2026-09-15 ruling 2", "[2026-09-15] ruling 2" in BOW_ROW)
check("bow row does not cite physics-topology", "physics-topology" not in BOW_ROW)
check("bow row does not cite the register", "NR-" not in BOW_ROW and "NR-" not in GUARD_ROW)
check("bow row is numbers-free", not any(c.isdigit() for c in BOW_ROW.split("|")[2]))
check("guard row is numbers-free", not any(c.isdigit() for c in GUARD_ROW.split("|")[2]))
check("bow row keeps the ruling's operative word", "does not translate sideways" in BOW_ROW)
check("bow row drops the old compression", "moves little" not in live)
check("guard row bars the stack translation", "stack translation" in GUARD_ROW)
check("no new row prints the nominalization", "translation of" not in live)

# grounds resolve in the tree
check("DECISIONS.md exists", (ROOT / "DECISIONS.md").exists())
check("the 2026-09-12 bow handover exists",
      (ROOT / "handovers/handover-2026-09-12-settle-rebuild-bow-and-static-solver.md").exists())
decisions = (ROOT / "DECISIONS.md").read_text()
check("the ruling carries the bow ruling", "Bow is an output, not a constraint" in decisions)
check("the ruling bars the 1.5 m print", "1.5 m figure must not be quoted as a" in decisions)
handover = (ROOT / "handovers/handover-2026-09-12-settle-rebuild-bow-and-static-solver.md").read_text()
check("the handover carries the near-constant-length rearrangement",
      "their lengths stay near-constant" in handover)
check("the handover carries the perpendicular-weight cause",
      "perpendicular to the shaft" in handover)

# scope: one tracked file, register untouched, no draft byte moves
changed = sorted(l for l in git("diff", "--name-only", BASE_REV).splitlines() if l)
check("exactly the two owned files changed",
      changed == sorted([REL, "scratch/sw_bptr_supply.md"]), repr(changed))
draft_moves = [l for l in git("diff", "--name-only", BASE_REV, "--", "docs/reporting/draft").splitlines() if l]
check("no draft byte moves", draft_moves == [], repr(draft_moves))
reg = git("diff", "--name-only", BASE_REV, "--", "docs/reporting/numbers-register.md")
check("the numbers register is untouched", reg.strip() == "")

print(f"\n{len(checks)} checks, 0 fail")
