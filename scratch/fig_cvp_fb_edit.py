#!/usr/bin/env python3
"""fig_cvp_fb_edit: the convergence counter-read fold-back edits (four files).

Two phases: every anchor verified across all four files first, then the
edits apply and the files write. Any mismatch aborts before a write.

Sets:
  A. the map: the row-16 cell takes the closure; delta v49 appends.
  B. the register-status note: the gates section reads closed; delta v2.
  C. the SPEC: the rounds lines take the closure; R3 holds the visual
     pass alone.
  D. the seat page: the header, open item 2 and the next-action line
     take the closure.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
REG = ROOT / "docs" / "reporting" / "figures" / "convergence" / "register-status.md"
SPEC = ROOT / "docs" / "reporting" / "figures" / "convergence" / "SPEC.md"
SEAT = (ROOT / "handovers"
        / "handover-2026-10-14-reporting-room-figures-images-diagrams.md")

# ---------------------------------------------------------------- A. the map
MAP_CELL_OLD = (
    "The reject labels take the NR-055 forms. Next: the counter-reads "
    "(the aero F-VALUE and the science register read), then the visual "
    "pass by Rod |")
MAP_CELL_NEW = (
    "The reject labels take the NR-055 forms. The counter-reads close "
    "clean: F-VALUE PASS (`24111e5` + `7956a39`, 39 + 2 checks) and the "
    "register read (`1b09190` + `c15af17`, 97 checks). Next: the visual "
    "pass by Rod, then the fold |")

V48_TAIL = ("  byte-identical across three locations. Next: the counter-reads, then\n"
            "  the visual pass by Rod.\n")
V49 = (
    "\n- **v49 (2026-10-15):** the convergence counter-reads fold back (row 16).\n"
    "  F-VALUE closes clean at the aero seat (`24111e5` + `7956a39`): the\n"
    "  census reads 39 checks and the repro walk 2 checks, 0 fail, and the\n"
    "  drawn geometry inverts to the counts, the star and the curve\n"
    "  vertices. The register read closes clean at the science seat\n"
    "  (`1b09190` + `c15af17`): 97 checks, 0 fail, with NR-042, NR-045,\n"
    "  NR-046 and NR-015 backing the remaining drawn tokens. The seed-form\n"
    "  query resolves. The kit's counter-read set is complete, and the\n"
    "  visual pass by Rod stands next. The register-status note takes delta\n"
    "  v2 and the SPEC rounds take the closure. No plate byte moves.\n")

# --------------------------------------------------- B. the register-status
GATES_OLD = (
    "## Validator gates\n"
    "\n"
    "The counter-reads open at the seats: F-VALUE at the aero seat, the\n"
    "register read at the science seat. A fresh F-VALUE runs at the\n"
    "sign-off commit. Any render or pin move needs a new pass.\n")
GATES_NEW = (
    "## Validator gates\n"
    "\n"
    "The counter-reads closed clean (2026-10-15). F-VALUE ran at the aero\n"
    "seat (`24111e5` + `7956a39`): a census of 39 checks and 2 repro\n"
    "checks, 0 fail. The register read ran at the science seat (`1b09190`\n"
    "+ `c15af17`): 97 checks, 0 fail. The kit's counter-read set is\n"
    "complete. The visual pass by Rod stands next. Any render or pin move\n"
    "needs a new pass.\n")

REG_V1_TAIL = ("**Delta** v1 (2026-10-15): created with the kit landing. The build\n"
               "carries the recorded merge of map row 16 (v47) and the NR-055 label\n"
               "set.\n")
REG_V2 = (
    "\n**Delta** v2 (2026-10-15): the counter-reads close clean. The aero\n"
    "F-VALUE census reads 39 checks and 2 repro checks, 0 fail. The\n"
    "register read reads 97 checks, 0 fail. The seed-form query resolves\n"
    "and the plate prints no generation tag. The kit's counter-read set is\n"
    "complete, and the visual pass by Rod stands next.\n")

# ------------------------------------------------------------- C. the SPEC
SPEC_R2_OLD = (
    "- **R2** this landing: the scripted figure against the committed\n"
    "  inputs walks F-CITE, F-REPRO and F-LABEL. The seats take their pass.\n"
    "  Deltas land.\n")
SPEC_R2_NEW = (
    "- **R2** this landing: the scripted figure against the committed\n"
    "  inputs walks F-CITE, F-REPRO and F-LABEL. The seats take their pass.\n"
    "  Deltas land. The counter-reads close clean at both seats (the\n"
    "  register-status v2 record).\n")
SPEC_R3_OLD = (
    "- **R3** the final pass. @aero-validator runs F-VALUE at the sign-off\n"
    "  commit. Rod does the visual pass. Status moves to approved.\n")
SPEC_R3_NEW = (
    "- **R3** the final pass. Rod does the visual pass. Status moves to\n"
    "  approved.\n")

# -------------------------------------------------------- D. the seat page
SEAT_HEAD_OLD = ("the convergence seat and the convergence build "
                 "(2026-10-15).")
SEAT_HEAD_NEW = ("the convergence seat, the convergence build and its "
                 "counter-read closures (2026-10-15).")

SEAT_ITEM_OLD = (
    "checks, 0 fail, and F-REPRO holds across three locations. Next: the\n"
    "counter-reads (the aero F-VALUE and the science register read), then\n"
    "the visual pass by Rod.")
SEAT_ITEM_NEW = (
    "checks, 0 fail, and F-REPRO holds across three locations. The\n"
    "counter-reads close clean (the aero F-VALUE and the register read).\n"
    "Next: the visual pass by Rod.")

SEAT_FOOT_OLD = ("**Next action:** the visual pass by Rod (the winner "
                 "plate, the F1 plate and rows 4 to 7). The convergence "
                 "figure joins after its counter-reads.")
SEAT_FOOT_NEW = ("**Next action:** the visual pass by Rod (the winner "
                 "plate, the F1 plate, rows 4 to 7 and the convergence "
                 "figure).")


def main() -> int:
    mp = MAP.read_text(encoding="utf-8")
    rg = REG.read_text(encoding="utf-8")
    sp = SPEC.read_text(encoding="utf-8")
    st = SEAT.read_text(encoding="utf-8")

    fails = []
    for name, text, anchor, n in (
            ("map cell", mp, MAP_CELL_OLD, 1),
            ("register gates", rg, GATES_OLD, 1),
            ("register v1 tail", rg, REG_V1_TAIL, 1),
            ("spec r2", sp, SPEC_R2_OLD, 1),
            ("spec r3", sp, SPEC_R3_OLD, 1),
            ("seat head", st, SEAT_HEAD_OLD, 1),
            ("seat item", st, SEAT_ITEM_OLD, 1),
            ("seat foot", st, SEAT_FOOT_OLD, 1)):
        c = text.count(anchor)
        if c != n:
            fails.append(f"{name} anchor count {c} (want {n})")
    if not mp.endswith(V48_TAIL):
        fails.append("map tail (v48 ending) not found")
    if mp.count("**v49 (2026-10-15):**") != 0:
        fails.append("map v49 already present")
    if rg.count("**Delta** v2 (2026-10-15):") != 0:
        fails.append("register v2 already present")
    if fails:
        print("ABORT, anchors failed:")
        for f in fails:
            print("  " + f)
        return 1

    mp = mp.replace(MAP_CELL_OLD, MAP_CELL_NEW)
    mp = mp.replace(V48_TAIL, V48_TAIL + V49)
    rg = rg.replace(GATES_OLD, GATES_NEW)
    rg = rg.replace(REG_V1_TAIL, REG_V1_TAIL + REG_V2)
    sp = sp.replace(SPEC_R2_OLD, SPEC_R2_NEW)
    sp = sp.replace(SPEC_R3_OLD, SPEC_R3_NEW)
    st = st.replace(SEAT_HEAD_OLD, SEAT_HEAD_NEW)
    st = st.replace(SEAT_ITEM_OLD, SEAT_ITEM_NEW)
    st = st.replace(SEAT_FOOT_OLD, SEAT_FOOT_NEW)

    assert mp.count(MAP_CELL_NEW) == 1
    assert mp.count("**v49 (2026-10-15):**") == 1
    assert rg.count(GATES_NEW) == 1
    assert rg.count("**Delta** v2 (2026-10-15):") == 1
    assert sp.count(SPEC_R3_NEW) == 1
    assert sp.count("runs F-VALUE at the sign-off") == 0
    assert st.count(SEAT_ITEM_NEW) == 1
    assert st.count(SEAT_FOOT_NEW) == 1

    MAP.write_text(mp, encoding="utf-8")
    REG.write_text(rg, encoding="utf-8")
    SPEC.write_text(sp, encoding="utf-8")
    SEAT.write_text(st, encoding="utf-8")
    print("edits applied: map cell + v49; register gates + v2; spec R2/R3; "
          "seat head/item/foot")
    return 0


if __name__ == "__main__":
    sys.exit(main())
