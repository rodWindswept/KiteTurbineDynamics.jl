#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""twist-limit: generating script for the mechanism-pair plate.

Plate: docs/reporting/figures/twist-limit/SPEC.md (GENERATE stage, R2).
Panel A draws the transmitted twist |Δα| of every segment against its
over-twist limit δcrit.  Panel B pairs segment torque with torsional
capacity at the same capture instant.  Both panels share the shaft frame
of the companion plate (ring-utilisation).

Run:
  /usr/bin/python3 docs/reporting/figures/twist-limit/twist-limit.py \
      --script-commit <hex>

Toolchain pin: /usr/bin/python3 (CPython 3.12.3), matplotlib 3.10.8,
numpy 2.4.4.  F-REPRO: svg.hashsalt set, SVG dc:date normalised, PDF and
PNG metadata fixed, no timestamps anywhere.

Mechanism references (cleared to draw by science-validator, 2026-10-08;
register rows pending — see register-status.md):
  realisability floor 72.25°, crossing-limit example 42.6° with the
  2026-08-13 overshoot (22,425°, 62 revolutions), removed 90° asin read
  clamp.  The seed binding segment (79.4°) is HELD, not drawn.

Outputs (in this directory): twist-limit.svg / .pdf / .png,
label-ledger.txt, manifest.json.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

HERE = Path(__file__).resolve().parent
EXTRACT = HERE.parent / "pair-extract" / "extract-winner-operating-point.csv"
SLUG = "twist-limit"

CAPTURE = {
    "run_id": "pair-extract-2026-10-08-winner-ops",
    "s": "1724859",
    "t": "49.99999483862295",
}  # per pair-extract README and the NR-021..NR-023 sign-off basis
DATA_COMMIT = "dd3cc6a"
AUTHORITY_COMMIT = "f8114be"  # computing commit of the extract (CSV header)
ROWS = "NR-022 · NR-023"

# mechanism references (values as recorded by the science seat, 2026-10-08)
FLOOR_DEG = "72.25"
X_LIMIT_DEG = "42.6"
X_REACHED = "22,425"
X_REVS = "62"

INK = "#1a1a1a"
LINE = "#333333"
GREY = "#555555"
FAINT = "#777777"
MUTED = "#98a0a8"
SEP = "#e2e2e2"
CYAN = "#1f8fff"  # transmitted twist
GREEN = "#2e8c57"  # segment torque
RED = "#b32222"  # over-twist limit / capacity
FLOOR = "#8a94a6"  # realisability floor

TITLE = "Every segment of the winner runs far below its over-twist limit"
SUB = ("Transmitted twist against δcrit · shaft profile S1–S5, ground to "
       "hub · island-3 winner operating point")
PANEL_A = ("A — twist: transmitted twist |Δα| against its δcrit over-twist "
           "limit")
PANEL_B = ("B — torque: segment torque against torsional capacity, paired "
           "at the same state")
AX_A = "twist angle — degrees"
AX_B = "torque — N·m"
FLOOR_LABEL = f"realisability floor {FLOOR_DEG}°"
LEGEND = [
    ("dot", CYAN, "transmitted twist (panel A)"),
    ("dot", GREEN, "segment torque (panel B)"),
    ("tick", RED, "δcrit over-twist limit"),
    ("square", RED, "torsional capacity"),
]
NOTES = [
    ("realisability floor — sin Δα ≤ 1/1.05 holds the geometry only to "
     f"{FLOOR_DEG}°."),
    ("crossing limit δα* — every segment gates on its own collapse-detector "
     "limit. That limit is not the over-twist limit."),
    (f"The 2026-08-13 winner ran to {X_REACHED}° ({X_REVS} revolutions) "
     f"against its {X_LIMIT_DEG}° limit — off scale."),
    ("read cap — the former 90° asin clamp is removed. Reads are uncapped."),
    ("no limit — the segment's tether is shorter than the sum of its end "
     "radii. Its lines cannot reach the axis,"),
    ("so no over-twist limit exists. Tether break strain and ring "
     "compression carry the limit instead."),
]

LEDGER: list[str] = []


def keep(s: str) -> str:
    LEDGER.append(s)
    return s


def txt(ax, x, y, s, **kw):
    return ax.text(x, y, keep(s), **kw)


