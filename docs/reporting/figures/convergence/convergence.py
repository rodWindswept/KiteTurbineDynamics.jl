#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""convergence: generating script for the row-16 plate (campaign progress, two panels).

Plate: docs/reporting/figures/convergence/SPEC.md (GENERATE stage, R2).
Draws the merged two-panel figure "first feasibility, then mass" from the
campaign records:

  panel 1  the pooled outcome mix of each generation (three islands, ten
           designs each): feasible, the two named gate classes, and the
           NR-055 reject split (power floor, FoS, cause not logged)
  panel 2  the three island running-best curves, generations 0 to 30,
           from the aero series extract (scratch/av_conv_series.csv)

The reject labels take the 301 print ruling (room, 2026-10-15) and the
NR-055 reading rules.  Drawn values: the class counts (NR-002, NR-055),
the seed 36.109 (NR-006) and the winner 27.364 (NR-005).  The objective
keeps the drawn (kg) form; captions read kg-equivalent.

Run:
  /usr/bin/python3 docs/reporting/figures/convergence/convergence.py \
      --script-commit <hex>

Toolchain pin: /usr/bin/python3 (CPython 3.12.3), matplotlib 3.10.8,
numpy 2.4.4.  F-REPRO: svg.hashsalt set, SVG dc:date normalised, PDF
CreationDate pinned, no timestamps anywhere.

Outputs (in this directory): convergence.svg / .pdf / .png,
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
from matplotlib.patches import Patch

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
RUN_DIR = (REPO / "scripts" / "results"
           / "v13_5kw_masslift_len18.8_rotorcount_bankderate2")
SERIES = REPO / "scratch" / "av_conv_series.csv"
SLUG = "convergence"

DATA_COMMIT = "dd3cc6a"
RUN_COMMIT = "a76c5e9"
ROWS = ("NR-002 \u00b7 NR-003 \u00b7 NR-004 \u00b7 NR-005 \u00b7 NR-006 "
        "\u00b7 NR-036 \u00b7 NR-054 \u00b7 NR-055")

INK = "#1a1a1a"
GREY = "#555555"
FAINT = "#777777"
MUTED = "#98a0a8"
GREEN = "#3a7d44"    # feasible
RED = "#b32222"      # clearance
ORANGE = "#c65f1c"   # twist
AMBER = "#dfa72f"    # power floor
VIOLET = "#7a5ba6"   # FoS
UGREY = "#9aa0a6"    # cause not logged
ISL = {1: "#4a7fb5", 2: "#2e8b57", 3: "#c1441e"}

TITLE = "First feasibility, then mass"
SUB = ("the campaign across generations 0 to 30 \u00b7 era "
       "post-95c385d_wind-authority")
HEADER_A = "the outcome mix of each generation \u00b7 pooled over the three islands"
HEADER_B = "the running-best search objective of each island"

CLASSES = [
    ("feasible", "feasible", GREEN),
    ("clearance", "rejected: rotor below 1.5 m clearance", RED),
    ("twist", "rejected: twist past the crossing limit", ORANGE),
    ("floor", "rejected: power below the 5 kW floor", AMBER),
    ("fos", "rejected: FoS below 2.5", VIOLET),
    ("unlogged", "rejected: cause not logged", UGREY),
]

LEDGER: list[str] = []


def keep(s: str) -> str:
    LEDGER.append(s)
    return s


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as fh:
        lines = [ln for ln in fh if not ln.startswith("#")]
    return list(csv.DictReader(lines))


def classify(r: dict) -> str:
    s = r["status"]
    if s == "ok":
        return "feasible"
    if s == "clearance_reject":
        return "clearance"
    if s == "reject_twist":
        return "twist"
    if s == "reject":
        p = float(r["P_mean"])
        fos = float(r["FoS"])
        if p == 0.0 and fos == float("inf"):
            return "unlogged"
        if 0.0 < p < 5.0:
            return "floor"
        if p >= 5.0 and fos < 2.5:
            return "fos"
    raise ValueError(f"unclassified row: {r}")


