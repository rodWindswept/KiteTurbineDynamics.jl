#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""k-basis: generating script for the row-5 plate (the k basis).

Plate: docs/reporting/figures/k-basis/SPEC.md (GENERATE stage, R2).
Draws the load sweep behind the campaign load, from the committed sweep
record (scripts/results/k_sweep_daisy_5kw.csv, blob d17d1377, run
adea1a3, 2026-08-22).  Values ride NR-041 (signed 2026-10-12).

What the plate shows, per the section 2.3 prose: the light end reads
under the power floor (reject); the heavy end levels off; the pick sits
between (k = 2.24, NR-015).  No clamp line draws (era-bound).  The
omega_eq column reads zero and draws nothing.  No anchor formula prints.

Run:
  /usr/bin/python3 docs/reporting/figures/k-basis/k-basis.py \
      --script-commit <hex>

Toolchain pin: /usr/bin/python3 (CPython 3.12.3), matplotlib 3.10.8,
numpy 2.4.4.  F-REPRO: svg.hashsalt set, SVG dc:date normalised, PDF
and PNG metadata fixed, no timestamps anywhere.

Outputs (in this directory): k-basis.svg / .pdf / .png, label-ledger.txt,
manifest.json.
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

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
CSV = REPO / "scripts" / "results" / "k_sweep_daisy_5kw.csv"
SLUG = "k-basis"

# ---------------------------------------------------------------- constants
DATA_COMMIT = "adea1a3"  # the run that landed the sweep record
BLOB = "d17d1377"
ROWS = "NR-015 \u00b7 NR-041 \u00b7 floor rows NR-027 \u00b7 NR-039"

INK = "#1a1a1a"
LINE = "#333333"
GREY = "#555555"
FAINT = "#777777"
MUTED = "#98a0a8"
RED = "#b32222"
STEEL = "#3d6b8e"
REF = "#8a8a8a"

TITLE = "The k = 2.24 pick: the light end reads under the floor, the heavy end levels off"
SUB = ("The load sweep (2026-08-22) \u00b7 the seed machine at a range of loads, "
       "each over the same measurement window")

LEDGER: list[str] = []


