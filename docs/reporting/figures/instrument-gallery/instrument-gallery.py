#!/usr/bin/python3
"""instrument-gallery.py - compose the Figure 12 plate at the report measure.

The plate is the 2 x 2 frame grid and nothing else: no label, no rule, no type.
It prints 1:1 at 174 mm wide on the 531 dpi grid (v2's own floor: 1780 px at
85 mm), so a reader who opens the PNG sees the same pixels the draft prints.

Each frame keeps its natural aspect and fits an 85 x 59.89 mm cell by the
binding dimension, which is the rule the stamp records. Row 1 is v1 and v2,
both whole dashboard windows. Row 2 is the twisted-state 3D viewport, cut at
measured ink boundaries, and the 3D cartography.

The grid is a whole number of pixels: a 4.00 mm gutter is 83.6 px, so the
plate carries 84 px gutters and prints 3638 x 2514 px = 174.02 x 120.26 mm.

Run:
    /usr/bin/python3 docs/reporting/figures/instrument-gallery/instrument-gallery.py
    /usr/bin/python3 docs/reporting/figures/instrument-gallery/instrument-gallery.py --page-proof
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
CAPTURES = HERE / "captures"
CAPTIONS = HERE / "captions.md"

DPI = 531
MM = DPI / 25.4

W_MM = 174.00
CELL_W = 85.00
ROW1_H = 56.35          # v2's aspect at 85 mm: the set's own row height
GUTTER = 4.00
ROW2_Y = ROW1_H + GUTTER
ROW2_H = 59.89          # the admission box height
X2 = CELL_W + GUTTER    # 89.00, left edge of the right column

SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
SERIF_B = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

CAP_PT, CAP_LH = 9.0, 4.286      # build_draft_pdf.py caption type
STAMP_PT, STAMP_LH = 7.5, 4.63
LABEL_LH = 4.29
PLAIN_LH = 4.29


def font(path: str, pt: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, round(pt * DPI / 72))


F_CAP = font(SERIF, CAP_PT)
F_CAP_B = font(SERIF_B, CAP_PT)
F_STAMP = font(MONO, STAMP_PT)


def wrap(draw: ImageDraw.ImageDraw, text: str, f, width_px: int) -> list[str]:
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = w if not cur else cur + " " + w
        if draw.textlength(trial, font=f) <= width_px:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def parse_captions() -> tuple[str, str]:
    text = CAPTIONS.read_text(encoding="utf-8")

    def grab(head: str) -> str:
        m = re.search(rf"## {head}\n\n(.+?)(?=\n\n## |\Z)", text, re.S)
        return re.sub(r"\s+", " ", m.group(1)).strip() if m else ""

    return grab("Plain caption"), grab("Technical caption")


def build() -> tuple[Image.Image, list[tuple]]:
    Wpx = round(W_MM * MM)
    Hpx = round((ROW2_Y + ROW2_H) * MM)
    img = Image.new("RGB", (Wpx, Hpx), "white")
    d = ImageDraw.Draw(img)
    factors = []

    def place(name: str, cell_x: float, y: float, box_w: float, box_h: float,
              label: str) -> None:
        im = Image.open(CAPTURES / name).convert("RGB")
        # fit by the binding dimension, as the stamp's box rule states
        w = min(box_w, box_h * im.width / im.height)
        h = w * im.height / im.width
        tw, th = round(w * MM), round(h * MM)
        x = cell_x + (box_w - w) / 2.0
        factors.append((label, im.width, im.height, tw, th,
                        tw / im.width, im.width / (w / 25.4), x, w, h))
        im = im.resize((tw, th), Image.LANCZOS)
        xx, yy = round(x * MM), round(y * MM)
        img.paste(im, (xx, yy))
        d.rectangle([xx, yy, xx + tw - 1, yy + th - 1], outline=(30, 30, 30), width=3)

    place("dashboard-v1-head.png", 0.0, 0.0, CELL_W, ROW1_H, "v1")
    place("dashboard-v2-head.png", X2, 0.0, CELL_W, ROW1_H, "v2")
    place("dashboard-twisted-state-head.png", 0.0, ROW2_Y, CELL_W, ROW2_H, "twisted")
    place("winner-10kw-cartography-head.png", X2, ROW2_Y, CELL_W, ROW2_H, "cartography")

    out = HERE / "instrument-gallery.png"
    img.save(out, dpi=(DPI, DPI))
    print(f"--- {out.name}: {img.width} x {img.height} px at {DPI} dpi "
          f"= {img.width / MM:.2f} x {img.height / MM:.2f} mm ---")
    for label, sw, sh, tw, th, factor, native, x, w, h in factors:
        flag = "UPSAMPLED" if factor > 1.0005 else "down"
        print(f"  {label:11s} {sw:5d}x{sh:<5d} -> {tw:5d}x{th:<5d}  x0 {x:6.2f} mm  "
              f"fits {w:5.2f} x {h:5.2f} mm  factor {factor:5.3f} {flag:9s} "
              f"native {native:7.1f} dpi")
    return img, factors


def page_proof(plate: Image.Image) -> None:
    """The builder's page: 174 x 257 mm measure, figure margin 1.2em, figcaption."""
    plain, tech = parse_captions()
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    tech_lines = wrap(probe, tech, F_CAP, round(W_MM * MM))
    plain_lines = wrap(probe, plain, F_CAP, round(W_MM * MM))
    label = "Figure (roster row N) \u00b7 instrument-gallery"
    stamp = "one render pass, repository at <C1>"
    manifest_path = HERE / "manifest.json"
    if manifest_path.exists():
        run_id = json.loads(manifest_path.read_text()).get("capture", {}).get("run_id")
        if run_id:
            stamp = run_id

    top = 4.44
    gap = 1.27
    plate_h = plate.height / MM
    block = LABEL_LH + len(plain_lines) * PLAIN_LH + len(tech_lines) * CAP_LH + STAMP_LH
    page_h = top + plate_h + gap + block + top

    img = Image.new("RGB", (plate.width, round(257 * MM)), "white")
    d = ImageDraw.Draw(img)
    img.paste(plate, (0, round(top * MM)))

    y = top + plate_h + gap
    d.text((0, round(y * MM)), label, font=F_CAP_B, fill="black")
    y += LABEL_LH
    for ln in plain_lines:
        d.text((0, round(y * MM)), ln, font=F_CAP, fill="black")
        y += PLAIN_LH
    for ln in tech_lines:
        d.text((0, round(y * MM)), ln, font=F_CAP, fill="black")
        y += CAP_LH
    d.text((0, round(y * MM)), stamp, font=F_STAMP, fill=(70, 70, 70))

    out = HERE / "page-proof.png"
    img.save(out, dpi=(DPI, DPI))
    print(f"--- {out.name}: page {page_h:.2f} mm of 257, spare {257 - page_h:.2f} mm ---")
    print(f"    plate {plate_h:.2f} + gap {gap} + block {block:.2f} "
          f"({len(plain_lines)} plain, {len(tech_lines)} tech, stamp) + margins {2 * top:.2f}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--page-proof", action="store_true")
    args = ap.parse_args()
    plate, _ = build()
    if args.page_proof:
        page_proof(plate)
