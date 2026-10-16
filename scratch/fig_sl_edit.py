#!/usr/bin/env python3
"""fig_sl_edit: the scaling-ladder stage records edits (two files).

Two phases: every anchor verified across both files first, then the
edits apply and the files write. Any mismatch aborts before a write.

Sets:
  A. the map: row 24 mints (slug `scaling-ladder`, R2); delta v50
     appends.
  B. the seat page: the header, open item 3 and the next-action line
     take the stage.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
SEAT = (ROOT / "handovers"
        / "handover-2026-10-14-reporting-room-figures-images-diagrams.md")

ROW24 = (
    "| 24 | \u27e8tbd\u27e9 | \u00a75 | The scaling ladder. The validated "
    "rung and the programme targets above it | `scaling-ladder` | R2 | "
    "The value-claims ledger section 4 (the rung seed, `aa76367`). "
    "`scripts/compute_seeds.jl` const RUNGS | The kit lands (script "
    "`4ebc385`): seven rungs at equal spacing, the validated rung solid, "
    "the six programme targets open plus label, no value axis. The "
    "in-script set reads 14 checks, 0 fail. F-REPRO reads byte-identical "
    "across three locations. Next: the counter-reads (aero, science), "
    "then the visual pass by Rod, then the fold |")

ROW23_TAIL = "The train is closed at this seat |"

V49_TAIL = ("v2 and the SPEC rounds take the closure. No plate byte "
            "moves.\n")

V50 = (
    "\n- **v50 (2026-10-16):** the scaling-ladder row mints and lands "
    "(row 24,\n  the close candidate). The room agreed one labelled close "
    "(\"Where this\n  goes\"), and the value-claims ledger section 4 "
    "seeded the rungs element\n  by element. The generator (`4ebc385`) "
    "draws the seven rungs at equal\n  spacing: the validated rung "
    "solid, the six programme targets open plus\n  label, no value "
    "axis. The outputs and the records ride this commit.\n  The "
    "in-script set reads 14 checks, 0 fail. F-REPRO stays "
    "byte-identical\n  across three locations. Next: the counter-reads, "
    "then the visual pass\n  by Rod, then the fold.\n")

SEAT_HEAD_OLD = ("the convergence build and its counter-read closures "
                 "(2026-10-15).")
SEAT_HEAD_NEW = ("the convergence build and its counter-read closures "
                 "(2026-10-15), and the scaling-ladder stage "
                 "(2026-10-16).")

SEAT_ITEM_ANCHOR = ("counter-reads close clean (the aero F-VALUE and "
                    "the register read).\nNext: the visual pass by Rod.\n")

SEAT_ITEM3 = (
    "3. **The scaling-ladder stage (the close candidate).** The kit "
    "lands at\n`docs/reporting/figures/scaling-ladder/` (generator "
    "`4ebc385`; map row\n24, delta v50). The in-script set reads 14 "
    "checks, 0 fail, and F-REPRO\nholds across three locations. Next: "
    "the counter-reads, then the visual\npass by Rod, then the fold.\n")

SEAT_FOOT_OLD = ("**Next action:** the visual pass by Rod (the winner "
                 "plate, the F1 plate, rows 4 to 7 and the convergence "
                 "figure).")
SEAT_FOOT_NEW = SEAT_FOOT_OLD + (" The scaling-ladder stage reads its "
                                 "counter-reads next.")


def main() -> int:
    mp = MAP.read_text(encoding="utf-8")
    st = SEAT.read_text(encoding="utf-8")

    fails = []
    if mp.count(ROW23_TAIL) != 1:
        fails.append(f"map row-23 tail count {mp.count(ROW23_TAIL)}")
    if mp.count(V49_TAIL) != 1:
        fails.append(f"map v49 tail count {mp.count(V49_TAIL)}")
    if mp.count("**v50 (2026-10-16):**") != 0:
        fails.append("map v50 already present")
    if mp.count("| planned |") != 1:
        fails.append(f"map planned count {mp.count('| planned |')}")
    if mp.count("| R2 |") != 11:
        fails.append(f"map R2 count {mp.count('| R2 |')}")
    if mp.count("| proposed |") != 6:
        fails.append(f"map proposed count {mp.count('| proposed |')}")
    if st.count(SEAT_HEAD_OLD) != 1:
        fails.append(f"seat head anchor count {st.count(SEAT_HEAD_OLD)}")
    if st.count(SEAT_ITEM_ANCHOR) != 1:
        fails.append(f"seat item anchor count "
                     f"{st.count(SEAT_ITEM_ANCHOR)}")
    if st.count(SEAT_FOOT_OLD) != 1:
        fails.append(f"seat foot anchor count {st.count(SEAT_FOOT_OLD)}")
    if fails:
        print("ABORT, anchors failed:")
        for f in fails:
            print("  " + f)
        return 1

    mp = mp.replace(ROW23_TAIL, ROW23_TAIL + "\n" + ROW24)
    mp = mp.replace(V49_TAIL, V49_TAIL + V50)
    st = st.replace(SEAT_HEAD_OLD, SEAT_HEAD_NEW)
    st = st.replace(SEAT_ITEM_ANCHOR, SEAT_ITEM_ANCHOR + "\n" + SEAT_ITEM3)
    st = st.replace(SEAT_FOOT_OLD, SEAT_FOOT_NEW)

    assert mp.count(ROW24) == 1
    assert mp.count("**v50 (2026-10-16):**") == 1
    assert mp.count("| planned |") == 1
    assert mp.count("| R2 |") == 12
    assert mp.count("| proposed |") == 6
    assert st.count(SEAT_ITEM3) == 1
    assert st.count(SEAT_FOOT_NEW) == 1

    MAP.write_text(mp, encoding="utf-8")
    SEAT.write_text(st, encoding="utf-8")
    print("edits applied: map row 24 + delta v50; seat page (3 sites)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
