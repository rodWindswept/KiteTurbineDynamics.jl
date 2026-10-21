#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""lever-set: generating script for the row-8 plates (the lever set).

Plate A: the sensitivity rank bar, then the response surface.
Plate B: the disqualification census, then the charge waterfall.

Sources (all committed, item-5 extract at 6c51f5c):
  docs/reporting/figures/lever-statistics-extract/
      extract-objective-vs-gene.csv        (10 rows, NR-074)
      extract-objective-by-gene-bins.csv   (46 rows, NR-077)
      extract-failure-rates-by-value.csv   (13 rows, NR-075)
      extract-penalty-summary.csv          (4 rows, NR-076)

Signed rows: NR-074, NR-075, NR-076, NR-077 (science-validator, 2026-10-21).
Slot ruling: two plates of two panels (author, eb7e64a + bf22566).

Rules this script enforces, not assumes:
  - the response surface drops every bin under five designs (NR-077 floor);
  - the rank bar greys every row under five designs at either end, and no
    caption may take an order from it (NR-074);
  - each plate names its own population: 508 ok designs for the bar and
    the waterfall, 930 designs for the census;
  - every drawn number recomputes from the source CSV in-script.

Run:
  /usr/bin/python3 docs/reporting/figures/lever-set/lever-set.py \
      --script-commit <hex>

Toolchain pin: /usr/bin/python3 (CPython 3.12.3), matplotlib 3.10.8.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import numpy as np

SLUG = "lever-set"
OUTDIR = Path(__file__).resolve().parent
ROOT = OUTDIR.parents[3]
EXTRACT = ROOT / "docs/reporting/figures/lever-statistics-extract"

FLOOR_N = 5
DATA_COMMIT = "dd3cc6a"
RUN = "a76c5e9"

INK = "#1a1a1a"
GREY = "#999999"
OK = "#009E73"
REJ = "#D55E00"
CLR = "#0072B2"
TWS = "#CC79A7"
THIN = "#c8c8c8"

LABELS: set[str] = set()


def lab(s: str) -> str:
    """Record a drawn string in the label ledger."""
    LABELS.add(s)
    return s


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_table(name: str) -> list[dict]:
    with open(EXTRACT / name, encoding="utf-8") as fh:
        lines = [ln for ln in fh if not ln.startswith("#")]
    return list(csv.DictReader(lines))


