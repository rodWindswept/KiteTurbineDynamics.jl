#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""ring-utilisation: generating script for the mechanism-pair plate.

Plate: docs/reporting/figures/ring-utilisation/SPEC.md (GENERATE stage, R2).
Draws the beam-column interaction of every checked ring against the fail
boundary, from the ruled capture (winner operating point).

Run:
  /usr/bin/python3 docs/reporting/figures/ring-utilisation/ring-utilisation.py \
      --script-commit <hex>

Toolchain pin: /usr/bin/python3 (CPython 3.12.3), matplotlib 3.10.8,
numpy 2.4.4.  F-REPRO: svg.hashsalt set, SVG dc:date normalised, PDF and
PNG metadata fixed, no timestamps anywhere.

Outputs (in this directory): ring-utilisation.svg / .pdf / .png,
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
REPO = HERE.parents[3]
EXTRACT = HERE.parent / "pair-extract" / "extract-winner-operating-point.csv"
SLUG = "ring-utilisation"

# ---------------------------------------------------------------- constants
CAPTURE = {
    "run_id": "pair-extract-2026-10-08-winner-ops",
    "s": "1724859",
    "t": "49.99999483862295",
}  # per pair-extract README and the NR-021..NR-023 sign-off basis
DATA_COMMIT = "dd3cc6a"
AUTHORITY_COMMIT = "f8114be"  # computing commit of the extract (CSV header)
ROWS = "NR-021"

INK = "#1a1a1a"
LINE = "#333333"
GREY = "#555555"
FAINT = "#777777"
MUTED = "#98a0a8"
SHAFT = "#c4c4c4"
CYAN = "#1f8fff"  # axial share
ORANGE = "#ff8c00"  # bending share
RED = "#b32222"  # fail boundary

TITLE = "Every checked ring sits far below its fail boundary"
SUB = "Beam-column interaction per checked ring · island-3 winner operating point"
AXLABEL = "utilisation — beam-column interaction"
GROUND = "R1 — ground ring · not checked (ground-supported)"
BOUNDARY = "fail boundary"
LEGEND = [
    ("swatch", CYAN, "axial share (N/N_crit, worst beam)"),
    ("swatch", ORANGE, "bending share (√(M²)/M_el, same beam)"),
    ("dash", RED, "fail boundary — interaction at the unit value"),
    ("text", None, "readout: ring FoS = 1 / ring utilisation"),
]

LEDGER: list[str] = []


def keep(s: str) -> str:
    LEDGER.append(s)
    return s


def txt(ax, x, y, s, **kw):
    return ax.text(x, y, keep(s), **kw)


