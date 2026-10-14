#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""The rows 6 and 7 F-VALUE closure records (figures seat, 2026-10-14).

The aero re-census (c30b2ca) closes F-VALUE on the fix commit
(ef36c6c), zero defects. This pass records the closure:

1. The figure-map cells for rows 6 and 7.
2. The ring and twist kit rounds lines (SPEC R2), with the
   counter-read history.
3. Map delta v31, ring SPEC delta v6, twist SPEC delta v5.
4. The seat handover: the Harris-3.5 thread closes; the open queue
   re-reads item-5 and the ring lead flag.

Two phases: verify every anchor count first, then write every file.

Run: /usr/bin/python3 scratch/fig_r67_edit.py
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
FIG = REPO / "docs/reporting/figures"
HANDOVER = REPO / "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md"

CLOSURE = ("The re-census at `c30b2ca` closes F-VALUE on the fix "
           "commit (`ef36c6c`) with zero defects.")

MAP_ROW6_OLD = "corrected interaction form). Next: F-VALUE at the sign-off commit |"
MAP_ROW6_NEW = ("corrected interaction form). %s. Next: the visual pass by "
                "Rod |" % CLOSURE)
MAP_ROW7_OLD = "the binding-limit title). Next: F-VALUE at the sign-off commit |"
MAP_ROW7_NEW = ("the binding-limit title). %s. Next: the visual pass by "
                "Rod |" % CLOSURE)

MAP_V31 = ("\n- **v31 (2026-10-14):** rows 6 and 7 take the F-VALUE closure. "
           "The\n  re-census lands at `c30b2ca` and closes on the fix commit "
           "(`ef36c6c`),\n  zero defects (85 checks). The re-pin, the levers "
           "rows and the review\n  copy all verify on the fixed bytes. The "
           "map cells and both kit rounds\n  lines take the closure. Next at "
           "both: the visual pass by Rod.\n")

R2_OLD = ("- **R2** the scripted figure against the real capture walks F-CITE, F-REPRO\n"
          "  and F-LABEL. The image-reader and the validators take their pass. Deltas\n"
          "  land.")
R2_NEW = (R2_OLD + "\n"
          "  The counter-read at `a3f4ae3` held the drawn values and routed the\n"
          "  appendix re-pin. The re-census at `c30b2ca` closes F-VALUE on the fix\n"
          "  commit (`ef36c6c`) with zero defects.")

RING_DELTA = ("\n- v6 (2026-10-14): the F-VALUE closure. The re-census at "
              "`c30b2ca` closes\n  F-VALUE on the fix commit (`ef36c6c`), zero "
              "defects (85 checks). The R2\n  rounds line takes the closure. "
              "No render moves.\n")
TWIST_DELTA = ("\n- v5 (2026-10-14): the F-VALUE closure. The re-census at "
               "`c30b2ca` closes\n  F-VALUE on the fix commit (`ef36c6c`), zero "
               "defects (85 checks). The R2\n  rounds line takes the closure. "
               "No render moves.\n")

HANDOVER_OPEN_OLD = (
    "1. **The Harris-3.5 thread.** The render deltas and the appendix re-pin\n"
    "   landed, and the F-VALUE counter-read passed with zero fail. The open part\n"
    "   is the aero re-census at the fix commit and the map closure on rows 6 and 7.\n"
    "   The review item sits in\n"
    "   `docs/reporting/feedback/2026-10-10-harris-review.md` section 3.5.\n"
    "\n"
    "2. **The item-5 lever-statistics extract.** Objective versus gene, gate\n"
    "   failures by gene, and penalty contributions across ok designs. The ask\n"
    "   sits in feedback item 5\n"
    "   (`docs/reporting/feedback/Feedback-message-1791925681590.md`).\n"
    "\n"
    "   The extract is file-disjoint from the draft chain, so it can fan out. It\n"
    "   lands behind the Harris deltas.\n"
    "\n"
    "3. **The ring lead flag.** The ring caption lead prints the capture form 15.033\n"
    "   (NR-021), not the report headline 15.0 (NR-009). One line flips it if the room\n"
    "   calls for the headline form there."
)
HANDOVER_OPEN_NEW = (
    "1. **The item-5 lever-statistics extract.** Objective versus gene, gate\n"
    "   failures by gene, and penalty contributions across ok designs. The ask\n"
    "   sits in feedback item 5\n"
    "   (`docs/reporting/feedback/Feedback-message-1791925681590.md`).\n"
    "\n"
    "   The extract is file-disjoint from the draft chain, so it can fan out.\n"
    "\n"
    "2. **The ring lead flag.** The ring caption lead prints the capture form 15.033\n"
    "   (NR-021), not the report headline 15.0 (NR-009). One line flips it if the room\n"
    "   calls for the headline form there."
)

