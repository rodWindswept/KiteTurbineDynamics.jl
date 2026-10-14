#!/usr/bin/env python3
"""fig-cg mint edit: row 23 joins the roster; map delta v36 appends.

Usage: python3 scratch/fig_cg_mint_edit.py    (repo root)
"""
import sys
from pathlib import Path

MAP = Path("docs/reporting/figures/figure-map.md")

edits = [
    # row 23 after row 22
    ("| 22 | ⟨tbd⟩ | §3.4 | The thrive/fail view. Status regions over the same projection | ⟨tbd⟩ | proposed | The founder ask (2026-10-13). The status and outcome columns | A slot ruling, then the build |\n",
     "| 22 | ⟨tbd⟩ | §3.4 | The thrive/fail view. Status regions over the same projection | ⟨tbd⟩ | proposed | The founder ask (2026-10-13). The status and outcome columns | A slot ruling, then the build |\n"
     "| 23 | ⟨tbd⟩ | §3.4 | The corner machines. Four renders, one per corner of the PC1-PC2 field | `machine-corner-grid` | planned | The founder ask (2026-10-14, routing comment 14). The pca projection (NR-044). Picks recorded at `scratch/fig_cg_picks.py` (data commit `dd3cc6a`, run `a76c5e9`) | The objective rows (science-validator), then the family-mode build |\n"),
    # delta v36 after v35
    ("  number prints. Script `d243b37`; the outputs and records ride this\n"
     "  commit. Two full runs byte-identical across all five outputs. Next:\n"
     "  the aero counter-read of the re-cut.\n",
     "  number prints. Script `d243b37`; the outputs and records ride this\n"
     "  commit. Two full runs byte-identical across all five outputs. Next:\n"
     "  the aero counter-read of the re-cut.\n"
     "\n"
     "- **v36 (2026-10-14):** the corner grid mints and its picks record (row\n"
     "  23). The founder ask (comment 14, id 13) asks four machine renders,\n"
     "  one typical of each corner of the PC1-PC2 field. The picks replicate\n"
     "  the certified projection with every NR-044 anchor re-verified, and\n"
     "  take the nearest feasible design to each [1,99] window corner:\n"
     "  `i1-g13-i1`, `i1-g7-i7`, `i2-g21-i4` and `i3-g26-i8`. The plate\n"
     "  values route to the science-validator first, then the family-mode\n"
     "  build.\n"),
]

ok = True
text = MAP.read_text(encoding="utf-8")
for old, new in edits:
    n = text.count(old)
    if n != 1:
        print(f"FAIL: target occurs {n} times: {old[:80]!r}")
        ok = False
        continue
    text = text.replace(old, new)
if ok:
    MAP.write_text(text, encoding="utf-8")
    print(f"edited: {MAP}")
print("RESULT:", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
