#!/usr/bin/python3
"""prior-analysis-gallery.py - compose the roster-row-32 plate at the report measure.

The plate holds six panels, one per prior chart class. Each panel prints its
campaign, its commit and its void status under the frame. Panel six carries a
void label because the pitch-depower V2 campaign has no surviving run.

The plate is a composition: it reads six tracked panel files under panels/,
scales each into an 85 x 48 mm cell, and draws the stamps at plate level so
they print at 7 pt. It renders none of the panels.

Run:
    /usr/bin/python3 docs/reporting/figures/prior-analysis-gallery/prior-analysis-gallery.py
    /usr/bin/python3 docs/reporting/figures/prior-analysis-gallery/prior-analysis-gallery.py --page-proof
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
PANELS = HERE / "panels"
CAPTIONS = HERE / "captions.md"
MANIFEST = HERE / "manifest.json"

DPI = 531
MM = DPI / 25.4

W_MM = 174.00
CELL_W = 85.00
IMG_H = 48.00
GUTTER = 4.00
X2 = CELL_W + GUTTER            # 89.00
STAMP_GAP = 2.20
STAMP_LH = 3.10
ROW_GAP = 4.00
ROW_PITCH = IMG_H + STAMP_GAP + 2 * STAMP_LH + ROW_GAP

SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
SERIF_B = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
SANS_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

CAP_PT, CAP_LH = 9.0, 4.286
STAMP_PT, STAMP_LH_PT = 7.0, 3.10
LABEL_LH = 4.29
PLAIN_LH = 4.29
RUN_STAMP_PT, RUN_STAMP_LH = 7.5, 4.63

VOID_RED = (179, 38, 30)
INK = (20, 20, 20)
GREY = (90, 90, 90)

# class, file, line 1, line 2, void, source, source_commit, campaign
PANEL_SPEC = [
    dict(cls="power curve", file="F1_power_curve.png",
         l1="power curve \u00b7 V10/constCL \u00b7 no campaign",
         l2="generate_charts.jl @ 86ca0e5 \u00b7 tier P (provisional) \u00b7 not void",
         void=False, source="charts/output/F1_power_curve.svg",
         commit="86ca0e5", campaign="none (declarative chart set)"),
    dict(cls="FoS envelope", file="F2_fos_envelope.png",
         l1="FoS envelope \u00b7 V10/constCL \u00b7 no campaign",
         l2="generate_charts.jl @ 86ca0e5 \u00b7 tier P (provisional) \u00b7 not void",
         void=False, source="charts/output/F2_fos_envelope.svg",
         commit="86ca0e5", campaign="none (declarative chart set)"),
    dict(cls="blade scaling", file="F5_blade_scaling.png",
         l1="blade scaling \u00b7 V10/constCL \u00b7 no campaign",
         l2="generate_charts.jl @ 86ca0e5 \u00b7 tier P (provisional) \u00b7 not void",
         void=False, source="charts/output/F5_blade_scaling.svg",
         commit="86ca0e5", campaign="none (declarative chart set)"),
    dict(cls="loss discriminator", file="F6_loss_discriminator.png",
         l1="loss discriminator \u00b7 V10/constCL \u00b7 no campaign",
         l2="generate_charts.jl @ 86ca0e5 \u00b7 tier P (provisional) \u00b7 not void",
         void=False, source="charts/output/F6_loss_discriminator.svg",
         commit="86ca0e5", campaign="none (declarative chart set)"),
    dict(cls="BEM benchmark", file="bem_benchmark_tulloch_wacker.png",
         l1="BEM benchmark \u00b7 Tulloch/Wacker chart",
         l2="analytical design chart @ 3619ad7 \u00b7 not void",
         void=False, source="figures/report/fig_tulloch_wacker_chart.png",
         commit="3619ad7", campaign="none (literature benchmark)"),
    dict(cls="design-space heatmap", file="design_space_heatmap_pitch_depower_v2.png",
         l1="design-space heatmap \u00b7 pitch-depower V2",
         l2="git 719e298 \u00b7 VOID: 512 of 512 runs disqualified",
         void=True, source="scripts/results/pitch_depower_campaign/analysis/03_heatmap_brake_time.png",
         commit="719e298", campaign="pitch_depower_campaign (V2)"),
]


def font(path: str, pt: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, round(pt * DPI / 72))


F_SANS = font(SANS, STAMP_PT)
F_SANS_B = font(SANS_B, STAMP_PT)
F_VOID = font(SANS_B, 8.0)
F_CAP = font(SERIF, CAP_PT)
F_CAP_B = font(SERIF_B, CAP_PT)
F_RUN = font(MONO, RUN_STAMP_PT)


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


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def build() -> tuple[Image.Image, list[dict], list[str]]:
    Wpx = round(W_MM * MM)
    Hpx = round((2 * ROW_PITCH + IMG_H + STAMP_GAP + 2 * STAMP_LH) * MM)
    img = Image.new("RGB", (Wpx, Hpx), "white")
    d = ImageDraw.Draw(img)
    checks: list[str] = []
    facts: list[dict] = []

    for i, spec in enumerate(PANEL_SPEC):
        col, row = i % 2, i // 2
        cx = 0.0 if col == 0 else X2
        ry = row * ROW_PITCH
        src = PANELS / spec["file"]
        im = Image.open(src).convert("RGB")

        w = min(CELL_W, IMG_H * im.width / im.height)
        h = w * im.height / im.width
        x = cx + (CELL_W - w) / 2.0
        y = ry + (IMG_H - h) / 2.0
        tw, th = round(w * MM), round(h * MM)
        im2 = im.resize((tw, th), Image.LANCZOS)
        xx, yy = round(x * MM), round(y * MM)
        img.paste(im2, (xx, yy))
        d.rectangle([xx, yy, xx + tw - 1, yy + th - 1], outline=(30, 30, 30), width=3)

        if spec["void"]:
            tag_w, tag_h = 17.0, 6.4
            tx = xx + tw - round(tag_w * MM) - 6
            ty = yy + 6
            d.rectangle([tx, ty, tx + round(tag_w * MM), ty + round(tag_h * MM)],
                        fill=VOID_RED)
            label = "VOID"
            lw = d.textlength(label, font=F_VOID)
            bbox = d.textbbox((0, 0), label, font=F_VOID)
            lh = bbox[3] - bbox[1]
            d.text((tx + (round(tag_w * MM) - lw) / 2,
                    ty + (round(tag_h * MM) - lh) / 2), label, font=F_VOID,
                   fill="white")

        sy = ry + IMG_H + STAMP_GAP
        sx = cx + 1.5
        d.text((round(sx * MM), round(sy * MM)), spec["l1"], font=F_SANS_B, fill=INK)
        d.text((round(sx * MM), round((sy + STAMP_LH) * MM)), spec["l2"],
               font=F_SANS, fill=VOID_RED if spec["void"] else GREY)

        lim = round((CELL_W - 2.0) * MM)
        for txt, fnt in ((spec["l1"], F_SANS_B), (spec["l2"], F_SANS)):
            wpx = d.textlength(txt, font=fnt)
            checks.append(f"stamp fits {wpx:.0f} <= {lim} px: {txt}")
            assert wpx <= lim

        facts.append(dict(
            n=i + 1, klass=spec["cls"], file="panels/" + spec["file"],
            pixels=[im.width, im.height], prints_mm=[round(w, 2), round(h, 2)],
            factor=round(w * MM / im.width, 3),
            source=spec["source"], source_commit=spec["commit"],
            campaign=spec["campaign"], void=spec["void"],
        ))

    out = HERE / "prior-analysis-gallery.png"
    img.save(out, dpi=(DPI, DPI), optimize=False)
    return img, facts, checks


def run_checks(img: Image.Image, facts: list[dict]) -> list[str]:
    out = []
    out.append(f"panel count reads 6: {len(facts)}")
    assert len(facts) == 6
    classes = [f["klass"] for f in facts]
    out.append("class set reads six distinct: " + ", ".join(classes))
    assert len(set(classes)) == 6
    voids = [f["n"] for f in facts if f["void"]]
    out.append(f"void panels read 1: {len(voids)}")
    assert voids == [6]
    for f in facts:
        out.append(f"panel {f['n']} fits the cell: {f['prints_mm'][0]} x {f['prints_mm'][1]} mm")
        assert f["prints_mm"][0] <= CELL_W + 0.02
        assert f["prints_mm"][1] <= IMG_H + 0.02
    Wpx = round(W_MM * MM)
    out.append(f"plate width {img.width} px = {img.width / MM:.2f} mm")
    assert img.width == Wpx
    out.append(f"plate height {img.height} px = {img.height / MM:.2f} mm")
    return out


def current_run_id() -> str:
    try:
        head = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], cwd=HERE).decode().strip()
    except Exception:
        head = "uncommitted"
    return f"one composition pass, repository at {head}"


def page_proof(plate: Image.Image, run_id: str) -> None:
    plain, tech = parse_captions()
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    tech_lines = wrap(probe, tech, F_CAP, round(W_MM * MM))
    plain_lines = wrap(probe, plain, F_CAP, round(W_MM * MM))
    label = "Figure (roster row 32) - prior-analysis-gallery"

    top = 4.44
    gap = 1.27
    plate_h = plate.height / MM
    block = LABEL_LH + len(plain_lines) * PLAIN_LH + len(tech_lines) * CAP_LH + RUN_STAMP_LH
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
    d.text((0, round(y * MM)), run_id, font=F_RUN, fill=(70, 70, 70))

    out = HERE / "page-proof.png"
    img.save(out, dpi=(DPI, DPI), optimize=False)
    print(f"--- {out.name}: page {page_h:.2f} mm of 257, spare {257 - page_h:.2f} mm ---")
    print(f"    plate {plate_h:.2f} + gap {gap} + block {block:.2f} "
          f"({len(plain_lines)} plain, {len(tech_lines)} tech, stamp) + margins {2 * top:.2f}")


def write_manifest(img: Image.Image, facts: list[dict], run_id: str) -> None:
    head = run_id.rsplit(" at ", 1)[-1]
    manifest = {
        "slug": "prior-analysis-gallery",
        "figure": "roster row 32, section 9: the prior-analysis gallery",
        "mode": "prior-analysis gallery, six panels",
        "run_id": f"one composition pass, repository at {head}",
        "run_commit": head,
        "command": "/usr/bin/python3 docs/reporting/figures/prior-analysis-gallery/prior-analysis-gallery.py --page-proof",
        "script": {
            "path": "docs/reporting/figures/prior-analysis-gallery/prior-analysis-gallery.py",
            "sha256": sha256(Path(__file__).resolve()),
        },
        "plate": {
            "pixels": [img.width, img.height],
            "dpi": DPI,
            "prints_mm": [round(img.width / MM, 2), round(img.height / MM, 2)],
            "cell_mm": [CELL_W, IMG_H],
            "gutter_mm": GUTTER,
            "row_pitch_mm": ROW_PITCH,
            "sha256": sha256(HERE / "prior-analysis-gallery.png"),
        },
        "panels": facts,
        "captions": {
            "path": "docs/reporting/figures/prior-analysis-gallery/captions.md",
            "sha256": sha256(CAPTIONS),
        },
        "outputs": {
            "prior-analysis-gallery.png": sha256(HERE / "prior-analysis-gallery.png"),
            "page-proof.png": sha256(HERE / "page-proof.png") if (HERE / "page-proof.png").exists() else None,
        },
        "withheld": "no panel prints a current claim; every value belongs to the tool or campaign that printed it at that commit",
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--page-proof", action="store_true")
    args = ap.parse_args()
    plate, facts, stamp_checks = build()
    checks = run_checks(plate, facts) + stamp_checks
    run_id = current_run_id()
    if args.page_proof:
        page_proof(plate, run_id)
    write_manifest(plate, facts, run_id)
    print(f"--- prior-analysis-gallery.png: {plate.width} x {plate.height} px at {DPI} dpi "
          f"= {plate.width / MM:.2f} x {plate.height / MM:.2f} mm ---")
    for c in checks:
        print("ok  " + c)
    print(f"{len(checks)} ok / 0 fail")
