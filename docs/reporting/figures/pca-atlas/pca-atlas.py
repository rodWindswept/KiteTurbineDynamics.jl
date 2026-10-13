#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""pca-atlas: generating script for the parameter-atlas plate (PCA redo).

Plate: docs/reporting/figures/pca-atlas/SPEC.md (GENERATE stage).
Draws the same PC1-PC2 projection as `pca-landscape`, coloured once per
gene panel.  Ten panels, one per gene slot (x1..x10).  The layout
framework is the old campaign atlas; the gene set is the reduced ten.

Inputs: the three island telemetry files of the campaign
`v13_5kw_masslift_len18.8_rotorcount_bankderate2` (data commit dd3cc6a,
run a76c5e9, era post-95c385d_wind-authority).  310 rows per island,
columns x1..x10 beside fitness, status and the outcomes.

Run:
  /usr/bin/python3 docs/reporting/figures/pca-atlas/pca-atlas.py \
      --script-commit <hex>

Toolchain pin: /usr/bin/python3 (CPython 3.12.3), matplotlib 3.10.8,
numpy 2.4.4.  F-REPRO: svg.hashsalt set, SVG dc:date normalised, PDF and
PNG metadata fixed, no timestamps anywhere.

Outputs (in this directory): pca-atlas.svg / .pdf / .png,
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
SLUG = "pca-atlas"
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
ISLAND_COLOR = {1: "#4a7fb5", 2: "#2e8b57", 3: "#c1441e"}

# x-slot, label, colour map
GENES = [
    ("x1", "r_hub (m)", "viridis"),
    ("x2", "r_bottom (m)", "plasma"),
    ("x3", "target_Lr (ratio)", "magma"),
    ("x4", "n_lines (count)", "cividis"),
    ("x5", "density_profile", "coolwarm"),
    ("x6", "rotor_count (count)", "YlGnBu"),
    ("x7", "bank_top (°)", "YlOrRd"),
    ("x8", "bank_bottom (°)", "RdPu"),
    ("x9", "blade_scale_top", "PuBuGn"),
    ("x10", "blade_scale_bottom", "BuPu"),
]

TITLE = "V13 campaign — parameter atlas"
SUB = ("the same PC1-PC2 projection, coloured once per gene · PC1 → "
       "horizontal, PC2 ↑ vertical · star = common seed, diamond = winner · "
       "thin lines = island journeys")

LEDGER: list[str] = []


