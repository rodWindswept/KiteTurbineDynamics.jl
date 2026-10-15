#!/usr/bin/env python3
"""fig_cv_edit: the convergence two-panel seat edits (three files).

Two phases: every anchor verified across every file first, then the
edits apply and the files write. Any mismatch aborts before a write.

Sets:
  A. the map: row 16 takes the two-panel seat; it moves to planned;
     delta v47 records the seating.
  B. the figure-generation notes: the merge line reads seated.
  C. the seat page: the header and the open items take the build.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
NOTES = ROOT / "docs" / "reporting" / "figures" / "figure-generation-notes.md"
SEAT = ROOT / "handovers" / "handover-2026-10-14-reporting-room-figures-images-diagrams.md"

EDITS = []

# ---- A. the map ----
row16_old = (
    "| 16 | 8 | \u00a73.2 | Convergence, three islands | \u27e8tbd\u27e9 | proposed | "
    "The running-best series. `convergence.csv` | An extract and rows for any printed value |"
)
row16_new = (
    "| 16 | 8 | \u00a73.2 | Convergence and the status mix (two panels) | \u27e8tbd\u27e9 | planned | "
    "The aero series extract (`scratch/av_conv_series.csv`, `9dd453d`). NR-054. "
    "The status mix reads the three island telemetry files (generations 0 to 30) | "
    "Seated (v47) as the recorded merge, \"first feasibility, then mass\": panel 1, the pooled "
    "status mix. Panel 2, the three running-best curves. The series extract lands (`9dd453d`), "
    "and NR-054 signs (science-validator, `441b9c7`). Next: the SPEC then the generator at the "
    "figures seat. The reject labels ride the 301 print-or-park call. |"
)
EDITS.append((MAP, row16_old, row16_new))

map_v47 = (
    "\n- **v47 (2026-10-15):** the convergence two-panel seat lands (row 16).\n"
    "  The series extract from the aero seat (`9dd453d`) and NR-054\n"
    "  (science-validator, `441b9c7`) close the row's gate (an extract and\n"
    "  rows for any printed value). The row takes the recorded merge: the\n"
    "  F4(b) status mix and the convergence series become one two-panel\n"
    "  figure, \"first feasibility, then mass\". It moves to `planned`. The\n"
    "  figure-generation notes take the seating note. Next: the SPEC then\n"
    "  the generator at this seat. The reject labels ride the 301\n"
    "  print-or-park call. No plate byte moves.\n"
)
EDITS.append((MAP, "__TAIL__spine protection releases with the merge. No plate byte moves.", map_v47))

# ---- B. the notes ----
EDITS.append((NOTES,
    "Merge. F4 panel (b) and F5 make one two-panel figure: \"first feasibility, then mass\". This saves a slot.",
    "Merge. F4 panel (b) and F5 make one two-panel figure: \"first feasibility, then mass\". This saves a slot.\n\n"
    "Seated at map v47 (2026-10-15): row 16 takes the two-panel form. NR-054 signs the series. "
    "The extract lands at `9dd453d`."))

# ---- C. the seat page ----
EDITS.append((SEAT,
    "the cite fixes, the placement label re-cut and the fidelity band merge (2026-10-15).",
    "the cite fixes, the placement label re-cut, the fidelity band merge and the convergence seat (2026-10-15)."))

seat_item2 = (
    "It moves earlier in one line if the room calls.\n"
    "\n"
    "2. **The convergence two-panel seat (row 16).** The seat lands at map\n"
    "v47: panel 1, the status mix; panel 2, the running-best curves, from\n"
    "the aero extract (`9dd453d`) and NR-054. The build reads next at this\n"
    "seat: the SPEC, then the generator. The reject labels wait on the 301\n"
    "print-or-park call.\n"
)
EDITS.append((SEAT, "It moves earlier in one line if the room calls.", seat_item2))


def main() -> int:
    problems = []
    texts = {}
    for path, old, new in EDITS:
        t = texts.get(path)
        if t is None:
            t = path.read_text(encoding="utf-8")
            texts[path] = t
        if old.startswith("__TAIL__"):
            frag = old[len("__TAIL__"):]
            ok = t.rstrip().endswith(frag)
            n = 1 if ok else 0
        else:
            n = t.count(old)
        if n != 1:
            problems.append(f"{path.name}: anchor {old[:60]!r} count={n}")
    if problems:
        print("PHASE 1 FAILED:")
        for p in problems:
            print("  " + p)
        return 1
    print("phase 1: all anchors verified (1 match each)")

    for path, old, new in EDITS:
        t = texts[path]
        if old.startswith("__TAIL__"):
            t = t.rstrip("\n") + "\n" + new
        else:
            t = t.replace(old, new)
        texts[path] = t
    for path in dict.fromkeys(p for p, _, _ in EDITS):
        path.write_text(texts[path], encoding="utf-8")
        print(f"written: {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
