#!/usr/bin/env python3
"""crop-twisted-cell.py — cut the 3D viewport out of the whole-window render.

render-twisted-state-head.jl saves the whole dashboard window at
px_per_unit = 2 (4074 x 1900). The layout columns are fixed: 300 px
control column, the 3D viewport, 370 px HUD column — but the widgets do
not respect their column exactly: the slider tracks end at device x = 612
(6 logical px past the 300 px column), and the HUD text anchors 3308 px at
the latest (23 device px inside its own column edge). Cutting on the
declared column widths therefore keeps clipped glyphs of both columns.

So the cut lands on the measured ink boundaries instead: device columns
613 .. 3308 inclusive, 2696 wide. Both inside margins carry zero ink at a
threshold of 12 levels off #1a1a1a, and the excluded strips carry the
sliders (1479 ink px) and the HUD's first glyph slivers. Every pixel the
scene draws prints; no chrome pixel does.

Run:
    python3 crop-twisted-cell.py
"""
from pathlib import Path
import hashlib

from PIL import Image

HERE = Path(__file__).resolve().parent
FULL = HERE / "dashboard-twisted-window-head.png"
OUT = HERE / "dashboard-twisted-state-head.png"

PPU = 2
WINDOW = (4074, 1900)
LEFT = 613          # first column kept: slider ink ends at 612
RIGHT = 3309        # one past the last column kept: HUD ink starts at 3311
CELL = (2696, 1900)

img = Image.open(FULL)
print(f"window {img.size}")
assert img.size == WINDOW, f"unexpected window size {img.size}, expected {WINDOW}"

vp = img.crop((LEFT, 0, RIGHT, WINDOW[1]))
assert vp.size == CELL, f"unexpected cell size {vp.size}, expected {CELL}"
vp.save(OUT)
print(f"cell {vp.size}")
print(f"cell bytes {OUT.stat().st_size}")
print(f"cell sha256 {hashlib.sha256(OUT.read_bytes()).hexdigest()}")