def read_extract(path: Path) -> dict[str, list[dict]]:
    with path.open(newline="", encoding="utf-8") as fh:
        lines = [ln for ln in fh if not ln.startswith("#")]
    rows: dict[str, list[dict]] = {"ring": [], "segment": []}
    for row in csv.DictReader(lines):
        rows[row["block"]].append(row)
    return rows


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script-commit", default="uncommitted")
    ap.add_argument("--outdir", default=str(HERE))
    args = ap.parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    data = read_extract(EXTRACT)
    segs = data["segment"]
    rings = data["ring"]
    stations = [0.0] + [float(r["station_m"]) for r in rings]
    centers = [(stations[i] + stations[i + 1]) / 2 for i in range(5)]

    plt.rcParams.update(
        {
            "font.size": 8,
            "svg.hashsalt": "ktd-fig-pin-2026-10-08",
            "svg.fonttype": "none",
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
            "figure.facecolor": "white",
            "savefig.facecolor": "white",
        }
    )

    fig = plt.figure(figsize=(7.6, 7.6))
    fig.text(0.012, 0.972, keep(TITLE), size=11, weight="bold", color=INK)
    fig.text(0.012, 0.943, keep(SUB), size=8, color=GREY)

    DEF_A = [0.145, 0.60, 0.825, 0.27]
    DEF_B = [0.145, 0.30, 0.825, 0.27]
    YLIM = (-2.3, 21.8)
    Y_AXIS = 19.0  # axis strip height per panel

    def base_panel(defrect, xmin, xmax, ticks, tickfmt, axlabel):
        ax = fig.add_axes(defrect)
        ax.set_axis_off()
        ax.set_xlim(xmin, xmax)
        ax.set_ylim(*YLIM)
        # shaft column + ring ticks + labels (shared frame)
        sh = xmin * 0.575
        ax.plot([sh, sh], [-0.3, 18.9], color="#c4c4c4", lw=0.9,
                ls=(0, (3, 3)))
        for i, y in enumerate(stations):
            ax.plot([xmin * 0.62, xmin * 0.50], [y, y], color=MUTED, lw=1.4)
            label = "R6 (hub)" if i == 5 else f"R{i + 1}"
            txt(ax, xmin * 0.68, y, label, ha="right", va="center", size=8,
                color=GREY)
        # segment separators + labels
        for y in stations[1:-1]:
            ax.plot([xmin * 0.70, xmax * 0.995], [y, y], color=SEP, lw=0.7,
                    zorder=1)
        for i, yc in enumerate(centers):
            txt(ax, xmin * 0.30, yc, f"S{i + 1}", ha="left", va="center",
                size=7.5, color=GREY)
        # top axis strip
        ax.plot([0.0, xmax * 0.99], [Y_AXIS, Y_AXIS], color=LINE, lw=1.1,
                solid_capstyle="butt")
        for t in ticks:
            ax.plot([t, t], [Y_AXIS, Y_AXIS + 0.22], color=LINE, lw=0.8)
            txt(ax, t, Y_AXIS + 0.28, tickfmt(t), ha="center", va="bottom",
                size=7, color=LINE)
        txt(ax, 0.0, Y_AXIS + 1.35, axlabel, ha="left", va="bottom",
            size=8, color=INK)
        return ax

    axa = base_panel(DEF_A, -20, 124, [0, 20, 40, 60, 80, 100],
                     lambda t: f"{t:g}", AX_A)
    axb = base_panel(DEF_B, -200, 1250, [0, 200, 400, 600, 800, 1000],
                     lambda t: f"{t:g}", AX_B)

    # ------------------------------------------------------------ panel A
    axa.plot([72.25, 72.25], [-0.6, 18.35], color=FLOOR, lw=1.3,
             ls=(0, (4, 3)), zorder=1.5)
    txt(axa, 72.25, 18.45, FLOOR_LABEL, ha="center", va="top", size=7.5,
        color=FLOOR)

    for seg, yc in zip(segs, centers):
        mag = float(seg["abs_dalpha_deg"])
        lim = float(seg["dcrit_deg"])
        axa.plot([mag, lim], [yc, yc], color="#999999", lw=1.0,
                 ls=(0, (2, 3)), zorder=2)
        axa.plot([mag], [yc], marker="o", ms=5.5, mfc=CYAN, mec=CYAN,
                 zorder=4)
        axa.plot([lim, lim], [yc - 0.6, yc + 0.6], color=RED, lw=2.2,
                 zorder=4)
        txt(axa, mag, yc + 0.5, f"{mag:.1f}", ha="center", va="bottom",
            size=7, color=INK,
            bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none",
                      alpha=1.0))
        txt(axa, lim, yc + 0.5, f"{lim:.1f}", ha="center", va="bottom",
            size=7, color=RED,
            bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none",
                      alpha=1.0))

    # ------------------------------------------------------------ panel B
    for seg, yc in zip(segs, centers):
        tq = float(seg["segment_torque_Nm"])
        cap = float(seg["torque_capacity_Nm"])
        axb.plot([tq, cap], [yc, yc], color="#999999", lw=1.0,
                 ls=(0, (2, 3)), zorder=2)
        axb.plot([tq], [yc], marker="o", ms=5.5, mfc=GREEN, mec=GREEN,
                 zorder=4)
        axb.plot([cap], [yc], marker="s", ms=5.5, mfc="white", mec=RED,
                 mew=1.4, zorder=4)
        txt(axb, tq, yc + 0.5, f"{tq:.1f}", ha="center", va="bottom",
            size=7, color=INK,
            bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none",
                      alpha=1.0))
        txt(axb, cap, yc + 0.5, f"{cap:.1f}", ha="center", va="bottom",
            size=7, color=RED,
            bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none",
                      alpha=1.0))

    # panel labels (bottom of each panel)
    txt(axa, 0.0, -0.65, PANEL_A, ha="left", va="top", size=7.5, color=GREY)
    txt(axb, 0.0, -0.65, PANEL_B, ha="left", va="top", size=7.5, color=GREY)

    # ------------------------------------------------------------ foot
    foot = fig.add_axes([0.0, 0.0, 1.0, 0.26])
    foot.set_axis_off()
    foot.set_xlim(0, 1)
    foot.set_ylim(0, 1)

    def marker(x, color, kind):
        if kind == "dot":
            foot.plot([x], [0.93], marker="o", ms=5.5, mfc=color, mec=color)
        elif kind == "tick":
            foot.plot([x + 0.002], [0.93], marker="|", ms=9, color=color,
                      mew=2.2)
        else:
            foot.plot([x + 0.004], [0.93], marker="s", ms=5.5, mfc="white",
                      mec=color, mew=1.4)

    lpos = [0.028, 0.26, 0.475, 0.675]
    for i, (kind, color, s) in enumerate(LEGEND):
        x = lpos[i]
        marker(x, color, kind)
        foot.text(x + 0.022, 0.93, keep(s), ha="left", va="center", size=7.5,
                  color=INK)

    ny = [0.84, 0.74, 0.64, 0.54, 0.44, 0.34]
    for y, s in zip(ny, NOTES):
        foot.text(0.028, y, keep(s), ha="left", va="center", size=7,
                  color=GREY)

    stamp1 = (f"source: data commit {DATA_COMMIT} · extract "
              f"extract-winner-operating-point.csv · capture "
              f"{CAPTURE['run_id']}")
    stamp2 = (f"s = {CAPTURE['s']} (t = {CAPTURE['t']} s) · rows {ROWS} · "
              f"script commit {args.script_commit} · authority commit "
              f"{AUTHORITY_COMMIT}")
    foot.text(0.028, 0.24, keep(stamp1), ha="left", va="center", size=6.5,
              color=FAINT)
    foot.text(0.028, 0.14, keep(stamp2), ha="left", va="center", size=6.5,
              color=FAINT)

    # ------------------------------------------------------------ save
    svg = outdir / f"{SLUG}.svg"
    pdf = outdir / f"{SLUG}.pdf"
    png = outdir / f"{SLUG}.png"
    fig.savefig(svg)
    fig.savefig(pdf, metadata={"Creator": f"{SLUG} · KTD figures",
                               "CreationDate": None})
    fig.savefig(png, dpi=300)
    plt.close(fig)

    raw = svg.read_bytes()
    raw = re.sub(rb"<dc:date>[^<]*</dc:date>",
                 rb"<dc:date>1970-01-01T00:00:00</dc:date>", raw)
    svg.write_bytes(raw)

    ledger = sorted(set(LEDGER))
    (outdir / "label-ledger.txt").write_text(
        "\n".join(ledger) + "\n", encoding="utf-8")

    found = {
        html.unescape(re.sub(r"<[^>]+>", "", m)).strip()
        for m in re.findall(r"<text[^>]*>(.*?)</text>", svg.read_text(),
                            flags=re.S)
    }
    missing = sorted(found - set(ledger))
    extra = sorted(set(ledger) - found)
    if missing or extra:
        print("F-LABEL self-check FAILED", file=sys.stderr)
        for s in missing:
            print(f"  in vector, not in ledger: {s!r}", file=sys.stderr)
        for s in extra:
            print(f"  in ledger, not in vector: {s!r}", file=sys.stderr)
        return 1

    manifest = {
        "slug": SLUG,
        "script": {
            "path": f"docs/reporting/figures/{SLUG}/{SLUG}.py",
            "sha256": sha256(Path(__file__).resolve()),
        },
        "toolchain": {
            "python": ".".join(str(v) for v in sys.version_info[:3]),
            "matplotlib": matplotlib.__version__,
            "numpy": __import__("numpy").__version__,
        },
        "inputs": {
            "extract": {
                "path": "docs/reporting/figures/pair-extract/"
                        "extract-winner-operating-point.csv",
                "sha256": sha256(EXTRACT),
            },
            "register_rows": [ROWS],
            "mechanism_references": {
                "realisability_floor_deg": FLOOR_DEG,
                "crossing_limit_example_deg": X_LIMIT_DEG,
                "crossing_overshoot_deg": X_REACHED,
                "crossing_overshoot_revs": X_REVS,
                "status": "cleared to draw 2026-10-08; rows pending",
            },
        },
        "capture": CAPTURE,
        "command": ("/usr/bin/python3 "
                    f"docs/reporting/figures/{SLUG}/{SLUG}.py "
                    f"--script-commit {args.script_commit}"),
        "precision": "angles 0.1 deg drawn; torque 0.1 N·m drawn; "
                     "mechanism references as recorded",
        "outputs": {
            f"{SLUG}.svg": sha256(svg),
            f"{SLUG}.pdf": sha256(pdf),
            f"{SLUG}.png": sha256(png),
            "label-ledger.txt": sha256(outdir / "label-ledger.txt"),
        },
    }
    (outdir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8")

    print(f"written: {SLUG}.svg / .pdf / .png, label-ledger.txt "
          f"({len(ledger)} strings), manifest.json")
    print("F-LABEL self-check: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
