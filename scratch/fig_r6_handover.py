#!/usr/bin/env python3
"""fig-r6 handover refresh — the figures seat page takes the round-6 closure.

Run from the repo root: /usr/bin/python3 scratch/fig_r6_handover.py
"""
import sys
from pathlib import Path

P = Path("handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md")
t = P.read_text(encoding="utf-8")

EDITS = [
    # base line
    ("This page refreshed in the fetch-first form. The refresh records the v0.41 hero counter-read closure (2026-10-14).",
     "This page refreshed in the fetch-first form. This refresh records the round-6 hub-name retirement landing (2026-10-14)."),
    # open items
    ("## Open items\n\n1. **The visual pass by Rod.** Rows 4 to 7 (the eval-timeline, k-basis,\n   ring-utilisation and twist-limit plates) and the machine hero (row 10)\n   stand at F-VALUE pass or closure. The hero seat reads §3.3, ahead of the\n   plates. It moves earlier in one line if the room calls.",
     "## Open items\n\n"
     "1. **The corner build (map row 23).** Science-validator signed NR-051 (`8855d9a`). The four corner picks read in `scratch/fig_cg_picks.py`. The family-mode build opens next at this seat.\n\n"
     "2. **The aero counter-read of the round-6 re-cuts.** The five plates, the three caption kits, the sweep set and the NR-042 footer join read at the aero desk. The receipt: `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-round6-hub-retirement-recut.md`.\n\n"
     "3. **The visual pass by Rod.** Rows 4 to 7 (the eval-timeline, k-basis, ring-utilisation and twist-limit plates) and the machine hero (row 10) stand at F-VALUE pass or closure. The plates now carry the round-6 top forms. The pass reads the v0.46 bytes. The hero seat reads §3.3, ahead of the plates. It moves earlier in one line if the room calls."),
    # closed prepend
    ("## Closed, last (evidence index)\n\n- The v0.41 hero counter-read closes clean at the aero seat (2026-10-14).",
     "## Closed, last (evidence index)\n\n"
     "- The round-6 hub-name retirement lands (2026-10-14). The five plates re-cut and the three caption kits take the top forms. The NR-042 footer join folds. Script `1af63fc`. The landing reads `45ed95a`. Receipt `docs/reporting/room-responses/figures-images-diagrams-2026-10-14-round6-hub-retirement-recut.md`. Evidence `scratch/fig_r6_edit.py`, `fig_r6_driver.py`, `fig_r6_pins.py`, `fig_r6_records.py`, `fig_r6_fix1.py` and `fig_r6_check.py` plus the run logs and the md5 tables.\n\n"
     "- The v0.41 hero counter-read closes clean at the aero seat (2026-10-14)."),
    # next action
    ("**Owner:** @fig-img-diagrams (figures-images-diagrams). **Next action:** hold for\nthe visual pass by Rod on rows 4 to 7 and the hero, then the folds.",
     "**Owner:** @fig-img-diagrams (figures-images-diagrams). **Next action:** the corner build (row 23) on the signed NR-051 row. The aero counter-read of the round-6 re-cuts runs first at its desk. The visual pass by Rod follows."),
]

bad = [f"count {t.count(o)}: {o[:80]!r}" for o, _ in EDITS if t.count(o) != 1]
if bad:
    print("FAIL:"); print("\n".join(bad)); sys.exit(1)
for o, n in EDITS:
    t = t.replace(o, n, 1)
P.write_text(t, encoding="utf-8")
print("handover refreshed (4 edits).")