def fmt_fos(v: float) -> str:
    if v >= 1e4:
        return f"{round(v):,}"
    return f"{v:.3f}"


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
    rings = data["ring"]
    stations = {r["id"]: float(r["station_m"]) for r in rings}
    stations["R1"] = 0.0

    # ------------------------------------------------------------ style
    plt.rcParams.update(
        {
            "font.size": 8,
            "svg.hashsalt": "ktd-fig-pin-2026-10-08",
            "svg.fonttype": "none",  # keep a real text layer (F-LABEL)
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
            "figure.facecolor": "white",
            "savefig.facecolor": "white",
        }
    )

    fig = plt.figure(figsize=(7.6, 4.9))
    fig.text(0.012, 0.965, keep(TITLE), size=11, weight="bold", color=INK)
    fig.text(0.012, 0.930, keep(SUB), size=8, color=GREY)

    ax = fig.add_axes([0.145, 0.245, 0.825, 0.60])
    ax.set_axis_off()
    ax.set_xlim(-0.34, 1.115)
    ax.set_ylim(-1.8, 22.2)

    # top axis strip (manual, spans bar origin to right edge)
    ax.plot([0.0, 1.10], [19.5, 19.5], color=LINE, lw=1.1, solid_capstyle="butt")
    for t in (0.0, 0.2, 0.4, 0.6, 0.8, 1.0):
        ax.plot([t, t], [19.5, 19.72], color=LINE, lw=0.8)
        lbl = f"{t:.1f}" if t < 1.0 else "1.0"
        txt(ax, t, 19.78, lbl, ha="center", va="bottom", size=7.5, color=LINE)
    txt(ax, 0.0, 20.75, AXLABEL, ha="left", va="bottom", size=8.5, color=INK)

    # shaft column and ring ticks
    ymin_r, ymax_r = 0.0, max(stations.values())
    ax.plot([-0.255, -0.255], [ymin_r - 0.25, ymax_r + 0.25], color=SHAFT,
            lw=0.9, ls=(0, (3, 3)))
    for rid, y in stations.items():
        ax.plot([-0.285, -0.225], [y, y], color=MUTED, lw=1.6)
        label = "R6 (hub)" if rid == "R6" else rid
        txt(ax, -0.302, y, label, ha="right", va="center", size=8, color=GREY)

    # fail boundary line and label
    ax.plot([1.0, 1.0], [-0.5, 19.4], color=RED, lw=1.8, ls=(0, (5, 4)))
    txt(ax, 1.0, -0.62, BOUNDARY, ha="center", va="top", size=7.5,
        color=RED, style="italic")

    # stacked bars and FoS readouts
    bh = 1.15
    for r in rings:
        y = float(r["station_m"])
        ua = float(r["util_axial"])
        ub = float(r["util_bending"])
        ax.add_patch(Rectangle((0.0, y - bh / 2), ua, bh, facecolor=CYAN,
                               edgecolor="none", alpha=0.95, zorder=3))
        ax.add_patch(Rectangle((ua, y - bh / 2), ub, bh, facecolor=ORANGE,
                               edgecolor=ORANGE, lw=0.6, alpha=0.35, zorder=3))
        txt(ax, ua + ub + 0.016, y, f"FoS {fmt_fos(float(r['ring_fos']))}",
            ha="left", va="center", size=8, color=INK)

    # ground-ring note
    txt(ax, 0.0, -0.62, GROUND, ha="left", va="top", size=7.5, color=FAINT)

    # ------------------------------------------------------------ foot
    foot = fig.add_axes([0.0, 0.0, 1.0, 0.225])
    foot.set_axis_off()
    foot.set_xlim(0, 1)
    foot.set_ylim(0, 1)

    def swatch(x, color, kind="swatch"):
        if kind == "swatch":
            foot.add_patch(Rectangle((x, 0.80), 0.016, 0.085, facecolor=color,
                                     edgecolor=color, lw=0.6, alpha=0.7))
        else:
            foot.plot([x, x + 0.022], [0.843, 0.843], color=color, lw=1.8,
                      ls=(0, (4, 3)))

    pos = [0.028, 0.315, 0.63, 0.028]
    for i, (kind, color, s) in enumerate(LEGEND):
        x = pos[i]
        if kind != "text":
            swatch(x, color, kind)
            foot.text(x + 0.026, 0.843, keep(s), ha="left", va="center",
                      size=7.5, color=INK)
        else:
            foot.text(x, 0.62, keep(s), ha="left", va="center", size=7.5,
                      color=INK)

    stamp1 = (f"source: data commit {DATA_COMMIT} · extract "
              f"extract-winner-operating-point.csv · capture {CAPTURE['run_id']}")
    stamp2 = (f"s = {CAPTURE['s']} (t = {CAPTURE['t']} s) · rows {ROWS} · "
              f"script commit {args.script_commit} · authority commit "
              f"{AUTHORITY_COMMIT}")
    foot.text(0.028, 0.30, keep(stamp1), ha="left", va="center", size=6.5,
              color=FAINT)
    foot.text(0.028, 0.13, keep(stamp2), ha="left", va="center", size=6.5,
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

    # normalise the SVG date (byte-stable output)
    raw = svg.read_bytes()
    raw = re.sub(rb"<dc:date>[^<]*</dc:date>",
                 rb"<dc:date>1970-01-01T00:00:00</dc:date>", raw)
    svg.write_bytes(raw)

    # ------------------------------------------------------------ ledger
    ledger = sorted(set(LEDGER))
    (outdir / "label-ledger.txt").write_text(
        "\n".join(ledger) + "\n", encoding="utf-8")

    # self-check: every text node of the SVG equals a ledger entry
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

    # ------------------------------------------------------------ manifest
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
        },
        "capture": CAPTURE,
        "command": ("/usr/bin/python3 "
                    f"docs/reporting/figures/{SLUG}/{SLUG}.py "
                    f"--script-commit {args.script_commit}"),
        "precision": "FoS readouts at 0.001, nearest integer above 1e4",
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
