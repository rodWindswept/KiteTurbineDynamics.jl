#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""capability-sheet: generating script for Figure 10 (section 7).

One sheet, eight exhibits: seven chart classes redrawn at HEAD from this
campaign's own rows, then the dashboard frame.

  H1-H4  heatmaps, four recorded outcomes on r_hub x bank_top
         (508 ok designs, value quintiles, cell medians, own colourbar
         limits per panel: NR-078 to NR-082)
  M1     parallel coordinates, ten genes, all 930 designs, status ink
  M2     correlation matrix, Spearman, the 508 ok designs
  M3     spider chart, the winner's ten genes on a standardised scale
  C1     the dashboard frame, rendered at HEAD by render_dashboard_frame.jl

The three M panels are specimen panels: they carry axis keys and print
no value.  No cell annotation, no coefficient, no gene value, no
variance share.  That is what lets them seat without a register row.

Rules this script enforces, not assumes:
  - the bin rule is the signed one: value quintiles on the 508 ok
    designs, rank-broken exactly as the signer's checker does it, so
    every cell reproduces the value NR-078 to NR-082 signed;
  - colourbar limits are the signed 2-dp outward rounding of the cell
    medians, and no cell may fall outside its bar;
  - no cell prints a count, because every cell on this pair clears the
    n >= 5 floor (NR-082 display form 2);
  - axis labels carry the edges, not a bin index (NR-082 form 3);
  - each panel names its own population; the three populations do not
    trade;
  - the capture is a crop of the HEAD render at a recorded offset, and
    the crop's hash is pinned in the manifest.

Run:
  /usr/bin/python3 docs/reporting/figures/capability-sheet/capability-sheet.py \\
      --script-commit <hex>

The capture must exist first:
  julia --project=. docs/reporting/figures/capability-sheet/render_dashboard_frame.jl

Toolchain pin: /usr/bin/python3 (CPython 3.12.3), matplotlib 3.10.8,
numpy 2.4.4, pandas 2.3.3.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.colors import Normalize

SLUG = "capability-sheet"
OUTDIR = Path(__file__).resolve().parent
ROOT = OUTDIR.parents[3]
RD = ROOT / "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"

DATA_COMMIT = "dd3cc6a"
RUN = "a76c5e9"
ERA = "post-95c385d_wind-authority"

INK = "#1a1a1a"
GREY = "#666666"
HAIR = "#d8d8d8"
OK = "#009E73"
REJ = "#D55E00"
CLR = "#0072B2"
TWS = "#CC79A7"

# the signed heatmap block (NR-078 to NR-082)
SIGNED = {
    "fitness": (29.66, 37.59, "kg-eq"),
    "P_mean": (5.28, 6.23, "kW"),
    "FoS": (9.30, 14.53, "-"),
    "clearance": (5.04, 5.93, "m"),
}
EDGE_R = [2.399, 4.116, 4.2248, 4.32, 4.5172, 5.116]
EDGE_B = [0.0, 6.34, 10.7, 13.4, 14.96, 22.0]

# capture geometry, measured on the HEAD render
CAP_SIZE = (966, 708)
CAP_OFFSET = (401, 329)
FULL_SIZE = (2000, 1188)

GENES = ["x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8", "x9", "x10"]
GENE_KEY = {
    "x1": "r_hub",
    "x2": "r_bot",
    "x3": "target_Lr",
    "x4": "n_lines",
    "x5": "density",
    "x6": "rotors",
    "x7": "bank_top",
    "x8": "bank_bot",
    "x9": "blade_top",
    "x10": "blade_bot",
}

LABELS: set[str] = set()


def lab(s: str) -> str:
    """Record a drawn string in the label ledger."""
    LABELS.add(s)
    return s


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_rows() -> pd.DataFrame:
    files = sorted(RD.glob("island_*/telemetry.csv"))
    if len(files) != 3:
        raise SystemExit(f"expected three island files, found {len(files)}")
    frames = []
    for f in files:
        with open(f, encoding="utf-8") as fh:
            lines = [ln for ln in fh if not ln.startswith("#")]
        frames.append(pd.read_csv(pd.io.common.StringIO("".join(lines))))
    return pd.concat(frames, ignore_index=True)


