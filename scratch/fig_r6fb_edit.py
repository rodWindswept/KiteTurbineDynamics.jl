#!/usr/bin/env python3
"""fig r6 fold-back edits: the map closure fold-back, delta v38, the two
kit form notes, and the seat page refresh. Assert-count edits; aborts
without writing on any mismatch.

Run: /usr/bin/python3 scratch/fig_r6fb_edit.py    (repo root)
"""
import sys
from pathlib import Path

MAP = Path("docs/reporting/figures/figure-map.md")
ET = Path("docs/reporting/figures/eval-timeline/register-status.md")
HERO = Path("docs/reporting/figures/machine-winner-hero/register-status.md")
SEAT = Path("handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md")

edits = [
    # --- the map: the five re-cut rows take the closure ---
    (MAP,
     "Next: the aero counter-read of the round-6 re-cut |",
     "The round-6 counter-read closes clean (`3038656`, 136 checks). "
     "Next: the visual pass by Rod |"),
    (MAP,
     "Next: the aero counter-read of the re-cut, then Rod's visual pass and the fold |",
     "The round-6 counter-read closes clean (`3038656`, 136 checks). "
     "Next: the visual pass by Rod, then the fold |"),
    (MAP,
     "The caption text takes the top forms. Next: the aero counter-read of the re-cut. "
     "The visual pass by Rod follows |",
     "The caption text takes the top forms. The round-6 counter-read closes clean "
     "(`3038656`, 136 checks). Next: the visual pass by Rod |"),
    (MAP,
     "The subtitle reads \"ground to top\". Next: the aero counter-read of the re-cut. "
     "The visual pass by Rod follows |",
     "The subtitle reads \"ground to top\". The round-6 counter-read closes clean "
     "(`3038656`, 136 checks). Next: the visual pass by Rod |"),
    (MAP,
     "The leader reads \"topmost ring R6\". Next: the aero counter-read of the re-cut. "
     "The visual pass by Rod follows |",
     "The leader reads \"topmost ring R6\". The round-6 counter-read closes clean "
     "(`3038656`, 136 checks). Next: the visual pass by Rod |"),
    # --- the map: row 23 records the open ---
    (MAP,
     "The objective row (NR-051) is signed (science-validator, `8855d9a`). "
     "The family-mode build opens at this seat |",
     "The objective row (NR-051) is signed (science-validator, `8855d9a`). "
     "The family-mode build opens: the extract mints (four genomes byte-exact, "
     "NR-051-gated; `extract-corner-grid.csv`). The generator build runs next |"),
    # --- the map: delta v38 ---
    (MAP,
     "  counter-read of the round-6 re-cuts. The corner build opens at this\n"
     "  seat on the NR-051 sign.\n",
     "  counter-read of the round-6 re-cuts. The corner build opens at this\n"
     "  seat on the NR-051 sign.\n"
     "\n"
     "- **v38 (2026-10-15):** the round-6 counter-read folds back at the\n"
     "  figures seat. The five re-cut rows (2, 4, 6, 7 and 10) take the\n"
     "  closure (`3038656`, 136 checks). They read the visual pass by Rod\n"
     "  as their next gate. The five generator comment form notes hold\n"
     "  for the next build of the two kits. Comments never print. A sweep\n"
     "  would move the two manifest script-sha pins and ask a fresh\n"
     "  reproduce walk. The corner grid opens (row 23): the extract mints\n"
     "  with the four genomes byte-exact and every NR-044 anchor gated.\n"
     "  The generator build runs next.\n"),
    # --- the kit form notes ---
    (ET,
     "**Delta** v5 (2026-10-14): the hub-name retirement (round-6 comment\n"
     "1). The lane-1 label reads \"\u03c9 top\" and the gate row reads \"top \u00b7\n"
     "tip \u00b7 Betz\". The drawn footer row list takes NR-042 at this build.\n"
     "No drawn value moves.\n",
     "**Delta** v5 (2026-10-14): the hub-name retirement (round-6 comment\n"
     "1). The lane-1 label reads \"\u03c9 top\" and the gate row reads \"top \u00b7\n"
     "tip \u00b7 Betz\". The drawn footer row list takes NR-042 at this build.\n"
     "No drawn value moves.\n"
     "\n"
     "**Form note** (2026-10-15): one script comment at the head holds\n"
     "the old ring name until the next re-render sweep. No drawn text is\n"
     "affected.\n"),
    (HERO,
     "byte-identical across all five outputs. No value moves.\n",
     "byte-identical across all five outputs. No value moves.\n"
     "\n"
     "**Form note** (2026-10-15): four script comments hold the old ring\n"
     "name until the next re-render sweep. No drawn text is affected.\n"),
    # --- the seat page ---
    (SEAT,
     "This refresh records the round-6 hub-name retirement landing (2026-10-14).",
     "This refresh records the round-6 counter-read fold-back and the "
     "corner-grid opening (2026-10-15)."),
    (SEAT,
     "1. **The corner build (map row 23).** Science-validator signed NR-051 "
     "(`8855d9a`). The four corner picks read in `scratch/fig_cg_picks.py`. "
     "The family-mode build opens next at this seat.",
     "1. **The corner build (map row 23).** Science-validator signed NR-051 "
     "(`8855d9a`). The extract pins at "
     "`docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv` "
     "(four genomes byte-exact). The generator build runs next at this seat."),
    (SEAT,
     "2. **The aero counter-read of the round-6 re-cuts.** The five plates, the "
     "three caption kits, the sweep set and the NR-042 footer join read at the "
     "aero desk. The receipt: "
     "`docs/reporting/room-responses/figures-images-diagrams-2026-10-14-round6-hub-retirement-recut.md`.\n"
     "\n"
     "3. **The visual pass by Rod.** Rows 4 to 7 (the eval-timeline, k-basis, "
     "ring-utilisation and twist-limit plates) and the machine hero (row 10) "
     "stand at F-VALUE pass or closure. The plates now carry the round-6 top "
     "forms. The pass reads the v0.46 bytes. The hero seat reads \u00a73.3, ahead "
     "of the plates. It moves earlier in one line if the room calls.",
     "2. **The visual pass by Rod.** The five re-cut rows (2, 4, 6, 7 and 10) "
     "and the k-basis plate (row 5) read the visual pass as their next gate "
     "(map v38). The plates carry the round-6 top forms. The hero seat reads "
     "\u00a73.3, ahead of the plates. It moves earlier in one line if the room calls."),
    (SEAT,
     "## Closed, last (evidence index)\n\n"
     "- The round-6 hub-name retirement lands (2026-10-14).",
     "## Closed, last (evidence index)\n\n"
     "- The round-6 counter-read closes clean at the aero desk (2026-10-15): "
     "136 checks, 0 fail, `9b414f3..0739ee7`. The five re-cut rows fold back "
     "(map v38) and read the visual pass next. The five generator comment "
     "form notes hold for the next build of the two kits. Receipt "
     "`docs/reporting/room-responses/figures-images-diagrams-2026-10-15-round6-counterread-foldback-and-corner-open.md`.\n"
     "\n"
     "- The corner grid opens (2026-10-15): the extract mints at "
     "`docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv` "
     "(four genomes byte-exact, NR-051-gated). Evidence "
     "`scratch/fig_cg_extract.py`, `scratch/fig_cg_extract_check.py` plus "
     "logs.\n"
     "\n"
     "- The round-6 hub-name retirement lands (2026-10-14)."),
    (SEAT,
     "**Owner:** @fig-img-diagrams (figures-images-diagrams). "
     "**Next action:** the corner build (row 23) on the signed NR-051 row. "
     "The aero counter-read of the round-6 re-cuts runs first at its desk. "
     "The visual pass by Rod follows.",
     "**Owner:** @fig-img-diagrams (figures-images-diagrams). "
     "**Next action:** the corner-grid generator build (row 23) on the pinned "
     "extract. The round-6 rebuild and the visual pass by Rod follow."),
]

ok = True

# group edits by file so each file writes once
by_file = {}
for path, old, new in edits:
    by_file.setdefault(path, []).append((old, new))

for path, pairs in by_file.items():
    text = path.read_text(encoding="utf-8")
    for old, new in pairs:
        n = text.count(old)
        if n != 1:
            print(f"FAIL: {path}: target occurs {n} times: {old[:90]!r}")
            ok = False
            continue
        text = text.replace(old, new)
    if ok:
        path.write_text(text, encoding="utf-8")
        print(f"edited: {path}")

print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
