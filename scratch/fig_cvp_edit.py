#!/usr/bin/env python3
"""fig_cvp_edit: the convergence build records edits (two files).

Two phases: every anchor verified across both files first, then the
edits apply and the files write. Any mismatch aborts before a write.

Sets:
  A. the map: row 16 takes the built state (slug `convergence`, R2);
     delta v48 appends.
  B. the seat page: the header, open item 2 and the next-action line
     take the build.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
SEAT = (ROOT / "handovers"
        / "handover-2026-10-14-reporting-room-figures-images-diagrams.md")

MAP_ROW_OLD = (
    "| 16 | 8 | \u00a73.2 | Convergence and the status mix (two panels) | "
    "\u27e8tbd\u27e9 | planned | The aero series extract "
    "(`scratch/av_conv_series.csv`, `9dd453d`). NR-054. The status mix "
    "reads the three island telemetry files (generations 0 to 30) | "
    "Seated (v47) as the recorded merge, \"first feasibility, then mass\": "
    "panel 1, the pooled status mix. Panel 2, the three running-best "
    "curves. The series extract lands (`9dd453d`), and NR-054 signs "
    "(science-validator, `441b9c7`). Next: the SPEC then the generator "
    "at the figures seat. The reject labels ride the 301 print-or-park "
    "call. |")

MAP_ROW_NEW = (
    "| 16 | 8 | \u00a73.2 | Convergence and the status mix (two panels) | "
    "`convergence` | R2 | The aero series extract "
    "(`scratch/av_conv_series.csv`, `9dd453d`). NR-054 and NR-055. The "
    "status mix reads the three island telemetry files (generations 0 "
    "to 30) | The build lands (script `0db99ac`): two panels, \"first "
    "feasibility, then mass\", 22 checks, 0 fail, and F-REPRO "
    "byte-identical across three locations. The reject labels take the "
    "NR-055 forms. Next: the counter-reads (the aero F-VALUE and the "
    "science register read), then the visual pass by Rod |")

V47_TAIL = ("  the generator at this seat. The reject labels ride the 301\n"
            "  print-or-park call. No plate byte moves.\n")

V48 = (
    "\n- **v48 (2026-10-15):** the convergence two-panel build lands (row 16).\n"
    "  The generator (`0db99ac`) draws the merged two-panel figure \"first\n"
    "  feasibility, then mass\". Panel 1 carries the pooled status mix with\n"
    "  the NR-055 reject split. Panel 2 carries the three island\n"
    "  running-best curves from the aero extract. The label set applies the\n"
    "  301 print ruling and the NR-055 forms. The row moves to R2 and the\n"
    "  slug `convergence` fills. The outputs and the records ride this\n"
    "  commit. The in-script set reads 22 checks, 0 fail. F-REPRO stays\n"
    "  byte-identical across three locations. Next: the counter-reads, then\n"
    "  the visual pass by Rod.\n")

SEAT_HEAD_OLD = ("the fidelity band merge and the convergence seat "
                 "(2026-10-15).")
SEAT_HEAD_NEW = ("the fidelity band merge, the convergence seat and the "
                 "convergence build (2026-10-15).")

SEAT_ITEM_OLD = (
    "2. **The convergence two-panel seat (row 16).** The seat lands at map\n"
    "v47: panel 1, the status mix; panel 2, the running-best curves, from\n"
    "the aero extract (`9dd453d`) and NR-054. The build reads next at this\n"
    "seat: the SPEC, then the generator. The reject labels wait on the 301\n"
    "print-or-park call.")

SEAT_ITEM_NEW = (
    "2. **The convergence two-panel build (row 16).** The build lands at\n"
    "map v48: the generator (`0db99ac`) and the kit\n"
    "`docs/reporting/figures/convergence/`. The in-script set reads 22\n"
    "checks, 0 fail, and F-REPRO holds across three locations. Next: the\n"
    "counter-reads (the aero F-VALUE and the science register read), then\n"
    "the visual pass by Rod.")

SEAT_FOOT_OLD = ("**Next action:** the visual pass by Rod (the winner "
                 "plate, the F1 plate and rows 4 to 7).")
SEAT_FOOT_NEW = ("**Next action:** the visual pass by Rod (the winner "
                 "plate, the F1 plate and rows 4 to 7). The convergence "
                 "figure joins after its counter-reads.")


def main() -> int:
    mp = MAP.read_text(encoding="utf-8")
    st = SEAT.read_text(encoding="utf-8")

    fails = []
    if mp.count(MAP_ROW_OLD) != 1:
        fails.append(f"map row anchor count {mp.count(MAP_ROW_OLD)}")
    if mp.count("| planned |") != 2:
        fails.append(f"map planned count {mp.count('| planned |')}")
    if mp.count("| R2 |") != 10:
        fails.append(f"map R2 count {mp.count('| R2 |')}")
    if not mp.endswith(V47_TAIL):
        fails.append("map tail (v47 ending) not found")
    if mp.count("**v48 (2026-10-15):**") != 0:
        fails.append("map v48 already present")
    if st.count(SEAT_HEAD_OLD) != 1:
        fails.append(f"seat head anchor count {st.count(SEAT_HEAD_OLD)}")
    if st.count(SEAT_ITEM_OLD) != 1:
        fails.append(f"seat item anchor count {st.count(SEAT_ITEM_OLD)}")
    if st.count(SEAT_FOOT_OLD) != 1:
        fails.append(f"seat foot anchor count {st.count(SEAT_FOOT_OLD)}")
    if fails:
        print("ABORT, anchors failed:")
        for f in fails:
            print("  " + f)
        return 1

    mp = mp.replace(MAP_ROW_OLD, MAP_ROW_NEW)
    mp = mp.replace(V47_TAIL, V47_TAIL + V48)
    st = st.replace(SEAT_HEAD_OLD, SEAT_HEAD_NEW)
    st = st.replace(SEAT_ITEM_OLD, SEAT_ITEM_NEW)
    st = st.replace(SEAT_FOOT_OLD, SEAT_FOOT_NEW)

    assert mp.count(MAP_ROW_NEW) == 1
    assert mp.count("| planned |") == 1
    assert mp.count("| R2 |") == 11
    assert mp.count("**v48 (2026-10-15):**") == 1
    assert st.count(SEAT_ITEM_NEW) == 1
    assert st.count(SEAT_ITEM_OLD) == 0

    MAP.write_text(mp, encoding="utf-8")
    SEAT.write_text(st, encoding="utf-8")
    print("edits applied: map row 16 + delta v48; seat page (3 sites)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