HANDOVER_CLOSED_OLD = ("## Closed, last (evidence index)\n"
                       "\n"
                       "- The appendix re-pin and the levers rows 20/21")
HANDOVER_CLOSED_NEW = (
    "## Closed, last (evidence index)\n"
    "\n"
    "- The Harris-3.5 thread closes on rows 6 and 7. The re-census (`c30b2ca`)\n"
    "  clears the fix at `ef36c6c` (85 checks, 0 fail). The map cells and the\n"
    "  kit rounds lines take the closure at map v31. The review sits in\n"
    "  `docs/reporting/feedback/2026-10-10-harris-review.md` section 3.5. Receipt\n"
    "  `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-rows67-closure.md`.\n"
    "  Evidence `scratch/fig_r67_edit.py`, `scratch/fig_r67_check.py` plus `.log`.\n"
    "\n"
    "- The appendix re-pin and the levers rows 20/21"
)

HANDOVER_NEXT_OLD = ("**Owner:** @fig-img-diagrams (figures-images-diagrams). "
                     "**Next action:** open the\n"
                     "item-5 lever-statistics extract. Fold the map closure when "
                     "the aero re-census lands.")
HANDOVER_NEXT_NEW = ("**Owner:** @fig-img-diagrams (figures-images-diagrams). "
                     "**Next action:** open the\n"
                     "item-5 lever-statistics extract.")

EDITS = [
    (FIG / "figure-map.md", [
        (MAP_ROW6_OLD, MAP_ROW6_NEW, 1),
        (MAP_ROW7_OLD, MAP_ROW7_NEW, 1),
    ], ("closure records on a later\n  delta.\n", MAP_V31)),

    (FIG / "ring-utilisation/SPEC.md", [
        (R2_OLD, R2_NEW, 1),
    ], ("  legend and the caption. Script commit `671ab96`.\n", RING_DELTA)),

    (FIG / "twist-limit/SPEC.md", [
        (R2_OLD, R2_NEW, 1),
    ], ("  item 1.3). Script commit `671ab96`.\n", TWIST_DELTA)),

    (HANDOVER, [
        (HANDOVER_OPEN_OLD, HANDOVER_OPEN_NEW, 1),
        (HANDOVER_CLOSED_OLD, HANDOVER_CLOSED_NEW, 1),
        (HANDOVER_NEXT_OLD, HANDOVER_NEXT_NEW, 1),
    ]),
]


def main() -> int:
    errors = []
    for path, edits, *rest in EDITS:
        text = path.read_text()
        for old, new, count in edits:
            n = text.count(old)
            if n != count:
                errors.append("%s: anchor x%d (want %d): %r"
                              % (path.relative_to(REPO), n, count, old[:70]))
        if rest:
            tail_mark, tail_add = rest[0]
            if not text.endswith(tail_mark):
                errors.append("%s: file does not end with the expected tail: %r"
                              % (path.relative_to(REPO), tail_mark[-40:]))
    if errors:
        print("ANCHOR FAILURES:")
        for e in errors:
            print(" ", e)
        return 1
    for path, edits, *rest in EDITS:
        text = path.read_text()
        for old, new, count in edits:
            text = text.replace(old, new)
        if rest:
            text = text + rest[0][1]
        path.write_text(text)
        print("edited: %s  (%d edits)" % (path.relative_to(REPO), len(edits)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
