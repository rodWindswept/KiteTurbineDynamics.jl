#!/usr/bin/env python3
"""fig_et_pl_fb_edit: the counter-read fold-back edits (six files).

Two phases: every anchor verified across every file first, then the
edits apply and the files write. Any mismatch aborts before a write.

Sets:
  A. the re-cut receipt takes the corrected count (two drawn strings).
  B. the map takes the closure (row 4 tail, delta v45).
  C. the register note takes delta v7.
  D. the seat page takes the closure (index, open item, next action).
  E. the standing check set advances its two closure-line expectations.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RC = ROOT / "docs" / "reporting" / "room-responses" / "figures-images-diagrams-2026-10-15-eval-timeline-placement-label-recut.md"
MAP = ROOT / "docs" / "reporting" / "figures" / "figure-map.md"
REG = ROOT / "docs" / "reporting" / "figures" / "eval-timeline" / "register-status.md"
SEAT = ROOT / "handovers" / "handover-2026-10-14-reporting-room-figures-images-diagrams.md"
CHK = ROOT / "scratch" / "fig_et_pl_check.py"

EDITS = []

# ---- A. the re-cut receipt ----
EDITS.append((RC,
    "form. One drawn string moves. No drawn value moves.",
    "form. Two drawn strings move: the lane-3 label and the footer stamp\n"
    "refresh. No drawn value moves."))

EDITS.append((RC,
    "- The head comment sweeps to the top form, and the round-6 comment hold",
    "- The footer stamp refreshes from `1af63fc` to `a269636`. The stamp is\n"
    "  the only digit-bearing move, and it carries a commit hash, not a\n"
    "  value.\n"
    "- The head comment sweeps to the top form, and the round-6 comment hold"))

EDITS.append((RC,
    "52 strings, with one\n  form swapped.",
    "52 strings, with two\n  forms refreshed (the label and the stamp)."))

EDITS.append((RC,
    "The label flip is the only drawn move. No value moves.",
    "The drawn moves are the label flip and the stamp refresh. No value\n"
    "  moves."))

# ---- B. the map ----
EDITS.append((MAP,
    "Next: the aero counter-read of the re-cut, then the visual pass by Rod, then the fold",
    "The counter-read closes clean (`8e33253`, 35 checks). The census reads two drawn strings, the label and the stamp refresh. Next: the visual pass by Rod, then the fold"))

map_v45 = (
    "\n- **v45 (2026-10-15):** the placement label re-cut counter-read folds\n"
    "  back (row 4). The read closes (`1bfb09e` + `8e33253`, 35 checks): the\n"
    "  census reads two drawn strings, the label and the footer stamp\n"
    "  refresh, one box and zero values. The manifest pins recompute. F-REPRO\n"
    "  holds at four locations. The register join verifies against NR-013\n"
    "  ext2. The boundary reads no draft byte. The figures checker re-runs\n"
    "  at 63 checks, 0 fail. The re-cut receipt takes the corrected count.\n"
    "  The gate-map band holds as the campaign as-run read, closed-held with\n"
    "  the one-line re-open. Next: the visual pass by Rod, then the fold.\n"
)
EDITS.append((MAP, "__TAIL__then the visual pass by Rod.", map_v45))

# ---- C. the register note ----
reg_v7 = (
    "**Delta** v7 (2026-10-15): the re-cut counter-read closes (aero-validator,\n"
    "`1bfb09e`, readback `8e33253`, 35 checks). The census reads two drawn\n"
    "strings, the label and the stamp refresh. No value moves. The pins and\n"
    "the four-location F-REPRO verify.\n\n"
)
EDITS.append((REG,
    "**Form note** (2026-10-15): swept at the v6 re-cut.",
    reg_v7 + "**Form note** (2026-10-15): swept at the v6 re-cut."))

# ---- D. the seat page ----
EDITS.append((SEAT,
    "  record. Receipt `docs/reporting/room-responses/figures-images-diagrams-2026-10-15-eval-timeline-placement-label-recut.md`.\n  Evidence `scratch/fig_et_pl_*` plus logs.",
    "  record. The counter-read closes (`8e33253`, 35 checks). Receipt\n"
    "  `docs/reporting/room-responses/figures-images-diagrams-2026-10-15-eval-timeline-placement-label-recut.md`,\n"
    "  fold-back\n"
    "  `docs/reporting/room-responses/figures-images-diagrams-2026-10-15-eval-timeline-recut-closure-foldback.md`.\n"
    "  Evidence `scratch/fig_et_pl_*` plus logs."))

EDITS.append((SEAT,
    "the placement re-cut: the aero counter-read opens, then the visual pass.",
    "the placement re-cut: the counter-read closes (`8e33253`, 35 checks).\n"
    "Next: the visual pass by Rod, then the fold."))

EDITS.append((SEAT,
    "**Next action:** the visual pass by Rod (the corner grid, the winner plate, the F1 plate and rows 4 to 7).",
    "**Next action:** the visual pass by Rod (the winner plate, the F1 plate and rows 4 to 7)."))

# ---- E. the standing check set ----
EDITS.append((CHK,
    'check("seat: open item note", "Row 4 carries the placement re-cut: the aero counter-read opens, then the visual pass." in seat, True)',
    'check("seat: open item note", "Row 4 carries the placement re-cut: the counter-read closes (`8e33253`, 35 checks)." in seat, True)'))

EDITS.append((CHK,
    'check("map: row tail", "Next: the aero counter-read of the re-cut, then the visual pass by Rod, then the fold" in mpn, True)',
    'check("map: row tail", "The counter-read closes clean (`8e33253`, 35 checks). The census reads two drawn strings, the label and the stamp refresh. Next: the visual pass by Rod, then the fold" in mpn, True)'))


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
