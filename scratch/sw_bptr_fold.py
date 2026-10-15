#!/usr/bin/env python3
"""Assertion-guarded fold: the destructive-resonance row into the glossary
candidates (science-writer seat).  Base -> candidate, every hunk asserted."""
import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "docs/reporting/glossary-candidates.md"
BASE = ROOT / "scratch/sw_bptr_base.md"
NEW = ROOT / "scratch/sw_bptr_new.md"

BASE_MD5 = "d452554f3b87875845b3cedb6d1b62b1"

ROW = (
    "| destructive resonance | The shaft failure mode of an earlier gain sweep. "
    "The twist ripple grows and does not settle. The shaft snaps between states, "
    "and the power falls to zero in intervals. The report names the term for that "
    "earlier round only. That round and this campaign share no number. "
    "| `docs/NOTES_MPPT_TWIST.md` section 3, the 2026-09-25 Tulloch plan section 9 "
    "| supply |"
)

ANCHOR = (
    "| collapse margin | The distance between the current twist state and the "
    "torsional collapse cliff. | CONTEXT.md | supply |"
)

STATUS_OLD = "**Status** PREP v17, numbers-free by construction (no measurement values, no"
STATUS_NEW = "**Status** PREP v19, numbers-free by construction (no measurement values, no"

DELTA_OLD_TAIL = "  The section 2 elevation-angle row takes the campaign form (NR-057).\n  No other change.\n"

DELTA_NEW = (
    "\n- **v19 (2026-10-15):** the back-pointer term lands at the science-writer seat.\n"
    "  Section 2 takes the destructive-resonance row, from the v0.56 load-block back-pointer (`docs/NOTES_MPPT_TWIST.md` section 3, `docs/plans/2026-09-25-trpt-tulloch-criterion-correction.md` section 9).\n"
    "  The row carries no value, so the gain figure stays a binding slot for Track D.\n"
    "  The status line takes v19, from a header that the v18 pass left at v17.\n"
    "  The bow row does not land and waits on a ruling from the founder.\n"
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
check("worktree file == base (no drift since the pin)", SRC.read_text() == base)
check("base carries no destructive-resonance row", "destructive resonance" not in base)
check("base status line reads PREP v17", base.count(STATUS_OLD) == 1)
check("collapse-margin anchor is unique", base.count(ANCHOR) == 1)
check("base delta tail is unique", base.count(DELTA_OLD_TAIL) == 1)
check("base row census reads 140", sum(1 for l in base.splitlines() if l.startswith("|")) == 140)
check("base line count reads 392", len(base.splitlines()) == 392)

new = base.replace(STATUS_OLD, STATUS_NEW, 1)
check("status token moved once", new.count(STATUS_NEW) == 1 and new.count(STATUS_OLD) == 0)

new = new.replace(ANCHOR, ANCHOR + "\n" + ROW, 1)
check("row inserted after the collapse-margin anchor", new.count(ROW) == 1)
check("anchor and row are adjacent", (ANCHOR + "\n" + ROW) in new)

new = new.replace(DELTA_OLD_TAIL, DELTA_OLD_TAIL + DELTA_NEW, 1)
check("v19 delta appended once", new.count("- **v19 (2026-10-15):**") == 1)
check("v18 delta text byte-held", base.count("- **v18 (2026-10-15):**") == 1 and "- **v18 (2026-10-15):**" in new)

# row-level hold: every base row survives, exactly one row is new
base_rows = [l for l in base.splitlines() if l.startswith("|")]
new_rows = [l for l in new.splitlines() if l.startswith("|")]
added = [r for r in new_rows if r not in base_rows]
missing = [r for r in base_rows if r not in new_rows]
check("no base row lost", missing == [])
check("exactly one row added", added == [ROW])
check("row census reads 141", len(new_rows) == 141)
check("line count reads 400", len(new.splitlines()) == 400)

# numbers-free: the definition cell of the new row carries no digit
defcell = ROW.split("|")[2]
check("new row definition cell is numbers-free", not any(ch.isdigit() for ch in defcell))

# ordering: the new row sits between collapse margin and FoS
order = [r.split("|")[1].strip() for r in new_rows if r.startswith("| ") or r.startswith("|")]
idx = [i for i, l in enumerate(new.splitlines()) if l == ROW][0]
check(
    "row sits between the collapse-margin and FoS rows",
    "collapse margin" in new.splitlines()[idx - 1] and "FoS (factor of safety)" in new.splitlines()[idx + 1],
)

NEW.write_text(new)
print(f"\n{len(checks)} checks, 0 fail")
print(f"candidate: {NEW}  md5 {hashlib.md5(new.encode()).hexdigest()}")