def best_so_far(rows: list[dict]) -> dict[int, tuple[float, int, int]]:
    ok = [(int(r["gen"]), int(r["idx"]), float(r["fitness"]))
          for r in rows if r["status"] == "ok"]
    out = {}
    for g in range(31):
        cand = [(f, gg, i) for (gg, i, f) in ok if gg <= g]
        out[g] = min(cand)   # ties take the earliest (gen, idx)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script-commit", default="uncommitted")
    ap.add_argument("--outdir", default=str(HERE))
    args = ap.parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    # ---------------------------------------------------------------- inputs
    tele = {}
    for isl in (1, 2, 3):
        tele[isl] = load(RUN_DIR / f"island_{isl}" / "telemetry.csv")
    extract = load(SERIES)

    # header hashes claimed by the extract file
    head = "".join(l for l in SERIES.open() if l.startswith("# sha256"))
    header_hexes = re.findall(r"[0-9a-f]{64}", head)

    # --------------------------------------------------------- class table
    per_gen = {g: {} for g in range(31)}
    pooled = {}
    per_isl = {}
    bunk = []
    for isl in (1, 2, 3):
        cnt = {}
        for r in tele[isl]:
            g = int(r["gen"])
            k = classify(r)
            cnt[k] = cnt.get(k, 0) + 1
            per_gen[g][k] = per_gen[g].get(k, 0) + 1
            pooled[k] = pooled.get(k, 0) + 1
            if k == "fos":
                bunk.append((isl, int(r["gen"]), int(r["idx"]),
                             float(r["P_mean"]), float(r["FoS"])))
        per_isl[isl] = cnt

    # --------------------------------------------------------- series table
    ser = {1: {}, 2: {}, 3: {}}
    for r in extract:
        ser[int(r["island"])][int(r["gen"])] = (
            float(r["best_fitness"]), int(r["best_source_gen"]),
            int(r["best_source_idx"]))

    # ------------------------------------------------------------ checks
    def close(got, want):
        if isinstance(got, float) or isinstance(want, float):
            return abs(float(got) - float(want)) <= 6e-4
        return got == want

    checks = []

    def chk(name, got, want):
        ok = (len(got) == len(want)
              and all(close(a, b) for a, b in zip(got, want))) \
            if isinstance(got, list) else close(got, want)
        checks.append((name, got, want, ok))

    chk("telemetry rows per island",
        [len(tele[i]) for i in (1, 2, 3)], [310, 310, 310])
    chk("status mix ok/reject/clearance/twist (NR-002)",
        [pooled.get("feasible", 0), pooled.get("floor", 0)
         + pooled.get("fos", 0) + pooled.get("unlogged", 0),
         pooled.get("clearance", 0), pooled.get("twist", 0)],
        [508, 301, 110, 11])
    chk("reject split floor/fos/unlogged (NR-055)",
        [pooled.get("floor", 0), len(bunk), pooled.get("unlogged", 0)],
        [96, 4, 201])
    chk("per-island ok (NR-002)",
        [per_isl[i].get("feasible", 0) for i in (1, 2, 3)],
        [152, 162, 194])
    chk("per-island reject",
        [per_isl[i].get("floor", 0) + per_isl[i].get("fos", 0)
         + per_isl[i].get("unlogged", 0) for i in (1, 2, 3)],
        [108, 111, 82])
    chk("per-island clearance",
        [per_isl[i].get("clearance", 0) for i in (1, 2, 3)], [47, 35, 28])
    chk("per-island twist",
        [per_isl[i].get("twist", 0) for i in (1, 2, 3)], [3, 2, 6])
    chk("subgroup-B rows (island, gen, idx)",
        sorted((i, g, x) for (i, g, x, _, _) in bunk),
        [(1, 6, 7), (3, 5, 8), (3, 14, 8), (3, 22, 2)])
    chk("subgroup-B reads (P, FoS)",
        [round(v, 2) for (_, _, _, p, f) in
         sorted(bunk) for v in (p, f)],
        [5.47, 2.27, 5.15, 1.61, 5.72, 1.25, 5.68, 0.42])
    chk("per-generation totals (31 gens, 30 each)",
        [len(per_gen), all(sum(per_gen[g].values()) == 30 for g in per_gen)],
        [31, True])
    chk("pooled design total", sum(pooled.values()), 930)
    chk("feasible by band (0 / 1-10 / 11-20 / 21-30)",
        [sum(per_gen[g].get("feasible", 0) for g in [0]),
         sum(per_gen[g].get("feasible", 0) for g in range(1, 11)),
         sum(per_gen[g].get("feasible", 0) for g in range(11, 21)),
         sum(per_gen[g].get("feasible", 0) for g in range(21, 31))],
        [3, 26, 196, 283])
    chk("series rows", len(extract), 93)
    chk("series gens per island",
        [len(ser[i]) for i in (1, 2, 3)], [31, 31, 31])
    chk("seed start (NR-006)",
        [ser[i][0][0] for i in (1, 2, 3)], [36.109, 36.109, 36.109])
    chk("finals (NR-003 to NR-005 forms)",
        [ser[1][30][0], ser[2][30][0], ser[3][26][0]],
        [30.578, 30.637, 27.364])
    chk("island 3 holds after gen 26",
        set(ser[3][g][0] for g in range(26, 31)) == {27.364}, True)
    chk("NR-036 milestones (7 of 7)",
        [ser[3][g][0] for g in (0, 6, 10, 18, 22, 25, 26)],
        [36.109, 32.293, 31.661, 30.929, 29.854, 28.315, 27.364])
    chk("island 1 last step", [ser[1][29][0], ser[1][30][0]],
        [31.018, 30.578])
    chk("island 2 last step", [ser[2][29][0], ser[2][30][0]],
        [31.085, 30.637])
    mism = 0
    for isl in (1, 2, 3):
        rec = best_so_far(tele[isl])
        for g in range(31):
            val, sg, si = ser[isl][g]
            rv, rg, ri = rec[g]
            if not (abs(val - rv) <= 6e-4 and sg == rg and si == ri):
                mism += 1
    chk("parity: recomputed running-best == extract (93 rows)", mism, 0)
    chk("telemetry sha256 == extract header",
        [sha256(RUN_DIR / f"island_{isl}" / "telemetry.csv")
         == header_hexes[isl - 1] for isl in (1, 2, 3)],
        [True, True, True])

    n_fail = 0
    for name, got, want, ok in checks:
        if not ok:
            n_fail += 1
        print(f"check: {name}: {got}  ({'OK' if ok else 'OFF vs ' + str(want)})")
    if n_fail:
        print(f"in-script checks FAILED: {n_fail}", file=sys.stderr)
        return 1

    # ---------------------------------------------------------------- figure
    plt.rcParams.update({
        "font.size": 8,
        "svg.hashsalt": "ktd-fig-pin-2026-10-15",
        "svg.fonttype": "none",
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "figure.facecolor": "white",
        "savefig.facecolor": "white",
    })

    fig = plt.figure(figsize=(7.6, 7.9))
    fig.text(0.012, 0.973, keep(TITLE), size=11, weight="bold", color=INK)
    fig.text(0.012, 0.9485, keep(SUB), size=7.5, color=GREY)

    # ------------------------------------------------------------- panel 1
    fig.text(0.105, 0.842, keep(HEADER_A), size=8, color=GREY)
    axA = fig.add_axes([0.105, 0.520, 0.87, 0.315])
    cum = [0.0] * 31
    handles = []
    for key, label, color in CLASSES:
        h = [per_gen[g].get(key, 0) for g in range(31)]
        axA.bar(range(31), h, bottom=cum, width=0.82, color=color,
                edgecolor="white", linewidth=0.4)
        cum = [a + b for a, b in zip(cum, h)]
        handles.append(Patch(facecolor=color, edgecolor="white"))
    axA.set_xlim(-0.55, 30.55)
    axA.set_ylim(0, 31)
    axA.set_yticks([0, 10, 20, 30])
    axA.set_yticklabels([keep("0"), keep("10"), keep("20"), keep("30")])
    axA.set_ylabel(keep("designs"), size=7.5, color=GREY)
    axA.set_xticks([0, 5, 10, 15, 20, 25, 30])
    axA.set_xticklabels([])
    for sp in ("top", "right"):
        axA.spines[sp].set_visible(False)
    for sp in ("left", "bottom"):
        axA.spines[sp].set_color(MUTED)
        axA.spines[sp].set_linewidth(0.8)
    axA.tick_params(labelsize=7, colors=GREY, length=2.5)

    labels = [f"{label} ({pooled.get(key, 0)})"
              for key, label, _ in CLASSES]
    fig.legend(handles=handles, labels=[keep(s) for s in labels],
               ncol=2, loc="upper left", bbox_to_anchor=(0.095, 0.471),
               frameon=False, fontsize=7, handlelength=1.1,
               handletextpad=0.5, labelspacing=0.38, columnspacing=1.8)
    fig.text(0.105, 0.400, keep("the reject split reads the power floor first"),
             size=6.8, color=FAINT, style="italic")

    # ------------------------------------------------------------- panel 2
    fig.text(0.105, 0.378, keep(HEADER_B), size=8, color=GREY)
    axB = fig.add_axes([0.105, 0.140, 0.87, 0.230])
    gens = list(range(31))
    s1 = [ser[1][g][0] for g in gens]
    s2 = [ser[2][g][0] for g in gens]
    s3 = [ser[3][g][0] for g in gens]
    axB.plot(gens, s3, color=ISL[3], lw=2.4, zorder=4)
    axB.plot(gens, s1, color=ISL[1], lw=1.6, zorder=5)
    axB.plot(gens, s2, color=ISL[2], lw=1.6, ls=(0, (4, 2)), zorder=5)
    axB.plot([26], [27.364], marker="*", ms=11, color=ISL[3],
             mec="white", mew=0.7, zorder=6)
    axB.set_xlim(-0.7, 30.7)
    axB.set_ylim(26, 37)
    axB.set_xticks([0, 5, 10, 15, 20, 25, 30])
    axB.set_xticklabels([keep(str(v)) for v in (0, 5, 10, 15, 20, 25, 30)])
    axB.set_yticks([26, 28, 30, 32, 34, 36])
    axB.set_yticklabels([keep(str(v)) for v in (26, 28, 30, 32, 34, 36)])
    axB.set_xlabel(keep("generation"), size=7.5, color=GREY)
    axB.set_ylabel(keep("search objective (kg)"), size=7.5, color=GREY)
    for sp in ("top", "right"):
        axB.spines[sp].set_visible(False)
    for sp in ("left", "bottom"):
        axB.spines[sp].set_color(MUTED)
        axB.spines[sp].set_linewidth(0.8)
    axB.tick_params(labelsize=7, colors=GREY, length=2.5)

    axB.text(0.2, 36.42, keep("the common seed \u00b7 36.109"),
             ha="left", va="bottom", size=7, color=GREY)
    axB.text(9.0, 34.4, keep("island 1"), ha="left", va="center",
             size=7, color=ISL[1])
    axB.text(3.9, 33.6, keep("island 2"), ha="left", va="center",
             size=7, color=ISL[2])
    axB.text(14.0, 32.25, keep("island 3"), ha="left", va="center",
             size=7, color=ISL[3])
    wbox = dict(boxstyle="round,pad=0.18", fc="white", ec="none", alpha=1.0)
    axB.text(25.4, 26.95, keep("the campaign winner \u00b7 27.364"),
             ha="right", va="center", size=7, color=ISL[3], bbox=wbox)

    fig.text(0.105, 0.078,
             keep("islands 1 and 2 improve to their last generation "
                  "\u00b7 the budget stops the search"),
             size=6.8, color=FAINT, style="italic")
    stamp1 = ("sources: the campaign telemetry, islands 1 to 3 "
              "\u00b7 the convergence series extract "
              f"\u00b7 data commit {DATA_COMMIT} \u00b7 run {RUN_COMMIT}")
    stamp2 = f"rows {ROWS} \u00b7 script commit {args.script_commit}"
    fig.text(0.012, 0.050, keep(stamp1), size=6.5, color=FAINT)
    fig.text(0.012, 0.030, keep(stamp2), size=6.5, color=FAINT)

    # ---------------------------------------------------------------- save
    svg = outdir / f"{SLUG}.svg"
    pdf = outdir / f"{SLUG}.pdf"
    png = outdir / f"{SLUG}.png"
    fig.savefig(svg)
    fig.savefig(pdf, metadata={"Creator": f"{SLUG} \u00b7 KTD figures",
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
                      "numpy": __import__("numpy").__version__},
        "inputs": {
            "extracts": [
                {"path": "scratch/av_conv_series.csv",
                 "sha256": sha256(SERIES)},
                {"path": ("scripts/results/v13_5kw_masslift_len18.8_"
                          "rotorcount_bankderate2/island_1/telemetry.csv"),
                 "sha256": sha256(RUN_DIR / "island_1" / "telemetry.csv")},
                {"path": ("scripts/results/v13_5kw_masslift_len18.8_"
                          "rotorcount_bankderate2/island_2/telemetry.csv"),
                 "sha256": sha256(RUN_DIR / "island_2" / "telemetry.csv")},
                {"path": ("scripts/results/v13_5kw_masslift_len18.8_"
                          "rotorcount_bankderate2/island_3/telemetry.csv"),
                 "sha256": sha256(RUN_DIR / "island_3" / "telemetry.csv")},
            ],
            "register_rows": ["NR-002", "NR-003", "NR-004", "NR-005",
                              "NR-006", "NR-036", "NR-054", "NR-055"],
        },
        "data_commit": DATA_COMMIT,
        "script_commit": args.script_commit,
        "command": (f"/usr/bin/python3 docs/reporting/figures/{SLUG}/"
                    f"{SLUG}.py --script-commit {args.script_commit}"),
        "precision": ("counts are integers; the objective prints 3 dp; "
                      "seed and winner as signed (36.109, 27.364)"),
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
