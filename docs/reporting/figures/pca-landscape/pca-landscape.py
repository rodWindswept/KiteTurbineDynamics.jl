#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""pca-landscape: generating script for the levers-landscape plate (PCA redo).

Plate: docs/reporting/figures/pca-landscape/SPEC.md (GENERATE stage).
Draws the PC1-PC2 projection of the 930-design v13 5 kW screen, coloured
by the search objective, with the three island journeys.  The reading
insets carry the lever directions, in the form of the old campaign
landscape charts.

Inputs: the three island telemetry files of the campaign
`v13_5kw_masslift_len18.8_rotorcount_bankderate2` (data commit dd3cc6a,
run a76c5e9, era post-95c385d_wind-authority).  310 rows per island,
columns x1..x10 beside fitness, status and the outcomes.

Run:
  /usr/bin/python3 docs/reporting/figures/pca-landscape/pca-landscape.py \
      --script-commit <hex>

Toolchain pin: /usr/bin/python3 (CPython 3.12.3), matplotlib 3.10.8,
numpy 2.4.4.  F-REPRO: svg.hashsalt set, SVG dc:date normalised, PDF and
PNG metadata fixed, no timestamps anywhere.

Outputs (in this directory): pca-landscape.svg / .pdf / .png,
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

import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
SLUG = "pca-landscape"
RD = REPO / "scripts" / "results" / "v13_5kw_masslift_len18.8_rotorcount_bankderate2"
ISLANDS = (1, 2, 3)

# ---------------------------------------------------------------- constants
DATA_COMMIT = "dd3cc6a"
RUN = "a76c5e9"
ERA = "post-95c385d_wind-authority"
ROWS = "NR-001, NR-005, NR-006"
ROW_WANTS = ["PCA projection summary (variance shares)"]
BINS = 18

INK = "#1a1a1a"
LINE = "#333333"
GREY = "#555555"
FAINT = "#777777"
MUTED = "#98a0a8"
BLUE_D = "#20558a"
ORANGE_D = "#a34a12"
ISLAND_COLOR = {1: "#4a7fb5", 2: "#2e8b57", 3: "#c1441e"}

GENES = ["r_hub", "r_bottom", "target_Lr", "n_lines", "density_profile",
         "rotor_count", "bank_top", "bank_bottom", "blade_scale_top",
         "blade_scale_bottom"]

TITLE = "V13 campaign — parameter-space landscape"
SUB = ("the 930-design screen · three DE islands · PC1-PC2 projection of the "
       "ten-gene search · colour is the search objective (kg)")

LEDGER: list[str] = []


def keep(s: str) -> str:
    LEDGER.append(s)
    return s


