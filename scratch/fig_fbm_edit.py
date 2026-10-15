#!/usr/bin/env python3
"""fig_fbm_edit: the fidelity band merge call edits (four files).

Two phases: every anchor verified across every file first, then the
edits apply and the files write. Any mismatch aborts before a write.

Sets:
  A. the map: row 12 closes merged; the status key gains the state;
     the spine list releases row 12; the unblock line takes the fold;
     delta v46 records the call.
  B. the figure-generation notes: the merge option reads taken.
  C. the eval-timeline register note: delta v8 records the fold.
  D. the seat page: the header and the closed index take the fold.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
NOTES = ROOT / "docs" / "reporting" / "figures" / "figure-generation-notes.md"
REG = ROOT / "docs" / "reporting" / "figures" / "eval-timeline" / "register-status.md"
SEAT = ROOT / "handovers" / "handover-2026-10-14-reporting-room-figures-images-diagrams.md"

EDITS = []

# ---- A. the map ----
EDITS.append((MAP,
    "| 12 | 16 | §4.1 | Fidelity band chart | \u27e8tbd\u27e9 | scoped | The fidelity probes. NR-012, NR-013 | Probe extracts and rows |",
    "| 12 | 16 | §4.1 | Fidelity band chart | \u27e8tbd\u27e9 | merged | The fidelity probes. NR-012, NR-013 | Merged into row 4, lane 3 (v46). Lane 3 carries the warm-vs-cold strain evidence, the core evidence of this row. The fix retired the warm false-reject premise (NR-013 ext2). No standalone plate builds. The slot frees. |"))

EDITS.append((MAP,
    "- **blocked** \u2014 waits on a recorded re-derivation.",
    "- **blocked** \u2014 waits on a recorded re-derivation.\n- **merged** \u2014 the content folds into another row. The slot frees."))

EDITS.append((MAP,
    "The protected spine (author seat): rows 2, 6, 7, 8, 9, 10 and 12. The\nparking set: rows 3, 14 and 17.",
    "The protected spine (author seat): rows 2, 6, 7, 8, 9 and 10. Row 12\nleft the spine at the merge into row 4 (v46). The parking set: rows 3,\n14 and 17."))

EDITS.append((MAP,
    "The fidelity band joins too. No number prints",
    "The fidelity band joins too (row 12 merged into row 4, v46). No number prints"))

map_v46 = (
    "\n- **v46 (2026-10-15):** the fidelity band chart folds into row 4 at the\n"
    "  figures seat (row 12 closes merged). The science-validator's feedback\n"
    "  audit routes the row: its premise moved when the rope-break fix\n"
    "  landed. No warm false-reject remains to band, and the post-fix warm\n"
    "  runs read honest rejects (NR-013 ext2). Lane 3 carries the\n"
    "  warm-vs-cold strain evidence, the core evidence of the row. The\n"
    "  figure-generation notes take the merge option as taken. The\n"
    "  eval-timeline register note takes delta v8. The slot frees, and the\n"
    "  spine protection releases with the merge. No plate byte moves.\n"
)
EDITS.append((MAP, "__TAIL__the one-line re-open. Next: the visual pass by Rod, then the fold.", map_v46))

# ---- B. the notes ----
EDITS.append((NOTES,
    "F3 can carry row 12 and free a slot.",
    "F3 can carry row 12 and free a slot. Taken at the figures seat (2026-10-15, map v46): row 12 closes merged. No standalone plate builds."))

# ---- C. the register note ----
reg_v8 = (
    "**Delta** v8 (2026-10-15): row 12, the fidelity band chart, folds into\n"
    "this plate (map v46, figures seat). Lane 3 carries the warm-vs-cold\n"
    "strain evidence, and NR-012 and NR-013 bind it. The fix retired the\n"
    "warm false-reject premise (NR-013 ext2). No standalone plate builds.\n"
    "No drawn row changes.\n\n"
)
EDITS.append((REG,
    "**Form note** (2026-10-15): swept at the v6 re-cut.",
    reg_v8 + "**Form note** (2026-10-15): swept at the v6 re-cut."))

# ---- D. the seat page ----
EDITS.append((SEAT,
    "the cite fixes and the placement label re-cut (2026-10-15).",
    "the cite fixes, the placement label re-cut and the fidelity band merge (2026-10-15)."))

seat_bullet = (
    "- The fidelity band merge call (2026-10-15): row 12 (the fidelity band\n"
    "  chart) folds into row 4 at map v46. Lane 3 carries the warm-vs-cold\n"
    "  strain evidence, and the fix retired the warm false-reject premise.\n"
    "  The slot frees. Receipt\n"
    "  `docs/reporting/room-responses/figures-images-diagrams-2026-10-15-fidelity-band-merge.md`.\n"
    "  Evidence `scratch/fig_fbm_*` plus logs.\n"
)
EDITS.append((SEAT,
    "(evidence index)\n\n- The placement label re-cut (2026-10-15):",
    "(evidence index)\n\n" + seat_bullet + "\n- The placement label re-cut (2026-10-15):"))


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