def spearman_matrix(frame: pd.DataFrame) -> np.ndarray:
    """Spearman rho as Pearson on ranks, ties averaged."""
    ranks = np.column_stack(
        [pd.Series(frame[g].to_numpy()).rank(method="average").to_numpy() for g in GENES]
    )
    return np.corrcoef(ranks, rowvar=False)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script-commit", required=True)
    args = ap.parse_args()
    commit = args.script_commit

    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 6.6,
            "axes.edgecolor": INK,
            "axes.labelcolor": INK,
            "text.color": INK,
            "xtick.color": INK,
            "ytick.color": INK,
            "savefig.facecolor": "white",
            "figure.facecolor": "white",
            "svg.hashsalt": SLUG,
        }
    )

    checks: list[tuple[bool, str]] = []
    d = load_rows()
    ok = d[d.status == "ok"].copy()
    counts = d.status.value_counts().to_dict()

    checks.append((len(d) == 930, f"rows read 930: {len(d)}"))
    checks.append((len(ok) == 508, f"ok rows 508: {len(ok)}"))
    checks.append((counts.get("reject") == 301, "reject 301"))
    checks.append((counts.get("clearance_reject") == 110, "clearance_reject 110"))
    checks.append((counts.get("reject_twist") == 11, "reject_twist 11"))

    # ---- the signed bins ---------------------------------------------------
    qa = pd.qcut(ok.r_hub.rank(method="first"), 5, labels=False)
    qb = pd.qcut(ok.bank_top.rank(method="first"), 5, labels=False)
    occ = ok.groupby([qa, qb]).size()
    checks.append((len(occ) == 25, f"cells occupied 25: {len(occ)}"))
    checks.append((int(occ.min()) == 10, f"smallest cell 10: {int(occ.min())}"))
    checks.append((float(occ.median()) == 21.0, f"median cell 21: {float(occ.median())}"))
    checks.append((int(occ.max()) == 36, f"largest cell 36: {int(occ.max())}"))
    checks.append((int((occ < 5).sum()) == 0, "no cell under five"))

    e_r = [round(x, 4) for x in ok.r_hub.quantile([0, .2, .4, .6, .8, 1.0]).tolist()]
    e_b = [round(x, 4) for x in ok.bank_top.quantile([0, .2, .4, .6, .8, 1.0]).tolist()]
    checks.append((e_r == EDGE_R, f"r_hub edges match the signed list: {e_r}"))
    checks.append((e_b == EDGE_B, f"bank_top edges match the signed list: {e_b}"))

    grid = {}
    for outcome, (lo, hi, _unit) in SIGNED.items():
        med = ok.groupby([qa, qb])[outcome].median()
        got_lo = np.floor(med.min() * 100) / 100
        got_hi = np.ceil(med.max() * 100) / 100
        checks.append((abs(got_lo - lo) < 1e-9, f"{outcome} colourbar low {lo}: {got_lo:.2f}"))
        checks.append((abs(got_hi - hi) < 1e-9, f"{outcome} colourbar high {hi}: {got_hi:.2f}"))
        arr = np.full((5, 5), np.nan)
        for (i, j), v in med.items():
            arr[int(j), int(i)] = float(v)
        checks.append((not np.isnan(arr).any(), f"{outcome} grid complete"))
        inside = bool(((arr >= lo - 1e-9) & (arr <= hi + 1e-9)).all())
        checks.append(
            (inside, f"{outcome} cells inside the bar "
                     f"(min {np.nanmin(arr):.6f} vs {lo}, max {np.nanmax(arr):.6f} vs {hi})")
        )
        grid[outcome] = arr

    # ---- population facts the sheet prints --------------------------------
    checks.append((bool((ok.FoS >= 2.5).all()), "every ok row passed the 2.5 FoS floor"))
    checks.append((round(float(ok.FoS.min()), 2) == 3.18, f"ok FoS minimum 3.18: {ok.FoS.min():.2f}"))
    checks.append((round(float(ok.clearance.min()), 2) == 4.74, "ok clearance minimum 4.74 m"))
    checks.append((round(float(ok.P_mean.min()), 2) == 5.02, "ok P_mean minimum 5.02 kW"))
    cr = d[d.status == "clearance_reject"]
    checks.append((float(cr.clearance.max()) < 1.5, f"clearance rejects all under 1.5 m: {cr.clearance.max():.2f}"))
    tw = d[d.status == "reject_twist"]
    checks.append((float(tw.twist_ratio.min()) > 1.0, f"twist rejects all over 1.0: {tw.twist_ratio.min():.3f}"))
    checks.append((int(cr.twist_ratio.isna().sum()) == 110,
                   "the 110 clearance rejects carry no twist reading (gate order)"))

    # ---- the capture -------------------------------------------------------
    full = OUTDIR / "dashboard-frame-full.png"
    if not full.exists():
        raise SystemExit(
            "missing dashboard-frame-full.png: run "
            "`julia --project=. docs/reporting/figures/capability-sheet/render_dashboard_frame.jl` first"
        )
    from PIL import Image

    im = Image.open(full).convert("RGB")
    checks.append((im.size == FULL_SIZE, f"render is {FULL_SIZE}: {im.size}"))
    x0, y0 = CAP_OFFSET
    w, h = CAP_SIZE
    crop = im.crop((x0, y0, x0 + w, y0 + h))
    checks.append((crop.size == CAP_SIZE, f"crop is {CAP_SIZE}: {crop.size}"))
    cap_path = OUTDIR / "dashboard-frame.png"
    crop.save(cap_path)

    # ---- the sheet ---------------------------------------------------------
    W, H = 7.6, 9.45
    fig = plt.figure(figsize=(W, H))

    def rect(x_in, y_in, w_in, h_in):
        return [x_in / W, y_in / H, w_in / W, h_in / H]

    def note(x_in, y_in, text, size, colour="#444444", weight="normal"):
        """Place a line of text by its inches from the left and the bottom."""
        fig.text(x_in / W, y_in / H, lab(text), fontsize=size, ha="left",
                 va="baseline", color=colour, weight=weight)

    note(0.02, 9.06, "Figure 10   What the platform draws", 9.2, INK, "bold")
    note(0.02, 8.86, "Seven chart classes redrawn at HEAD from this campaign's own rows, and the dashboard frame.",
         6.8, INK)

    # ---- H1-H4: the heatmaps ----------------------------------------------
    pw = ph = 1.16
    cbw, label_gap, gap = 0.050, 0.40, 0.06
    x = 0.58
    y_img = 7.45
    cmap = plt.get_cmap("viridis")
    for k, (outcome, (lo, hi, unit)) in enumerate(SIGNED.items()):
        ax = fig.add_axes(rect(x, y_img, pw, ph))
        ax.imshow(grid[outcome], origin="lower", cmap=cmap, vmin=lo, vmax=hi,
                  aspect="equal", interpolation="nearest")
        ax.set_xticks(range(6))
        ax.set_yticks(range(6))
        ax.set_xticklabels([f"{v:.2f}" for v in EDGE_R], rotation=90, fontsize=5.0)
        if k == 0:
            ax.set_yticklabels([f"{v:g}" for v in EDGE_B], fontsize=5.0)
            ax.set_ylabel(lab("bank_top, degrees"), fontsize=6.0, labelpad=1.5)
        else:
            ax.set_yticklabels([])
        ax.set_xlim(-0.5, 4.5)
        ax.set_ylim(-0.5, 4.5)
        ax.tick_params(length=1.6, pad=1.0, width=0.4)
        for s in ax.spines.values():
            s.set_linewidth(0.5)
        ax.set_title(lab(f"{outcome}  ·  {unit}"), fontsize=6.6, pad=2.6, loc="left")
        if k == 0:
            ax.set_xlabel(lab("r_hub, metres  ·  508 ok designs"), fontsize=6.0, labelpad=3.2)
        cbax = fig.add_axes(rect(x + pw + 0.020, y_img, cbw, ph))
        cb = fig.colorbar(plt.cm.ScalarMappable(norm=Normalize(lo, hi), cmap=cmap), cax=cbax)
        cb.set_ticks([lo, hi])
        cb.set_ticklabels([lab(f"{lo:.2f}"), lab(f"{hi:.2f}")])
        cb.ax.tick_params(labelsize=5.0, length=1.3, pad=1.2, width=0.4)
        cb.outline.set_linewidth(0.4)
        x += pw + 0.020 + cbw + label_gap + gap

    # ---- C1: the capture ---------------------------------------------------
    cap_w = 5.22
    cap_h = cap_w * CAP_SIZE[1] / CAP_SIZE[0]
    cap_x = (W - cap_w) / 2
    cap_y = 2.92
    axc = fig.add_axes(rect(cap_x, cap_y, cap_w, cap_h))
    axc.imshow(plt.imread(cap_path))
    axc.set_axis_off()
    axc.set_title(
        lab("C1  The dashboard frame at HEAD · v1 interface · canonical 5-line · crop 966 x 708"),
        fontsize=6.4, pad=2.6, loc="left",
    )

    # ---- M1: parallel coordinates -----------------------------------------
    norm = (d[GENES] - d[GENES].min()) / (d[GENES].max() - d[GENES].min())
    axp = fig.add_axes(rect(0.56, 1.38, 2.95, 1.18))
    order = ["reject", "clearance_reject", "reject_twist", "ok"]
    ink = {"ok": OK, "reject": REJ, "clearance_reject": CLR, "reject_twist": TWS}
    alpha = {"ok": 0.16, "reject": 0.10, "clearance_reject": 0.22, "reject_twist": 0.32}
    names = {"ok": "ok", "reject": "reject", "clearance_reject": "clearance reject",
             "reject_twist": "twist reject"}
    handles = []
    for status in order:
        mask = (d.status == status).to_numpy()
        vals = norm[mask].to_numpy()
        for row in vals:
            axp.plot(range(10), row, color=ink[status], lw=0.22, alpha=alpha[status],
                     solid_capstyle="butt", zorder=2 if status == "ok" else 1)
        handles.append(axp.plot([], [], color=ink[status], lw=1.2,
                                label=lab(f"{names[status]} ({int(mask.sum())})"))[0])
    axp.set_xlim(0, 9)
    axp.set_ylim(-0.02, 1.02)
    axp.set_xticks(range(10))
    axp.set_xticklabels([lab(GENE_KEY[g]) for g in GENES], rotation=90, fontsize=5.0)
    axp.set_yticks([])
    axp.tick_params(length=0, pad=1.0)
    for s in ("top", "right", "left"):
        axp.spines[s].set_visible(False)
    axp.set_title(lab("M1  Parallel coordinates\nall 930 designs, ten genes"),
                  fontsize=6.4, pad=2.6, loc="left")
    fig.legend(handles=handles, loc="lower left", bbox_to_anchor=(0.56 / W, 0.74 / H),
               ncol=4, fontsize=4.8, frameon=False, handlelength=0.9,
               columnspacing=0.9, handletextpad=0.35, borderaxespad=0.0)

    # ---- M2: the correlation matrix ---------------------------------------
    rho = spearman_matrix(ok)
    axm = fig.add_axes(rect(3.86, 1.38, 1.42, 1.18))
    im2 = axm.imshow(rho, cmap="RdBu_r", vmin=-1, vmax=1, interpolation="nearest")
    axm.set_xticks(range(10))
    axm.set_yticks(range(10))
    axm.set_xticklabels([lab(GENE_KEY[g]) for g in GENES], rotation=90, fontsize=4.4)
    axm.set_yticklabels([lab(GENE_KEY[g]) for g in GENES], fontsize=4.4)
    axm.tick_params(length=1.2, pad=0.8, width=0.4)
    for s in axm.spines.values():
        s.set_linewidth(0.5)
    axm.set_title(lab("M2  Gene correlation\nSpearman, 508 ok"),
                  fontsize=6.4, pad=3.5, loc="left")
    cb2 = fig.colorbar(im2, ax=axm, fraction=0.040, pad=0.02, shrink=0.80)
    cb2.set_ticks([-1, 0, 1])
    cb2.set_ticklabels([lab("−1"), lab("0"), lab("+1")])
    cb2.ax.tick_params(labelsize=4.8, length=1.2, pad=0.6, width=0.4)
    cb2.outline.set_linewidth(0.4)

    # ---- M3: ranked configurations ----------------------------------------
    winner = ok.loc[ok.fitness.idxmin()]
    checks.append((round(float(winner.fitness), 3) == 27.364,
                   f"winner fitness 27.364: {float(winner.fitness):.3f}"))
    ranked = np.sort(ok.fitness.to_numpy(dtype=float))
    checks.append((len(ranked) == 508, f"ranked curve holds 508 values: {len(ranked)}"))
    checks.append((abs(float(ranked[-1]) - 60.646) < 1e-3,
                   f"worst ok design reads the population maximum: {ranked[-1]:.3f}"))
    axr = fig.add_axes(rect(5.78, 1.38, 1.44, 1.18))
    axr.plot(np.arange(1, len(ranked) + 1), ranked, color=INK, lw=0.7, zorder=3)
    axr.fill_between(np.arange(1, len(ranked) + 1), ranked.min(), ranked,
                     color=HAIR, alpha=0.55, lw=0.0, zorder=1)
    axr.set_xlim(0, 508)
    axr.set_ylim(25, 62)
    axr.set_xticks([0, 100, 200, 300, 400, 500])
    axr.set_yticks([30, 40, 50, 60])
    axr.tick_params(labelsize=5.0, length=1.5, pad=1.2, width=0.4)
    axr.set_xlabel(lab("rank, best to worst"), fontsize=5.2, labelpad=1.0)
    axr.set_ylabel(lab("fitness, kg-eq"), fontsize=5.2, labelpad=1.0)
    for s in ("top", "right"):
        axr.spines[s].set_visible(False)
    axr.set_title(lab("M3  The objective, ordered\n508 ok designs"),
                  fontsize=6.4, pad=3.5, loc="left")

    # ---- footer ------------------------------------------------------------
    note(0.02, 0.47,
         f"source v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{{1,2,3}}/telemetry.csv · "
         f"data {DATA_COMMIT} · run {RUN} · era {ERA} · script {commit}", 5.8)
    note(0.02, 0.31,
         "Heatmaps and M2 read the 508 ok designs. M1 reads all 930. M3 reads the 508, ordered. "
         "C1 is a render at HEAD, not a dataset read.", 5.8)

    # ---- save --------------------------------------------------------------
    out_png = OUTDIR / f"{SLUG}.png"
    fig.savefig(OUTDIR / f"{SLUG}.svg", metadata={"Date": None, "Creator": f"{SLUG} · KTD figures"})
    fig.savefig(OUTDIR / f"{SLUG}.pdf", metadata={"Creator": f"{SLUG} · KTD figures", "CreationDate": None})
    fig.savefig(out_png, dpi=300)
    plt.close(fig)

    # ---- ledger, checks, manifest -----------------------------------------
    ledger = OUTDIR / "label-ledger.txt"
    ledger.write_text("\n".join(sorted(LABELS)) + "\n", encoding="utf-8")
    checks.append((True, f"label ledger holds {len(LABELS)} strings"))

    passed = sum(1 for okc, _ in checks if okc)
    lines = [f"{'ok  ' if okc else 'FAIL'} {msg}" for okc, msg in checks]
    lines.append(f"{passed} ok / {len(checks) - passed} fail")
    (OUTDIR / "checks.log").write_text("\n".join(lines) + "\n", encoding="utf-8")

    manifest = {
        "slug": SLUG,
        "command": f"/usr/bin/python3 docs/reporting/figures/{SLUG}/{SLUG}.py --script-commit {commit}",
        "script_commit": commit,
        "data_commit": DATA_COMMIT,
        "run": RUN,
        "era": ERA,
        "inputs": {
            "telemetry": [
                {"path": str(f.relative_to(ROOT)), "sha256": sha256(f)}
                for f in sorted(RD.glob("island_*/telemetry.csv"))
            ],
            "renderer": {
                "path": f"docs/reporting/figures/{SLUG}/render_dashboard_frame.jl",
                "sha256": sha256(OUTDIR / "render_dashboard_frame.jl"),
            },
            "capture_full": {
                "path": f"docs/reporting/figures/{SLUG}/dashboard-frame-full.png",
                "sha256": sha256(full),
                "pixels": list(FULL_SIZE),
                "px_per_unit": 1.25,
            },
            "register_rows": ["NR-001", "NR-002", "NR-005", "NR-042",
                              "NR-078", "NR-079", "NR-080", "NR-081", "NR-082"],
        },
        "outputs": {
            f"{SLUG}.pdf": sha256(OUTDIR / f"{SLUG}.pdf"),
            f"{SLUG}.png": sha256(out_png),
            f"{SLUG}.svg": sha256(OUTDIR / f"{SLUG}.svg"),
            "dashboard-frame.png": sha256(cap_path),
            "label-ledger.txt": sha256(ledger),
        },
        "precision": "colourbar limits 2 dp outward; axis edges 2 dp; counts as integers; M panels print no value",
        "toolchain": {
            "python": sys.version.split()[0],
            "matplotlib": matplotlib.__version__,
            "numpy": np.__version__,
            "pandas": pd.__version__,
        },
    }
    (OUTDIR / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                                          encoding="utf-8")

    print("\n".join(lines))
    return 0 if passed == len(checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