def txt(ax, x, y, s, **kw):
    return ax.text(x, y, keep(s), **kw)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_telemetry() -> list[dict]:
    rows: list[dict] = []
    for isl in ISLANDS:
        p = RD / f"island_{isl}" / "telemetry.csv"
        lines = [ln for ln in p.read_text().splitlines()
                 if not ln.startswith("#") and ln.strip()]
        got = list(csv.DictReader(lines))
        assert got, p
        rows.extend(got)
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script-commit", default="uncommitted")
    ap.add_argument("--outdir", default=str(HERE))
    args = ap.parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------ inputs
    for isl in ISLANDS:
        head = (RD / f"island_{isl}" / "telemetry.csv").read_text(
        ).splitlines()[0]
        assert f"era={ERA}" in head, head
        assert f"git={RUN}" in head, head

    rows = load_telemetry()
    per_isl = [sum(1 for r in rows if r["island"] == str(i))
               for i in ISLANDS]
    status_all = {s: sum(1 for r in rows if r["status"] == s)
                  for s in ("ok", "reject", "clearance_reject",
                            "reject_twist")}

    X = np.array([[float(r[f"x{i}"]) for i in range(1, 11)] for r in rows])
    fit = np.array([float(r["fitness"]) for r in rows])
    st = np.array([r["status"] for r in rows])
    gen = np.array([int(r["gen"]) for r in rows])
    isl_a = np.array([int(r["island"]) for r in rows])
    feas = (st == "ok") & (fit < 1e6)

    # ------------------------------------------------------------ projection
    mu = X.mean(axis=0)
    sd = X.std(axis=0, ddof=1)
    Xc = (X - mu) / sd
    _, S, Vt = np.linalg.svd(Xc, full_matrices=False)
    var = S**2 / (S**2).sum()
    V = Vt.T
    pc1 = Xc @ V[:, 0]
    pc2 = Xc @ V[:, 1]

    # clip window from the full-screen percentiles (same window in both kits)
    x1w, x2w = np.percentile(pc1, [1, 99])
    y1w, y2w = np.percentile(pc2, [1, 99])

    # best-so-far journey per island
    journeys = {}
    for isl in ISLANDS:
        pts = []
        for g in range(31):
            cand = np.where((isl_a == isl) & (gen <= g) & feas)[0]
            best = cand[np.argmin(fit[cand])]
            pts.append((pc1[best], pc2[best], fit[best]))
        journeys[isl] = pts

    seed_i = int(np.where((isl_a == 1) & (gen == 0))[0][0])
    win_i = int(np.argmin(np.where(feas, fit, np.inf)))
    for isl in ISLANDS:
        s_i = int(np.where((isl_a == isl) & (gen == 0))[0][0])
        assert abs(pc1[s_i] - pc1[seed_i]) < 1e-9
        assert abs(fit[s_i] - fit[seed_i]) < 1e-9

    # ------------------------------------------------------------ checks
    vmin = float(np.percentile(fit[feas], 2))
    vmax = float(np.percentile(fit[feas], 90))
    checks = [
        ("rows", len(rows), 930),
        ("rows per island", per_isl, [310, 310, 310]),
        ("status counts", status_all,
         {"ok": 508, "reject": 301, "clearance_reject": 110,
          "reject_twist": 11}),
        ("feasible rows", int(feas.sum()), 508),
        ("PC1 share (2 dp)", round(float(var[0]) * 100, 2), 22.43),
        ("PC2 share (2 dp)", round(float(var[1]) * 100, 2), 17.26),
        ("seed fit", float(fit[seed_i]), 36.109),
        ("seed pc", (round(float(pc1[seed_i]), 3), round(float(pc2[seed_i]), 3)),
         (0.531, -1.297)),
        ("winner fit", float(fit[win_i]), 27.364),
        ("winner island", int(isl_a[win_i]), 3),
        ("winner pc",
         (round(float(pc1[win_i]), 3), round(float(pc2[win_i]), 3)),
         (0.885, 2.869)),
        ("PC1 top loadings",
         [GENES[j] for j in np.argsort(-np.abs(V[:, 0]))[:3]],
         ["n_lines", "rotor_count", "blade_scale_top"]),
        ("PC2 top loadings",
         [GENES[j] for j in np.argsort(-np.abs(V[:, 1]))[:3]],
         ["bank_bottom", "blade_scale_bottom", "density_profile"]),
        ("PC1 share covers top three", bool(abs(V[3, 0]) > 0.5), True),
    ]
    for name, got, want in checks:
        ok = got == want
        print(f"check: {name}: {got}  ({'OK' if ok else 'FAIL'})")
        if not ok:
            return 1
    print(f"clip window: pc1 [{x1w:.3f}, {x2w:.3f}]  pc2 [{y1w:.3f}, {y2w:.3f}]")
    print(f"colour norm: vmin {vmin:.3f}  vmax {vmax:.3f}")

    shares = (f"{var[0]*100:.1f}", f"{var[1]*100:.1f}")

    # ------------------------------------------------------------ style
    plt.rcParams.update({
        "font.size": 8,
        "svg.hashsalt": "ktd-fig-pin-2026-10-13",
        "svg.fonttype": "none",
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "figure.facecolor": "white",
        "savefig.facecolor": "white",
    })

    fig = plt.figure(figsize=(11.2, 7.4))
    gs = fig.add_gridspec(2, 3, width_ratios=[3.0, 1.15, 1.15],
                          height_ratios=[4.0, 1.30], left=0.058, right=0.972,
                          top=0.885, bottom=0.145, hspace=0.38, wspace=0.22)
    ax_main = fig.add_subplot(gs[0, 0])
    ax_legend = fig.add_subplot(gs[0, 1])
    ax_pc1 = fig.add_subplot(gs[0, 2])
    ax_journey = fig.add_subplot(gs[1, 0])
    ax_pc2 = fig.add_subplot(gs[1, 1:])

    fig.text(0.058, 0.965, keep(TITLE), size=12.5, weight="bold", color=INK)
    fig.text(0.058, 0.930, keep(SUB), size=8.2, color=GREY)

    # ------------------------------------------------------------ main panel
    eff = feas & (pc1 >= x1w) & (pc1 <= x2w) & (pc2 >= y1w) & (pc2 <= y2w)
    Hw, _, _ = np.histogram2d(pc1[eff], pc2[eff], bins=BINS,
                              range=[[x1w, x2w], [y1w, y2w]],
                              weights=fit[eff])
    Hc, xe, ye = np.histogram2d(pc1[eff], pc2[eff], bins=BINS,
                                range=[[x1w, x2w], [y1w, y2w]])
    with np.errstate(invalid="ignore", divide="ignore"):
        H_avg = np.ma.masked_where(Hc == 0, Hw / Hc)

    im = ax_main.imshow(H_avg.T, origin="lower", aspect="auto",
                        extent=(x1w, x2w, y1w, y2w), cmap="viridis_r",
                        norm=Normalize(vmin=vmin, vmax=vmax),
                        interpolation="nearest")
    ax_main.set_xlim(x1w, x2w)
    ax_main.set_ylim(y1w, y2w)

    xc = (xe[:-1] + xe[1:]) / 2
    yc = (ye[:-1] + ye[1:]) / 2
    for lvl in (29.0, 31.0, 33.0):
        ax_main.contour(xc, yc, H_avg.T, levels=[lvl], colors="#444444",
                        linewidths=0.6, alpha=0.55, linestyles="--")

    for isl in ISLANDS:
        js = journeys[isl]
        xs = [p[0] for p in js]
        ys = [p[1] for p in js]
        big = isl == 3
        ax_main.plot(xs, ys, color=ISLAND_COLOR[isl], lw=2.1 if big else 1.3,
                     alpha=0.95 if big else 0.85, zorder=6,
                     solid_capstyle="round")

    ax_main.scatter([pc1[seed_i]], [pc2[seed_i]], marker="*", s=210,
                    c="#111111", edgecolors="white", linewidths=0.9,
                    zorder=9)
    for isl in (1, 2):
        ex, ey, _ = journeys[isl][-1]
        ax_main.scatter([ex], [ey], marker="o", s=52, facecolor="white",
                        edgecolors=ISLAND_COLOR[isl], linewidths=1.4,
                        zorder=8)
    ex, ey, _ = journeys[3][-1]
    ax_main.scatter([ex], [ey], marker="D", s=72, c=ISLAND_COLOR[3],
                    edgecolors="white", linewidths=1.0, zorder=9)

    bbox = dict(boxstyle="round,pad=0.22", facecolor="white", edgecolor="none",
                alpha=1.0)
    ax_main.annotate(keep("start 36.109"), (pc1[seed_i], pc2[seed_i]),
                     xytext=(10, -13), textcoords="offset points",
                     size=7.5, color=INK, zorder=10, bbox=bbox)
    ax_main.annotate(keep("island 1"), (journeys[1][-1][0], journeys[1][-1][1]),
                     xytext=(11, -3), textcoords="offset points",
                     size=7.5, color=ISLAND_COLOR[1], zorder=10, bbox=bbox)
    ax_main.annotate(keep("island 2"), (journeys[2][-1][0], journeys[2][-1][1]),
                     xytext=(-11, 7), textcoords="offset points", ha="right",
                     size=7.5, color=ISLAND_COLOR[2], zorder=10, bbox=bbox)
    ax_main.annotate(keep("winner 27.364"),
                     (journeys[3][-1][0], journeys[3][-1][1]),
                     xytext=(13, -4), textcoords="offset points", size=7.5,
                     color=ISLAND_COLOR[3], zorder=10, bbox=bbox)

    ax_main.set_xlabel(keep("PC1 — blade scale against unit count"), size=8.5)
    ax_main.set_ylabel(keep("PC2 — second-rotor and clustering settings"),
                       size=8.5)
    xt = [-5, -4, -3, -2, -1, 0, 1]
    yt = [-2, -1, 0, 1, 2, 3]
    ax_main.set_xticks(xt)
    ax_main.set_xticklabels([keep(f"{t}") for t in xt])
    ax_main.set_yticks(yt)
    ax_main.set_yticklabels([keep(f"{t}") for t in yt])
    ax_main.minorticks_off()
    ax_main.grid(color="#dddddd", lw=0.5, alpha=0.6, zorder=1)
    ax_main.set_axisbelow(True)
    for sp in ax_main.spines.values():
        sp.set_color("#bbbbbb")

    # ------------------------------------------------------------ colorbar
    ax_legend.set_axis_off()
    txt(ax_legend, 0.0, 0.96, "cell mean of the search", size=7.6, color=INK)
    txt(ax_legend, 0.0, 0.88, "objective (kg)", size=7.6, color=INK)
    cax = ax_legend.inset_axes([0.34, 0.40, 0.14, 0.42])
    cbar = fig.colorbar(im, cax=cax)
    cbar.set_ticks([30, 33, 36])
    cbar.ax.set_yticklabels([keep("30"), keep("33"), keep("36")])
    cbar.ax.tick_params(labelsize=7, length=2, color=LINE)
    cbar.outline.set_edgecolor("#bbbbbb")
    txt(ax_legend, 0.0, 0.30, "bright = lower objective", size=7.4, color=INK)
    txt(ax_legend, 0.0, 0.20, "feasible designs only;", size=7, color=FAINT)
    txt(ax_legend, 0.0, 0.11, "blank cells carry none", size=7, color=FAINT)

    # ------------------------------------------------------------ PC1 inset
    ax_pc1.set_axis_off()
    txt(ax_pc1, 0.0, 0.97, f"PC1 — {shares[0]}% of variance", size=9,
        weight="bold", color=INK)
    pc1_lines = [
        ("+ PC1 ↑", BLUE_D, "larger main-rotor blades (x9)"),
        ("", GREY, "wider spacing (x3), ground ring (x2)"),
        ("− PC1 ↓", ORANGE_D, "more TRPT lines (x4)"),
        ("", GREY, "more rotors (x6)"),
    ]
    for k, (mark, col, s) in enumerate(pc1_lines):
        y = 0.78 - k * 0.155
        if mark:
            txt(ax_pc1, 0.0, y, mark, size=8.2, weight="bold", color=col)
            y -= 0.105
        txt(ax_pc1, 0.0, y, s, size=7.6, color=GREY)
    txt(ax_pc1, 0.0, 0.10, "direction reads from the loadings", size=6.5,
        color=FAINT)

    # ------------------------------------------------------------ PC2 inset
    ax_pc2.set_axis_off()
    txt(ax_pc2, 0.0, 0.93, f"PC2 — {shares[1]}% of variance", size=9,
        weight="bold", color=INK)
    txt(ax_pc2, 0.0, 0.66, "+ PC2 ↑", size=8.2, weight="bold", color=BLUE_D)
    txt(ax_pc2, 0.13, 0.66, "deeper second-rotor bank (x8), smaller second "
        "blades (x10),", size=7.6, color=GREY)
    txt(ax_pc2, 0.13, 0.50, "rings biased toward the ground (x5)", size=7.6,
        color=GREY)
    txt(ax_pc2, 0.0, 0.26, "− PC2 ↓", size=8.2, weight="bold", color=ORANGE_D)
    txt(ax_pc2, 0.13, 0.26, "even rings, shallow second bank, larger second "
        "blades", size=7.6, color=GREY)

    # ------------------------------------------------------------ journey inset
    ax_journey.set_axis_off()
    txt(ax_journey, 0.0, 0.92, "THE THREE JOURNEYS", size=9, weight="bold",
        color=INK)
    txt(ax_journey, 0.0, 0.70, "930 designs · three islands · 31 generations "
        "each", size=7.8, color=GREY)
    txt(ax_journey, 0.0, 0.50, "one common seed at 36.109 (kg)", size=7.8,
        color=GREY)
    txt(ax_journey, 0.0, 0.30, "winner: island 3 at 27.364 (kg)", size=7.8,
        color=GREY)
    txt(ax_journey, 0.0, 0.08, "each line: the island best-so-far path, one "
        "step per generation", size=6.5, color=FAINT)

    # ------------------------------------------------------------ foot
    stamp1 = (f"source: island telemetry · data commit {DATA_COMMIT} · "
              f"run {RUN} · era {ERA} · rows {ROWS}")
    stamp2 = ("projection: z-scored 10-gene matrix, SVD · variance shares "
              f"pending their row · script commit {args.script_commit}")
    fig.text(0.058, 0.088, keep(stamp1), size=6.5, color=FAINT)
    fig.text(0.058, 0.050, keep(stamp2), size=6.5, color=FAINT)

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
    (outdir / "label-ledger.txt").write_text("\n".join(ledger) + "\n",
                                             encoding="utf-8")

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
        "script": {"path": f"docs/reporting/figures/{SLUG}/{SLUG}.py",
                   "sha256": sha256(Path(__file__).resolve())},
        "toolchain": {"python": ".".join(str(v) for v in sys.version_info[:3]),
                      "matplotlib": matplotlib.__version__,
                      "numpy": np.__version__},
        "inputs": {
            "telemetry": [
                {"path": (f"scripts/results/v13_5kw_masslift_len18.8_"
                          f"rotorcount_bankderate2/island_{i}/telemetry.csv"),
                 "sha256": sha256(RD / f"island_{i}" / "telemetry.csv")}
                for i in ISLANDS],
            "register_rows": ["NR-001", "NR-005", "NR-006"],
            "row_wants": ROW_WANTS,
        },
        "data_commit": DATA_COMMIT,
        "script_commit": args.script_commit,
        "command": (f"/usr/bin/python3 docs/reporting/figures/{SLUG}/{SLUG}.py "
                    f"--script-commit {args.script_commit}"),
        "precision": ("journey values as signed; variance shares at 1 dp; "
                      "colour norm at 2 dp internal"),
        "outputs": {f"{SLUG}.svg": sha256(svg), f"{SLUG}.pdf": sha256(pdf),
                    f"{SLUG}.png": sha256(png),
                    "label-ledger.txt": sha256(outdir / "label-ledger.txt")},
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