def close(a: float, b: float, tol: float = 1e-12) -> bool:
    return abs(a - b) <= tol * max(1.0, abs(a), abs(b))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script-commit", required=True)
    args = ap.parse_args()
    commit = args.script_commit

    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 7.5,
            "axes.edgecolor": INK,
            "axes.labelcolor": INK,
            "text.color": INK,
            "xtick.color": INK,
            "ytick.color": INK,
            "savefig.facecolor": "white",
            "figure.facecolor": "white",
            "svg.hashsalt": "lever-set",
        }
    )

    sens = read_table("extract-objective-vs-gene.csv")
    bins = read_table("extract-objective-by-gene-bins.csv")
    rates = read_table("extract-failure-rates-by-value.csv")
    pen = read_table("extract-penalty-summary.csv")

    checks: list[tuple[bool, str]] = []

    # ---- assemble the sensitivity set -------------------------------------
    pop = {}
    for b in bins:
        pop.setdefault(b["gene"], {})[b["bin"]] = int(b["n"])
    rows = []
    for r in sens:
        g = r["gene"]
        rho = float(r["spearman_rho"])
        d = float(r["delta_med_kg"])
        lo, hi = r["bottom_bin"], r["top_bin"]
        nlo, nhi = pop[g][lo], pop[g][hi]
        rows.append(
            {
                "gene": g,
                "slot": r["slot"],
                "rho": rho,
                "delta": d,
                "lo": lo,
                "hi": hi,
                "nlo": nlo,
                "nhi": nhi,
                "thin": nlo < FLOOR_N or nhi < FLOOR_N,
            }
        )
    rows.sort(key=lambda x: abs(x["delta"]))
    thin_rows = [x for x in rows if x["thin"]]
    checks.append((len(rows) == 10, f"sensitivity rows read 10: {len(rows)}"))
    checks.append((len(thin_rows) == 2, f"thin rows read 2: {len(thin_rows)}"))

    # ---- plate A ----------------------------------------------------------
    figA = plt.figure(figsize=(7.6, 8.9))
    gsA = figA.add_gridspec(
        2, 1, height_ratios=[1.0, 1.15], hspace=0.42,
        left=0.345, right=0.925, top=0.905, bottom=0.085,
    )

    axA1 = figA.add_subplot(gsA[0])
    ypos = np.arange(len(rows))
    for y, r in zip(ypos, rows):
        colour = THIN if r["thin"] else OK
        axA1.barh(
            y, r["delta"], height=0.62, color=colour,
            edgecolor=INK if r["thin"] else "none",
            linewidth=0.6 if r["thin"] else 0.0,
            hatch="///" if r["thin"] else None, zorder=3,
        )
        axA1.text(
            29.2, y,
            lab(f"{r['delta']:+.2f} kg-eq  (rho {r['rho']:+.2f})"),
            va="center", ha="left", fontsize=6.6, color=INK,
        )
    axA1.set_yticks(ypos)
    axA1.set_yticklabels(
        [f"{r['gene']}  ({r['slot']})\n{r['lo']} to {r['hi']},  {r['nlo']} / {r['nhi']} designs" for r in rows],
        fontsize=6.6,
    )
    axA1.axvline(0, color=INK, lw=0.7)
    axA1.set_xlim(-9.5, 45.5)
    axA1.set_ylim(-0.7, len(rows) - 0.3)
    axA1.set_xlabel(lab("median shift from the gene's lowest bin to its highest, kg-equivalent"), fontsize=7.2)
    axA1.set_title(
        lab("A1  Which gene moves the objective. Grey rows hold under five designs at one end."),
        fontsize=8.0, loc="left", pad=6,
    )
    axA1.grid(axis="x", color="#e6e6e6", lw=0.5, zorder=0)
    axA1.set_axisbelow(True)
    for s in ("top", "right"):
        axA1.spines[s].set_visible(False)

    axA2 = figA.add_subplot(gsA[1])
    genes = [r["gene"] for r in rows]
    bin_order: dict[str, list[str]] = {}
    for g in genes:
        gb = [b for b in bins if b["gene"] == g]
        gb.sort(key=lambda b: float(b["lo"]))
        bin_order[g] = [b["bin"] for b in gb]
    med_by_gene = {}
    for r in bins:
        med_by_gene.setdefault(r["gene"], {})[r["bin"]] = (int(r["n"]), float(r["median_fitness"]))
    vals = [v[1] for g in genes for v in med_by_gene[g].values() if v[0] >= FLOOR_N]
    vmin, vmax = min(vals), max(vals)
    cmap = plt.get_cmap("viridis")
    dropped = 0
    for i, g in enumerate(genes):
        ks = bin_order[g]
        k = len(ks)
        for j, bl in enumerate(ks):
            n, med = med_by_gene[g][bl]
            x0 = j / k
            w = 1.0 / k
            if n < FLOOR_N:
                dropped += 1
                axA2.add_patch(plt.Rectangle((x0, i - 0.34), w - 0.008, 0.68,
                                             facecolor="#ffffff", edgecolor=GREY,
                                             lw=0.6, hatch="////", zorder=3))
                axA2.text(x0 + w / 2, i, lab(f"n={n}\nno read"), ha="center", va="center",
                          fontsize=4.9, color="#777777", linespacing=1.05, zorder=4,
                          clip_on=True)
            else:
                frac = (med - vmin) / (vmax - vmin) if vmax > vmin else 0.5
                axA2.add_patch(plt.Rectangle((x0, i - 0.34), w - 0.008, 0.68,
                                             facecolor=cmap(0.08 + 0.84 * frac),
                                             edgecolor="white", lw=0.8, zorder=3))
                axA2.text(x0 + w / 2, i, lab(f"n={n}"), ha="center", va="center",
                          fontsize=5.8, color="white" if frac < 0.62 else INK, zorder=4)
    checks.append((dropped == 4, f"surface drops four bins under five: {dropped}"))
    axA2.set_xlim(0, 1)
    axA2.set_ylim(-0.6, len(genes) - 0.4)
    axA2.set_yticks(range(len(genes)))
    axA2.set_yticklabels(
        [lab(f"{g}  ({rows[i]['slot']})  ·  {len(bin_order[g])} bins") for i, g in enumerate(genes)],
        fontsize=6.6,
    )
    axA2.set_xticks([])
    axA2.set_xlabel(lab("bins of each gene, lowest to highest. Strip width divides by the bin count."), fontsize=7.0)
    axA2.set_title(
        lab("A2  The objective by gene bin, 508 ok designs. Colour is the median; cells print the count."),
        fontsize=8.0, loc="left", pad=6,
    )
    for sp in ("top", "right", "bottom"):
        axA2.spines[sp].set_visible(False)
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=plt.Normalize(vmin, vmax))
    cb = figA.colorbar(sm, ax=axA2, fraction=0.030, pad=0.015)
    cb.set_label(lab("median fitness, kg-equivalent"), fontsize=6.6)
    cb.ax.tick_params(labelsize=6.0)

    figA.text(0.345, 0.955, lab("Plate A  The main effect and the surface it flattens"),
              fontsize=8.6, ha="left", weight="bold")
    figA.text(0.345, 0.930, lab("508 ok designs of 930, campaign v13_5kw_masslift_len18.8_rotorcount_bankderate2"),
              fontsize=6.8, ha="left")
    figA.text(0.345, 0.030, lab(f"source lever-statistics-extract · data {DATA_COMMIT} · run {RUN} · script {commit}"),
              fontsize=6.2, ha="left", color="#444444")
    figA.text(0.345, 0.012, lab("A positive shift is heavier and worse. The shift is a fitness difference, in kg-equivalent."),
              fontsize=6.2, ha="left", color="#444444")
    for ext in ("pdf", "png", "svg"):
        pass
    figA.savefig(OUTDIR / f"{SLUG}-A.svg", metadata={"Date": None, "Creator": f"{SLUG} · KTD figures"})
    figA.savefig(OUTDIR / f"{SLUG}-A.pdf",
                 metadata={"Creator": f"{SLUG} · KTD figures", "CreationDate": None})
    figA.savefig(OUTDIR / f"{SLUG}-A.png", dpi=300)
    plt.close(figA)

    # ---- plate B ----------------------------------------------------------
    figB = plt.figure(figsize=(7.6, 7.4))
    gsB = figB.add_gridspec(
        2, 1, height_ratios=[1.25, 1.0], hspace=0.45,
        left=0.235, right=0.94, top=0.885, bottom=0.095,
    )

    axB1 = figB.add_subplot(gsB[0])
    tags, okv, rejv, clrv, twsv = [], [], [], [], []
    for r in rates:
        if r["column"] == "n_active":
            continue
        tags.append(lab(f"{r['column']} {r['value']}"))
        okv.append(int(r["ok"]))
        rejv.append(int(r["reject"]))
        clrv.append(int(r["clearance_reject"]))
        twsv.append(int(r["reject_twist"]))
    y = np.arange(len(tags))
    left = np.zeros(len(tags))
    for vals, colour, name in (
        (okv, OK, "ok"),
        (rejv, REJ, "reject"),
        (clrv, CLR, "clearance reject"),
        (twsv, TWS, "twist reject"),
    ):
        axB1.barh(y, vals, left=left, height=0.66, color=colour, label=lab(name), zorder=3)
        left = left + np.array(vals)
    for i, tot in enumerate(left):
        share = 100.0 * okv[i] / tot
        if okv[i] > 90:
            axB1.text(8, i, lab(f"{share:.1f}% ok"), va="center", fontsize=6.5,
                      color="white", zorder=5)
        else:
            axB1.text(tot + 10, i, lab(f"{share:.1f}% ok"), va="center", fontsize=6.5)
    axB1.set_yticks(y)
    axB1.set_yticklabels(tags, fontsize=6.5)
    axB1.invert_yaxis()
    axB1.set_xlim(0, 860)
    axB1.set_xlabel(lab("designs"), fontsize=7.2)
    axB1.set_title(
        lab("B1  What fails, by line count and rotor count. All 930 designs; ok share printed at each bar."),
        fontsize=8.0, loc="left", pad=6,
    )
    axB1.legend(loc="lower right", fontsize=6.2, frameon=False, ncol=2, handlelength=1.2)
    axB1.grid(axis="x", color="#e6e6e6", lw=0.5, zorder=0)
    axB1.set_axisbelow(True)
    for s in ("top", "right"):
        axB1.spines[s].set_visible(False)

    axB2 = figB.add_subplot(gsB[1])
    chans = [r for r in pen if r["channel"] != "total"]
    total = [r for r in pen if r["channel"] == "total"][0]
    names, sums, shares, dom = [], [], [], []
    display = {"overpower": "over-power", "utilisation": "utilisation", "twist": "twist"}
    for r in chans:
        names.append(lab(display[r["channel"]]))
        sums.append(float(r["sum"]))
        shares.append(float(r["share_pct"]))
        dom.append(int(r["n_dominant"]))
    x = np.arange(len(names))
    cols = [REJ, CLR, TWS]
    axB2.bar(x, sums, width=0.58, color=cols, zorder=3)
    for i, (sv, sh, d) in enumerate(zip(sums, shares, dom)):
        if sv > 500:
            axB2.text(i, sv * 0.62, lab(f"{sv:.2f} kg-eq"), ha="center", fontsize=7.0,
                      color="white", weight="bold")
            axB2.text(i, sv * 0.44, lab(f"{sh:.2f}% of the total"), ha="center", fontsize=6.4,
                      color="white")
            axB2.text(i, sv * 0.30, lab(f"largest charge in {d}"), ha="center", fontsize=6.4,
                      color="white")
        else:
            axB2.text(i, sv + 62, lab(f"{sv:.2f} kg-eq"), ha="center", fontsize=6.8, weight="bold")
            axB2.text(i, sv + 148, lab(f"{sh:.2f}% of the total"), ha="center", fontsize=6.2,
                      color="#333333")
            axB2.text(i, sv + 232, lab(f"largest charge in {d}"), ha="center", fontsize=6.2,
                      color="#333333")
    axB2.axhline(float(total["sum"]), color=INK, lw=0.9, ls=(0, (4, 2)))
    axB2.text(-0.42, float(total["sum"]) + 96,
              lab(f"total {float(total['sum']):.2f} kg-eq"), ha="left", fontsize=6.6, va="bottom")
    axB2.set_xticks(x)
    axB2.set_xticklabels(names, fontsize=7.0)
    axB2.set_ylim(0, 2420)
    axB2.set_ylabel(lab("charge sum, kg-equivalent"), fontsize=7.2)
    axB2.set_title(
        lab("B2  Where the penalty mass sits. 508 ok designs; the maximum is not the ranking."),
        fontsize=8.0, loc="left", pad=6,
    )
    axB2.grid(axis="y", color="#e6e6e6", lw=0.5, zorder=0)
    axB2.set_axisbelow(True)
    for s in ("top", "right"):
        axB2.spines[s].set_visible(False)

    figB.text(0.235, 0.945, lab("Plate B  The failure population and the penalty mass"),
              fontsize=8.6, ha="left", weight="bold")
    figB.text(0.235, 0.918, lab("B1 counts all 930 designs. B2 reads the 508 that passed."),
              fontsize=6.8, ha="left")
    figB.text(0.235, 0.030, lab(f"source lever-statistics-extract · data {DATA_COMMIT} · run {RUN} · script {commit}"),
              fontsize=6.2, ha="left", color="#444444")
    figB.text(0.235, 0.012, lab("Utilisation holds the larger single charge, 12.36 kg-equivalent against 8.84."),
              fontsize=6.2, ha="left", color="#444444")
    figB.savefig(OUTDIR / f"{SLUG}-B.svg", metadata={"Date": None, "Creator": f"{SLUG} · KTD figures"})
    figB.savefig(OUTDIR / f"{SLUG}-B.pdf",
                 metadata={"Creator": f"{SLUG} · KTD figures", "CreationDate": None})
    figB.savefig(OUTDIR / f"{SLUG}-B.png", dpi=300)
    plt.close(figB)

    # ---- in-script value checks ------------------------------------------
    ov = [r for r in pen if r["channel"] == "overpower"][0]
    ut = [r for r in pen if r["channel"] == "utilisation"][0]
    tw = [r for r in pen if r["channel"] == "twist"][0]
    def at4(x, y):
        return round(float(x), 4) == y

    checks.append((at4(ov["sum"], 1462.3155), "over-power sum 1462.3155"))
    checks.append((at4(ut["sum"], 506.3577), "utilisation sum 506.3577"))
    checks.append((at4(tw["sum"], 141.1349), "twist sum 141.1349"))
    checks.append((at4(total["sum"], 2109.8081), "total sum 2109.8081"))
    checks.append((int(ov["n_dominant"]) == 453, "over-power dominant in 453"))
    checks.append((int(ut["n_dominant"]) == 46, "utilisation dominant in 46"))
    checks.append((int(tw["n_dominant"]) == 9, "twist dominant in 9"))
    checks.append((at4(ut["max"], 12.3611) and at4(ov["max"], 8.8445)
                   and float(ut["max"]) > float(ov["max"]),
                   "utilisation maximum exceeds over-power maximum"))
    nl6 = [r for r in rates if r["column"] == "n_lines" and r["value"] == "6"][0]
    checks.append((close(float(nl6["ok_share_pct"]), 4.8, 1e-9), "n_lines 6 ok share 4.8 per cent"))
    clr_total = sum(int(r["clearance_reject"]) for r in rates if r["column"] == "rotor_count")
    checks.append((clr_total == 110, f"clearance rejects sum to 110: {clr_total}"))
    clr_one = [r for r in rates if r["column"] == "rotor_count" and r["value"] == "1"][0]
    checks.append((int(clr_one["clearance_reject"]) == 0, "no clearance reject at one rotor"))
    ok_rows = sum(int(r["ok"]) for r in rates if r["column"] == "n_lines")
    checks.append((ok_rows == 508, f"ok rows sum to 508: {ok_rows}"))
    all_rows = sum(int(r["n_total"]) for r in rates if r["column"] == "n_lines")
    checks.append((all_rows == 930, f"all rows sum to 930: {all_rows}"))

    # ---- ledger -----------------------------------------------------------
    ledger = OUTDIR / "label-ledger.txt"
    ledger.write_text("\n".join(sorted(LABELS)) + "\n", encoding="utf-8")
    checks.append((True, f"label ledger holds {len(LABELS)} strings"))

    # ---- checks log -------------------------------------------------------
    passed = sum(1 for ok, _ in checks if ok)
    lines = [f"{'ok ' if ok else 'FAIL'}  {msg}" for ok, msg in checks]
    lines.append(f"{passed} ok / {len(checks) - passed} fail")
    (OUTDIR / "checks.log").write_text("\n".join(lines) + "\n", encoding="utf-8")

    # ---- manifest ---------------------------------------------------------
    manifest = {
        "slug": SLUG,
        "command": f"/usr/bin/python3 docs/reporting/figures/{SLUG}/{SLUG}.py --script-commit {commit}",
        "script_commit": commit,
        "data_commit": DATA_COMMIT,
        "run": RUN,
        "inputs": {
            "extracts": [
                {"path": str((EXTRACT / n).relative_to(ROOT)), "sha256": sha256(EXTRACT / n)}
                for n in (
                    "extract-objective-vs-gene.csv",
                    "extract-objective-by-gene-bins.csv",
                    "extract-failure-rates-by-value.csv",
                    "extract-penalty-summary.csv",
                    "extract-penalty-contributions.csv",
                )
            ],
            "register_rows": ["NR-074", "NR-075", "NR-076", "NR-077"],
        },
        "outputs": {
            f"{SLUG}-A.pdf": sha256(OUTDIR / f"{SLUG}-A.pdf"),
            f"{SLUG}-A.png": sha256(OUTDIR / f"{SLUG}-A.png"),
            f"{SLUG}-A.svg": sha256(OUTDIR / f"{SLUG}-A.svg"),
            f"{SLUG}-B.pdf": sha256(OUTDIR / f"{SLUG}-B.pdf"),
            f"{SLUG}-B.png": sha256(OUTDIR / f"{SLUG}-B.png"),
            f"{SLUG}-B.svg": sha256(OUTDIR / f"{SLUG}-B.svg"),
            "label-ledger.txt": sha256(ledger),
        },
        "script": {"path": f"docs/reporting/figures/{SLUG}/{SLUG}.py", "sha256": sha256(Path(__file__).resolve())},
        "precision": "rho 2 dp; shift 2 dp; charge sums 2 dp; ok share 1 dp; populations as integers",
        "toolchain": {"python": sys.version.split()[0], "matplotlib": matplotlib.__version__, "numpy": np.__version__},
    }
    (OUTDIR / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print("\n".join(lines))
    return 0 if passed == len(checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