def keep(s: str) -> str:
    LEDGER.append(s)
    return s


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load() -> list[dict]:
    with CSV.open(newline="", encoding="utf-8") as fh:
        lines = [ln for ln in fh if not ln.startswith("#")]
    return list(csv.DictReader(lines))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script-commit", default="uncommitted")
    ap.add_argument("--outdir", default=str(HERE))
    args = ap.parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    rows = load()
    ks = [float(r["k"]) for r in rows]
    ps = [float(r["P_mean"]) for r in rows]
    st = [r["status"].strip() for r in rows]

    # ---------------------------------------------------------------- checks
    checks = []
    checks.append(("rows", len(rows), 10))
    checks.append(("k settings (2 dp)", [round(x, 2) for x in ks],
                   [0.5, 1.0, 1.5, 1.94, 2.24, 3.0, 4.0, 5.39, 7.0, 9.0]))
    checks.append(("status column", st, ["reject"] + ["ok"] * 9))
    checks.append(("P_mean (2 dp)", [round(p, 2) for p in ps],
                   [3.49, 5.45, 6.78, 7.56, 8.00, 8.89, 8.95, 8.95, 8.95, 8.95]))
    checks.append(("k=0.5 P_mean full", ps[0], 3.485236347784519))
    checks.append(("omega_eq sum (draws nothing)", sum(float(r["omega_eq"]) for r in rows), 0.0))
    plateau = [p for k, p in zip(ks, ps) if k >= 4.0]
    checks.append(("plateau band (4 dp)", (round(min(plateau), 4), round(max(plateau), 4)),
                   (8.9475, 8.9511)))
    for name, got, want in checks:
        ok = (abs(got - want) / max(abs(want), 1e-12) < 5e-3
              if isinstance(got, float) else got == want)
        print(f"check: {name}: {got}  ({'OK' if ok else 'OFF vs ' + str(want)})")

    plt.rcParams.update({
        "font.size": 8,
        "svg.hashsalt": "ktd-fig-pin-2026-10-08",
        "svg.fonttype": "none",
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "figure.facecolor": "white",
        "savefig.facecolor": "white",
    })

    fig = plt.figure(figsize=(7.6, 4.35))
    fig.text(0.012, 0.952, keep(TITLE), size=10.5, weight="bold", color=INK)
    fig.text(0.012, 0.897, keep(SUB), size=7.5, color=GREY)

    ax = fig.add_axes([0.085, 0.225, 0.875, 0.615])
    ax.set_xlim(0, 9.8)
    ax.set_ylim(3.0, 9.8)
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    for sp in ("left", "bottom"):
        ax.spines[sp].set_color(MUTED)
        ax.spines[sp].set_linewidth(0.8)
    ax.tick_params(labelsize=7, colors=GREY, length=2.5)

    ax.set_xticks(range(10))
    ax.set_xticklabels([keep(str(v)) for v in range(10)])
    ax.set_yticks([4, 5, 6, 7, 8, 9])
    ax.set_yticklabels([keep(str(v)) for v in (4, 5, 6, 7, 8, 9)])
    ax.set_ylabel(keep("window mean power (kW)"), size=7.5, color=GREY)
    ax.set_xlabel(keep("load constant k (N\u00b7m/(rad/s)\u00b2)"), size=7.5, color=GREY)

    # the recorded sweep: segments through the ten readings
    ax.plot(ks, ps, color=LINE, lw=1.2, zorder=3)
    ax.plot(ks, ps, ls="none", marker="o", ms=3.6, mfc="white", mec=INK,
            mew=1.0, zorder=4)

    # the floor line, the reject reading, the pick
    ax.axhline(5.0, color=RED, lw=1.0, ls=(0, (4, 3)), zorder=2)
    ax.plot([0.5], [ps[0]], ls="none", marker="o", ms=6.2, mfc="white",
            mec=RED, mew=1.4, zorder=5)
    ax.plot([2.24], [ps[4]], ls="none", marker="*", ms=13, mfc=STEEL,
            mec="white", mew=0.5, zorder=6)
    ax.plot([2.24, 2.24], [3.0, ps[4]], color=REF, lw=0.9, ls=(0, (3, 3)),
            zorder=2)

    ax.text(9.6, 5.14, keep("power floor (5.0 kW)"), ha="right", va="bottom",
            size=7, color=RED)
    ax.text(0.65, 3.62, keep("3.49 kW \u2014 reject (under the floor)"),
            ha="left", va="bottom", size=7, color=RED)
    ax.text(2.50, 7.72, keep("k = 2.24 \u2014 the campaign load (NR-015)"),
            ha="left", va="top", size=7, color=STEEL)

    # the heavy-end bracket over the plateau rows
    ax.plot([4.0, 9.0], [9.35, 9.35], color=FAINT, lw=0.8)
    ax.plot([4.0, 4.0], [9.35, 9.23], color=FAINT, lw=0.8)
    ax.plot([9.0, 9.0], [9.35, 9.23], color=FAINT, lw=0.8)
    ax.text(6.5, 9.42, keep("the power levels off (k \u2265 4)"),
            ha="center", va="bottom", size=7, color=GREY)

    fig.text(0.012, 0.108, keep("One load applies to the whole search (NR-015)."),
             size=6.8, color=FAINT, style="italic")
    stamp1 = (f"source: scripts/results/k_sweep_daisy_5kw.csv \u00b7 "
              f"blob {BLOB} \u00b7 run landed {DATA_COMMIT} (2026-08-22)")
    stamp2 = f"rows {ROWS} \u00b7 script commit {args.script_commit}"
    fig.text(0.012, 0.052, keep(stamp1), size=6.5, color=FAINT)
    fig.text(0.012, 0.018, keep(stamp2), size=6.5, color=FAINT)

    # ---------------------------------------------------------------- save
    svg = outdir / f"{SLUG}.svg"
    pdf = outdir / f"{SLUG}.pdf"
    png = outdir / f"{SLUG}.png"
    fig.savefig(svg)
    fig.savefig(pdf, metadata={"Creator": f"{SLUG} \u00b7 KTD figures", "CreationDate": None})
    fig.savefig(png, dpi=300)
    plt.close(fig)

    raw = svg.read_bytes()
    raw = re.sub(rb"<dc:date>[^<]*</dc:date>", rb"<dc:date>1970-01-01T00:00:00</dc:date>", raw)
    svg.write_bytes(raw)

    ledger = sorted(set(LEDGER))
    (outdir / "label-ledger.txt").write_text("\n".join(ledger) + "\n", encoding="utf-8")

    found = {
        html.unescape(re.sub(r"<[^>]+>", "", m)).strip()
        for m in re.findall(r"<text[^>]*>(.*?)</text>", svg.read_text(), flags=re.S)
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
                      "numpy": __import__("numpy").__version__},
        "inputs": {
            "extract": {"path": "scripts/results/k_sweep_daisy_5kw.csv",
                        "sha256": sha256(CSV)},
            "register_rows": ["NR-015", "NR-041", "NR-027", "NR-039"],
        },
        "data_commit": DATA_COMMIT,
        "script_commit": args.script_commit,
        "command": (f"/usr/bin/python3 docs/reporting/figures/{SLUG}/{SLUG}.py "
                    f"--script-commit {args.script_commit}"),
        "precision": "P_mean at 2 dp; k settings as listed; floor 5.0 kW",
        "outputs": {f"{SLUG}.svg": sha256(svg), f"{SLUG}.pdf": sha256(pdf),
                    f"{SLUG}.png": sha256(png),
                    "label-ledger.txt": sha256(outdir / "label-ledger.txt")},
    }
    (outdir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                                          encoding="utf-8")
    print(f"written: {SLUG}.svg / .pdf / .png, label-ledger.txt "
          f"({len(ledger)} strings), manifest.json")
    print("F-LABEL self-check: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
