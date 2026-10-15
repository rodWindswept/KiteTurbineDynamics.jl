#!/usr/bin/env python3
"""fig corner-grid landing edits: the map row cells + delta v39, the SPEC
delta D10, the kit README state, and the seat page. Two-phase: verify
every anchor count across every file first, then apply all writes.

Run: /usr/bin/python3 scratch/fig_cg_landing_edit.py    (repo root)
"""
import sys
from pathlib import Path

MAP = Path("docs/reporting/figures/figure-map.md")
SPEC = Path("docs/reporting/figures/machine-renderer/SPEC.md")
README = Path("docs/reporting/figures/machine-corner-grid/README.md")
SEAT = Path("handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md")

edits = [
    # --- the map: row 23 cells ---
    (MAP,
     "`machine-corner-grid` | planned |",
     "`machine-corner-grid` | R2 |"),
    (MAP,
     "Picks recorded at `scratch/fig_cg_picks.py` (data commit `dd3cc6a`, "
     "run `a76c5e9`) |",
     "Picks recorded at `scratch/fig_cg_picks.py` (data commit `dd3cc6a`, "
     "run `a76c5e9`). The extract `corner-grid-extract-2026-10-15-picks` "
     "(`92ca9f5`) |"),
    (MAP,
     "The family-mode build opens: the extract mints (four genomes "
     "byte-exact, NR-051-gated; `extract-corner-grid.csv`). The generator "
     "build runs next |",
     "The build lands (`a4b4057`): four panels, all in-script checks pass, "
     "and the three-location F-REPRO walk reads byte-identical across all "
     "five outputs. Next: the aero counter-reads and the science register "
     "read, then the visual pass by Rod |"),
    # --- the map: delta v39 ---
    (MAP,
     "  with the four genomes byte-exact and every NR-044 anchor gated.\n"
     "  The generator build runs next.\n",
     "  with the four genomes byte-exact and every NR-044 anchor gated.\n"
     "  The generator build runs next.\n"
     "\n"
     "- **v39 (2026-10-15):** the corner grid builds (row 23). The family\n"
     "  mode, corner variant, lands under SPEC delta D10. Four panels in\n"
     "  the signed NR-051 order at one shared scale. The label strips\n"
     "  carry the corner, the tag and the objective at its 3 dp form.\n"
     "  Script `a4b4057`, and the outputs and the records ride this\n"
     "  commit. All in-script checks pass. The kit rendered in place\n"
     "  plus twice into scratch reads byte-identical across all five\n"
     "  outputs. Next: the aero counter-reads and the science register\n"
     "  read, then the visual pass by Rod.\n"),
    # --- the SPEC: delta D10 ---
    (SPEC,
     "byte class (2026-10-14).\n\n*Delta rounds:",
     "byte class (2026-10-14).\n"
     "\n"
     "- **D10 (2026-10-15):** the corner grid runs the family mode with\n"
     "  the NR-051 picks as its exemplar list (figure map row 23, the\n"
     "  founder ask of 2026-10-14). Four panels in the signed corner\n"
     "  order, one shared scale and window. Each label strip carries the\n"
     "  corner name, the identity tag and the search objective at its\n"
     "  signed 3 dp form. The layout reads left to right. The grid\n"
     "  claims geometry and typicality: the picks are typical machines,\n"
     "  not optima. The kit takes the emitted set of the strip and the\n"
     "  -dg/-zg PDF normalise (script `a4b4057`).\n"
     "\n"
     "*Delta rounds:"),
    # --- the kit README ---
    (README,
     "## State\n"
     "\n"
     "The extract pins (2026-10-15). The generator build runs next at the\n"
     "figures seat. The build follows the family-grid mode of the\n"
     "machine-renderer SPEC: four panels, one fixed scale, one label strip\n"
     "per panel, and the footer band.",
     "## State\n"
     "\n"
     "The generator lands (`a4b4057`). Four panels, one per corner, at one\n"
     "shared scale. All in-script checks pass, and the three-location\n"
     "F-REPRO walk reads byte-identical across all five outputs. Next: the\n"
     "counter-reads (aero F-CITE and F-VALUE, the science register read),\n"
     "then the visual pass by Rod.\n"
     "\n"
     "## Delivered files\n"
     "\n"
     "- `machine-corner-grid.png` / `.svg` / `.pdf` carry the plate.\n"
     "- `manifest.json` pins the extract, the knobs and the output hashes.\n"
     "- `checks.log` holds the GENERATE record."),
    # --- the seat page ---
    (SEAT,
     "1. **The corner build (map row 23).** Science-validator signed NR-051 "
     "(`8855d9a`). The extract pins at "
     "`docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv` "
     "(four genomes byte-exact). The generator build runs next at this seat.",
     "1. **The corner build (map row 23).** The generator lands (`a4b4057`): "
     "four panels, all checks pass, the three-location F-REPRO walk holds. "
     "The counter-reads queue next (aero F-CITE and F-VALUE, the science "
     "register read)."),
    (SEAT,
     "## Closed, last (evidence index)\n\n"
     "- The round-6 counter-read closes clean at the aero desk",
     "## Closed, last (evidence index)\n\n"
     "- The corner grid builds (2026-10-15): the generator lands at "
     "`a4b4057` (family mode, corner variant; SPEC delta D10). Four panels "
     "from the NR-051 picks, all checks pass, and the three-location "
     "F-REPRO walk reads byte-identical. Receipt "
     "`docs/reporting/room-responses/figures-images-diagrams-2026-10-15-corner-grid-generator.md`. "
     "Evidence `scratch/fig_cg_repro.md5` and the run logs.\n"
     "\n"
     "- The round-6 counter-read closes clean at the aero desk"),
    (SEAT,
     "**Next action:** the corner-grid generator build (row 23) on the "
     "pinned extract. The round-6 rebuild and the visual pass by Rod follow.",
     "**Next action:** the corner-grid counter-reads (row 23) on the "
     "delivered bytes. The visual pass by Rod follows."),
]

ok = True
texts = {}
for path, old, new in edits:
    if path not in texts:
        texts[path] = path.read_text(encoding="utf-8")
    n = texts[path].count(old)
    if n != 1:
        print(f"FAIL: {path}: target occurs {n} times: {old[:90]!r}")
        ok = False

if ok:
    for path, old, new in edits:
        texts[path] = texts[path].replace(old, new)
    for path, text in texts.items():
        path.write_text(text, encoding="utf-8")
        print(f"edited: {path}")

print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
