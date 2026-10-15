#!/usr/bin/env python3
"""fig_et_pl_docs_edit: the placement re-cut records edit (four files).

Two phases: every anchor is verified across every file first (all
failures printed), then the edits apply and the files write. Any anchor
mismatch aborts before a single file is written.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "docs" / "reporting" / "figures" / "eval-timeline"
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
SEAT = ROOT / "handovers" / "handover-2026-10-14-reporting-room-figures-images-diagrams.md"

EDITS = []

# ---------------- register-status.md ----------------
reg_new_para = (
    "The lane-3 label takes the landed form at this re-cut. The label reads\n"
    "\"rope-break gate off during relax\". The 2026-09-16 placement landed in\n"
    "the code at `2bf76a3` (aero-validator). The gate-map band and the foot\n"
    "line hold as the a89642b record."
)
EDITS.append((KIT / "register-status.md",
    "NR-042 is signed (`8c278a5`).\n\n## Drawn precision",
    "NR-042 is signed (`8c278a5`).\n\n" + reg_new_para + "\n\n## Drawn precision"))

form_note_old = (
    "**Form note** (2026-10-15): one script comment at the head holds\n"
    "the old ring name until the next re-render sweep. No drawn text is\n"
    "affected."
)
form_note_new = (
    "**Delta** v6 (2026-10-15): the placement lands. The lane-3 label takes\n"
    "the landed form (the 2026-09-16 placement, `2bf76a3`, aero-validator).\n"
    "The held head comment sweeps to the top form. The pins refresh at this\n"
    "re-cut (script `a269636`). No drawn value moves.\n\n"
    "**Form note** (2026-10-15): swept at the v6 re-cut. The head comment\n"
    "reads \"ground ring and top ring\". No drawn text is affected."
)
EDITS.append((KIT / "register-status.md", form_note_old, form_note_new))

# ---------------- SPEC.md ----------------
spec_bullet_old = (
    "- The ruling-mode curve prints under the condition-run label only. The\n"
    "  label names the placement as not yet in the code. No label claims the\n"
    "  machine would pass."
)
spec_bullet_new = (
    "- The ruling-mode curve prints under the condition-run label only. The\n"
    "  label names the placement, landed in the code at `2bf76a3`. No label\n"
    "  claims the machine would pass."
)
EDITS.append((KIT / "SPEC.md", spec_bullet_old, spec_bullet_new))

spec_open_old = (
    "1. **Decision 5:** the window-only rope-break placement call sits with\n"
    "   @user. That ruling changes what lane 3 draws. The labels hold the\n"
    "   \"not yet in the code\" form until then."
)
spec_open_new = (
    "1. **Closed:** the window-only rope-break placement call. The placement\n"
    "   landed in the code at `2bf76a3` (aero-validator). The lane-3 label takes\n"
    "   the landed form. The gate-map band holds as the a89642b record."
)
EDITS.append((KIT / "SPEC.md", spec_open_old, spec_open_new))

spec_v3 = (
    "\n\n- v3 (2026-10-15): the placement lands (`2bf76a3`). The lane-3 label\n"
    "  reads \"rope-break gate off during relax\". The head comment sweeps to the\n"
    "  top form. No drawn value moves.\n"
)
EDITS.append((KIT / "SPEC.md", "__TAIL__No drawn value moves.", spec_v3))

# ---------------- figure-map.md ----------------
map_row_old = (
    "The round-6 counter-read closes clean (`3038656`, 136 checks). Next: the visual pass by Rod, then the fold"
)
map_row_new = (
    "The round-6 counter-read closes clean (`3038656`, 136 checks). The placement label re-cut lands (script `a269636`): the lane-3 label takes the landed form (`2bf76a3`). The gate-map band and the foot line hold as the a89642b record. The captions hold with them. Next: the aero counter-read of the re-cut, then the visual pass by Rod, then the fold"
)
EDITS.append((MAP, map_row_old, map_row_new))

map_v44 = (
    "\n- **v44 (2026-10-15):** the placement label re-cut lands (row 4). The\n"
    "  rope-break placement fix lands in the code (`2bf76a3`, aero-validator).\n"
    "  The lane-3 label takes the landed form: \"rope-break gate off during\n"
    "  relax\". The held head comment sweeps at this build. The gate-map band,\n"
    "  the foot line and the captions hold as the a89642b record. Script\n"
    "  `a269636`, and the outputs and the records ride this commit. Three full\n"
    "  runs byte-identical across all five outputs. Next: the aero counter-read\n"
    "  of the re-cut, then the visual pass by Rod.\n"
)
EDITS.append((MAP, "__TAIL__plate byte moves.", map_v44))

# ---------------- seat page ----------------
seat_head_old = ("the term gate, the counter-reads and the cite fixes (2026-10-15).")
seat_head_new = ("the term gate, the counter-reads, the cite fixes and the placement label re-cut (2026-10-15).")
EDITS.append((SEAT, seat_head_old, seat_head_new))

seat_open_old = "The plates carry the round-6 top forms and the relabel."
seat_open_new = (
    "The plates carry the round-6 top forms and the relabel. Row 4 carries\n"
    "the placement re-cut: the aero counter-read opens, then the visual pass."
)
EDITS.append((SEAT, seat_open_old, seat_open_new))

seat_closed_old = "## Closed, last (evidence index)\n\n- The corner-grid reads fold back (2026-10-15):"
seat_closed_new = (
    "## Closed, last (evidence index)\n\n"
    "- The placement label re-cut (2026-10-15): the lane-3 label takes the\n"
    "  landed form (the rope-break placement fix lands at `2bf76a3`, script\n"
    "  `a269636`). The gate-map band and the foot line hold as the a89642b\n"
    "  record. Receipt `docs/reporting/room-responses/figures-images-diagrams-2026-10-15-eval-timeline-placement-label-recut.md`.\n"
    "  Evidence `scratch/fig_et_pl_*` plus logs.\n\n"
    "- The corner-grid reads fold back (2026-10-15):"
)
EDITS.append((SEAT, seat_closed_old, seat_closed_new))


def main() -> int:
    # phase 1: verify every anchor across every file.
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
            problems.append(f"{path.name}: anchor {old[:60]!r}... count={n}")
    if problems:
        print("PHASE 1 FAILED:")
        for p in problems:
            print("  " + p)
        return 1
    print("phase 1: all anchors verified (1 match each)")

    # phase 2: apply and write.
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