def keep(s: str) -> str:
    LEDGER.append(s)
    return s


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

    mu = X.mean(axis=0)
    sd = X.std(axis=0, ddof=1)
    Xc = (X - mu) / sd
    _, S, Vt = np.linalg.svd(Xc, full_matrices=False)
    var = S**2 / (S**2).sum()
    V = Vt.T
    pc1 = Xc @ V[:, 0]
    pc2 = Xc @ V[:, 1]

    x1w, x2w = np.percentile(pc1, [1, 99])
    y1w, y2w = np.percentile(pc2, [1, 99])

    journeys = {}
    for isl in ISLANDS:
        pts = []
        for g in range(31):
            cand = np.where((isl_a == isl) & (gen <= g) & feas)[0]
            best = cand[np.argmin(fit[cand])]
            pts.append((pc1[best], pc2[best]))
        journeys[isl] = pts

    seed_i = int(np.where((isl_a == 1) & (gen == 0))[0][0])
    win_i = int(np.argmin(np.where(feas, fit, np.inf)))

    checks = [
        ("rows", len(rows), 930),
        ("rows per island", per_isl, [310, 310, 310]),
        ("status counts", status_all,
         {"ok": 508, "reject": 301, "clearance_reject": 110,
          "reject_twist": 11}),
        ("feasible rows", int(feas.sum()), 508),
        ("PC1 share (2 dp)", round(float(var[0]) * 100, 2), 22.43),
        ("PC2 share (2 dp)", round(float(var[1]) * 100, 2), 17.26),
        ("seed pc", (round(float(pc1[seed_i]), 3), round(float(pc2[seed_i]), 3)),
         (0.531, -1.297)),
        ("winner fit", float(fit[win_i]), 27.364),
        ("winner pc",
         (round(float(pc1[win_i]), 3), round(float(pc2[win_i]), 3)),
         (0.885, 2.869)),
    ]
    for name, got, want in checks:
        ok = got == want
        print(f"check: {name}: {got}  ({'OK' if ok else 'FAIL'})")
        if not ok:
            return 1
    print(f"clip window: pc1 [{x1w:.3f}, {x2w:.3f}]  pc2 [{y1w:.3f}, {y2w:.3f}]")

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

    fig = plt.figure(figsize=(16.2, 7.6))
    gs = fig.add_gridspec(2, 5, left=0.045, right=0.985, top=0.845,
                          bottom=0.125, wspace=0.30, hspace=0.58)

    fig.text(0.045, 0.955, keep(TITLE), size=13.5, weight="bold", color=INK)
    fig.text(0.045, 0.912, keep(SUB), size=8.5, color=GREY)

    Hc_all, xe, ye = np.histogram2d(pc1, pc2, bins=BINS,
                                    range=[[x1w, x2w], [y1w, y2w]])

    for k, (slot, label, cmap) in enumerate(GENES):
        ax = fig.add_subplot(gs[k // 5, k % 5])
        j = int(slot[1:]) - 1
        col = X[:, j]
        Hw, _, _ = np.histogram2d(pc1, pc2, bins=BINS,
                                  range=[[x1w, x2w], [y1w, y2w]],
                                  weights=col)
        with np.errstate(invalid="ignore", divide="ignore"):
            H_avg = np.ma.masked_where(Hc_all == 0, Hw / Hc_all)
        lo, hi = np.percentile(col, [2, 98])
        im = ax.imshow(H_avg.T, origin="lower", aspect="auto",
                       extent=(x1w, x2w, y1w, y2w), cmap=cmap,
                       norm=Normalize(vmin=lo, vmax=hi),
                       interpolation="nearest")
        ax.set_xlim(x1w, x2w)
        ax.set_ylim(y1w, y2w)
        ax.set_xticks([])
        ax.set_yticks([])
        ax.set_title(keep(f"{slot}  {label}"), size=8.5, weight="bold",
                     color=INK, pad=4)
        for sp in ax.spines.values():
            sp.set_color("#bbbbbb")
        ax.axhline(0, color="#ffffff", lw=0.5, alpha=0.55, zorder=2)
        ax.axvline(0, color="#ffffff", lw=0.5, alpha=0.55, zorder=2)
        for isl in ISLANDS:
            xs = [p[0] for p in journeys[isl]]
            ys = [p[1] for p in journeys[isl]]
            ax.plot(xs, ys, color=ISLAND_COLOR[isl], lw=1.0, alpha=0.65,
                    zorder=5)
        ax.scatter([pc1[seed_i]], [pc2[seed_i]], marker="*", s=70,
                   c="#111111", edgecolors="white", linewidths=0.6, zorder=7)
        ax.scatter([pc1[win_i]], [pc2[win_i]], marker="D", s=36,
                   c=ISLAND_COLOR[3], edgecolors="white", linewidths=0.7,
                   zorder=7)

        cax = ax.inset_axes([0.0, -0.12, 1.0, 0.042])
        cbar = fig.colorbar(im, cax=cax, orientation="horizontal")
        mid = (lo + hi) / 2
        ticks = [lo, mid, hi]
        cbar.set_ticks(ticks)
        cbar.ax.set_xticklabels([keep(f"{v:.3g}") for v in ticks])
        cbar.ax.tick_params(labelsize=5.5, length=1.5, pad=1.5, color=LINE)
        cbar.outline.set_edgecolor("#cccccc")

    stamp1 = (f"source: island telemetry · data commit {DATA_COMMIT} · "
              f"run {RUN} · era {ERA} · rows {ROWS}")
    stamp2 = ("projection: z-scored 10-gene matrix, SVD · gene values over "
              f"all 930 designs · script commit {args.script_commit}")
    fig.text(0.045, 0.045, keep(stamp1), size=6.5, color=FAINT)
    fig.text(0.045, 0.016, keep(stamp2), size=6.5, color=FAINT)

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
        "precision": ("gene values at 3 significant figures on the colour "
                      "bars; panel scales as drawn"),
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
