#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""The levers fix pass: figure-map edits (rows 20/21 cells + delta v26).

Run: /usr/bin/python3 scratch/fig_pca_fix_map_edit.py
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MAP = REPO / "docs/reporting/figures/figure-map.md"

CELL_OLD = ("The counter-read by the seats (F-VALUE opens, NR-044 signed). Then the visual pass by Rod")
CELL_NEW = ("F-VALUE counter-read at `331f60d` holds the drawn values. The cite fix and the stamp re-cut "
            "landed (script commit `e23f226`). A fresh read rides the new pins. Then the visual pass by Rod")

TAIL_OLD = "and 21 wait on the counter-read and the visual pass by Rod.\n"
TAIL_NEW = ("and 21 wait on the counter-read and the visual pass by Rod.\n\n"
            "- **v26 (2026-10-14):** the levers fix pass lands. The NR-005 and NR-006\n"
            "  cites take the register mapping on both kits, ten lines across six\n"
            "  files. The drawn row lists take NR-044 on both stamps and NR-045 on\n"
            "  the landscape. The landscape projection stamp takes its signed form.\n"
            "  The caption text takes the kg-equivalent form on the landscape and\n"
            "  the strip. Script commit `e23f226`, with both kits re-rendered and\n"
            "  two runs byte-identical across all five outputs each. The F-VALUE\n"
            "  counter-read at `331f60d` had routed the fix. Next: a fresh\n"
            "  counter-read, then the fold and the visual pass by Rod.\n")


def main() -> int:
    text = MAP.read_text()
    n = text.count(CELL_OLD)
    assert n == 2, ("cells", n)
    text = text.replace(CELL_OLD, CELL_NEW)
    n = text.count(TAIL_OLD)
    assert n == 1, ("tail", n)
    text = text.replace(TAIL_OLD, TAIL_NEW)
    MAP.write_text(text)
    print("edited: docs/reporting/figures/figure-map.md (2 cells, delta v26)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
