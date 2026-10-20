#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""machine-power-trend: the generation-axis companion to the evolution strip.

Plate: docs/reporting/figures/machine-power-trend/SPEC.md (GENERATE candidate).
The strip prints window-end power under each machine. This plate carries the
shape those seven cards cannot show: the running-best window-end power of all
three islands across generations 0 to 30, drawn as a step against the 5 kW
floor.

Drawn values: four NR-062 forms on the island-3 line (5.86, 5.4, 5.89, 5.31),
each one of the signed pair NR-062 carries. No objective curve, no mass curve,
no slope numeral. The objective curve is the convergence plate (row 16).

Run:
  /usr/bin/python3 docs/reporting/figures/machine-power-trend/\\
      machine-power-trend.py --script-commit <hex>

Toolchain pin: /usr/bin/python3 (CPython 3.12), matplotlib 3.10.
F-REPRO: svg.hashsalt set, SVG dc:date normalised, PDF CreationDate pinned,
no timestamps anywhere.
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
RUN_DIR = (REPO / "scripts" / "results"
           / "v13_5kw_masslift_len18.8_rotorcount_bankderate2")
SLUG = "machine-power-trend"

DATA_COMMIT = "dd3cc6a"
RUN_COMMIT = "a76c5e9"
ERA = "post-95c385d_wind-authority"
ROWS = "NR-002 \u00b7 NR-005 \u00b7 NR-006 \u00b7 NR-062 \u00b7 NR-066"

INK = "#1a1a1a"
GREY = "#555555"
FAINT = "#777777"
MUTED = "#98a0a8"
AMBER = "#c08a1e"
ISL = {1: "#4a7fb5", 2: "#2e8b57", 3: "#c1441e"}

# NR-062 display forms (signed 2026-10-18). The window-end member of the
# signed pair. Gen 6 prints 5.4 as recorded: two significant digits.
P_FORMS = {0: "5.86", 6: "5.4", 10: "5.89", 18: "5.78",
           22: "5.76", 25: "5.52", 26: "5.31"}
# The four forms this plate prints. Each is one of the seven above.
P_DRAWN = (0, 6, 10, 26)

# NR-036 forms, used as the running-best identity check against the telemetry.
OBJ_FORMS = {0: 36.109, 6: 32.293, 10: 31.661, 18: 30.929,
             22: 29.854, 25: 28.315, 26: 27.364}

TITLE = "Window-end power drives the over-power penalty"
SUB1 = ("running-best window-end power \u00b7 three islands \u00b7 "
        "generations 0 to 30 \u00b7 era " + ERA)
SUB2 = ("island 3 falls 5.89 to 5.31 kW from gen 10 to gen 26 \u00b7 its score "
        "falls 36.109 to 27.364 kg-eq (NR-062, NR-005, NR-006)")

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


def best_so_far(rows: list[dict]) -> dict[int, tuple[float, float, int, int]]:
    """Running-best per generation: least fitness, ties to earliest (gen, idx).

    Returns gen -> (fitness, P_end, source gen, source idx).
    """
    ok = [(float(r["fitness"]), float(r["P_end"]), int(r["gen"]),
           int(r["idx"])) for r in rows if r["status"] == "ok"]
    out = {}
    for g in range(31):
        cand = [(f, pe, gg, i) for (f, pe, gg, i) in ok if gg <= g]
        out[g] = min(cand, key=lambda t: (t[0], t[2], t[3]))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script-commit", default="uncommitted")
    ap.add_argument("--outdir", default=str(HERE))
    args = ap.parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    tele = {i: load(RUN_DIR / f"island_{i}" / "telemetry.csv")
            for i in (1, 2, 3)}
    ser = {i: best_so_far(tele[i]) for i in (1, 2, 3)}
    gens = list(range(31))

    checks: list[tuple[str, object, object, bool]] = []

    def chk(name, got, want):
        if isinstance(got, list) and isinstance(want, list):
            ok = len(got) == len(want) and all(
                (abs(float(a) - float(b)) <= 6e-4
                 if isinstance(a, (int, float)) and isinstance(b, (int, float))
                 else a == b) for a, b in zip(got, want))
        else:
            ok = got == want
        checks.append((name, got, want, ok))

    chk("telemetry rows per island", [len(tele[i]) for i in (1, 2, 3)],
        [310, 310, 310])
    chk("generations covered", [sorted({int(r["gen"]) for r in tele[1]})[0],
                                max(int(r["gen"]) for r in tele[1])], [0, 30])
    chk("rows per generation per island",
        sorted({sum(1 for r in tele[1] if int(r["gen"]) == g)
                for g in range(31)}), [10])
    chk("common seed \u00b7 fitness and window-end power",
        [ser[i][0][0] for i in (1, 2, 3)] + [ser[i][0][1] for i in (1, 2, 3)],
        [36.109, 36.109, 36.109, 5.86, 5.86, 5.86])
    chk("island 3 running-best fitness == NR-036 forms",
        [round(ser[3][g][0], 3) for g in P_FORMS],
        [OBJ_FORMS[g] for g in P_FORMS])
    chk("island 3 running-best P_end == NR-062 forms",
        [f"{ser[3][g][1]:.2f}" for g in P_FORMS],
        [f"{float(v):.2f}" for v in P_FORMS.values()])
    step_gens = [g for g in range(1, 31)
                 if ser[3][g][2:] != ser[3][g - 1][2:]]
    chk("island 3 steps land on the strip's seven generations",
        [0] + step_gens, sorted(P_FORMS))
    chk("no interpolation: a step holds one source machine",
        all(ser[3][g][1] == ser[3][g - 1][1] for g in range(1, 31)
            if g not in step_gens), True)
    chk("running-best fitness never rises",
        [all(ser[i][g][0] <= ser[i][g - 1][0] + 1e-12 for g in range(1, 31))
         for i in (1, 2, 3)], [True, True, True])
    all_pe = [ser[i][g][1] for i in (1, 2, 3) for g in gens]
    chk("all 93 running-best values at or above the 5 kW floor",
        min(all_pe) >= 5.0, True)
    chk("all 93 running-best values below 6.0 kW",
        max(all_pe) < 6.0, True)
    chk("island 1 sits on the floor, generations 8 to 14",
        [g for g in gens if ser[1][g][1] == 5.0], list(range(8, 15)))
    chk("island 3 ends below the seed", ser[3][30][1] < ser[3][0][1], True)
    ok_pe = sorted(float(r["P_end"]) for i in (1, 2, 3) for r in tele[i]
                   if r["status"] == "ok")
    chk("ok evaluations (NR-002 feasible count)", len(ok_pe), 508)
    chk("no ok evaluation below the 5 kW gate",
        sum(1 for v in ok_pe if v < 5.0), 0)
    chk("exactly one ok evaluation on the gate", ok_pe.count(5.0), 1)
    chk("the next lowest ok evaluation", ok_pe[1], 5.02)
    chk("the highest ok evaluation", ok_pe[-1], 6.33)

    n_fail = sum(1 for *_, ok in checks if not ok)
    if n_fail:
        for name, got, want, ok in checks:
            if not ok:
                print(f"check: {name}: {got}  (OFF vs {want})", file=sys.stderr)
        print(f"in-script checks FAILED: {n_fail}", file=sys.stderr)
        return 1

    # ---------------------------------------------------------------- figure
    plt.rcParams.update({
        "font.size": 8,
        "svg.hashsalt": "ktd-fig-pin-2026-10-20",
        "svg.fonttype": "none",
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "figure.facecolor": "white",
        "savefig.facecolor": "white",
    })

    fig = plt.figure(figsize=(7.6, 4.1))
    fig.text(0.012, 0.958, keep(TITLE), size=12, weight="bold", color=INK)
    fig.text(0.012, 0.910, keep(SUB1), size=8, color=GREY)
    fig.text(0.012, 0.872, keep(SUB2), size=8, color=GREY)

    ax = fig.add_axes([0.088, 0.250, 0.845, 0.570])
    xdraw = gens + [30.9]
    for i, ls, lw, z in ((1, "-", 1.2, 3), (2, (0, (4, 2)), 1.2, 3),
                         (3, "-", 2.3, 5)):
        y = [ser[i][g][1] for g in gens] + [ser[i][30][1]]
        ax.step(xdraw, y, where="post", color=ISL[i], lw=lw,
                ls=ls, zorder=z, solid_capstyle="butt")
    ax.plot([g for g in P_FORMS], [ser[3][g][1] for g in P_FORMS],
            ls="none", marker="o", ms=3.4, mfc=ISL[3], mec="white",
            mew=0.6, zorder=6)

    box = dict(boxstyle="round,pad=0.14", fc="white", ec="none", alpha=0.93)
    ax.axhline(5.0, color=AMBER, lw=1.0, ls=(0, (5, 3)), zorder=2)
    ax.text(0.15, 5.035, keep("5 kW floor"), ha="left", va="bottom",
            size=7.5, color=AMBER, zorder=7)
    ax.text(8.35, 5.045, keep("the tightest pass") + "\n"
            + keep("one design of 508"),
            ha="left", va="bottom", size=7.2, color=GREY, linespacing=1.05,
            bbox=box, zorder=8)
    ax.text(0.9, 5.905, keep("the common seed \u00b7 5.86"), ha="left",
            va="bottom", size=8, color=GREY, bbox=box, zorder=8)
    ax.text(6.2, 5.355, keep("5.4"), ha="left", va="top", size=8,
            color=ISL[3], bbox=box, zorder=8)
    ax.text(10.3, 5.93, keep("5.89"), ha="left", va="bottom", size=8,
            color=ISL[3], bbox=box, zorder=8)
    ax.text(30.45, 5.35, keep("5.31"), ha="right", va="bottom", size=8,
            color=ISL[3], bbox=box, zorder=8)

    ax.text(31.05, 5.92, keep("island 2"), ha="left", va="center", size=8,
            color=ISL[2], bbox=box, zorder=8)
    ax.text(31.05, 5.68, keep("island 1"), ha="left", va="center", size=8,
            color=ISL[1], bbox=box, zorder=8)
    ax.text(31.05, 5.31, keep("island 3"), ha="left", va="center", size=8,
            color=ISL[3], bbox=box, zorder=8)

    ax.set_xlim(-0.9, 34.6)
    ax.set_ylim(4.85, 6.12)
    ax.set_xticks([0, 5, 10, 15, 20, 25, 30])
    ax.set_xticklabels([keep(str(v)) for v in (0, 5, 10, 15, 20, 25, 30)])
    ax.set_yticks([5.0, 5.5, 6.0])
    ax.set_yticklabels([keep("5.0"), keep("5.5"), keep("6.0")])
    ax.set_xlabel(keep("generation \u00b7 search order"), size=8, color=GREY)
    ax.set_ylabel(keep("window-end power (kW)") + "\n"
                  + keep("the floor is a gate, not a target"),
                  size=8, color=GREY)
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    for sp in ("left", "bottom"):
        ax.spines[sp].set_color(MUTED)
        ax.spines[sp].set_linewidth(0.8)
    ax.tick_params(labelsize=7.5, colors=GREY, length=2.5)
    ax.set_axisbelow(True)
    ax.yaxis.grid(True, color="#e8e8e8", lw=0.6)

    fig.text(0.088, 0.150,
             keep("step, no interpolation \u00b7 the running-best machine changes "
                  "only when a better design is recorded"),
             size=7, color=FAINT, style="italic")
    fig.text(0.012, 0.100,
             keep("sources: the campaign telemetry, islands 1 to 3 \u00b7 "
                  f"data commit {DATA_COMMIT} \u00b7 run {RUN_COMMIT}"),
             size=6.8, color=FAINT)
    fig.text(0.012, 0.062,
             keep(f"rows {ROWS} \u00b7 script commit {args.script_commit} \u00b7 "
                  "the four printed forms are the window-end member NR-062 signs"),
             size=6.8, color=FAINT)

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
        "mode": "trend",
        "script": {"path": f"docs/reporting/figures/{SLUG}/{SLUG}.py",
                   "sha256": sha256(Path(__file__).resolve())},
        "toolchain": {"python": ".".join(str(v) for v in sys.version_info[:3]),
                      "matplotlib": matplotlib.__version__,
                      "numpy": __import__("numpy").__version__,
                      "svg_text_layer": "glyph text, not paths"},
        "inputs": {
            "extracts": [
                {"path": ("scripts/results/v13_5kw_masslift_len18.8_"
                          f"rotorcount_bankderate2/island_{i}/telemetry.csv"),
                 "sha256": sha256(RUN_DIR / f"island_{i}" / "telemetry.csv")}
                for i in (1, 2, 3)
            ],
            "register_rows": ["NR-002", "NR-005", "NR-006", "NR-062", "NR-066"],
        },
        "data_commit": DATA_COMMIT,
        "run_commit": RUN_COMMIT,
        "era": ERA,
        "script_commit": args.script_commit,
        "command": (f"/usr/bin/python3 docs/reporting/figures/{SLUG}/"
                    f"{SLUG}.py --script-commit {args.script_commit}"),
        "statistic": ("window-end power (P_end) of each island's running-best "
                      "machine, one point per generation, n = 3 per generation"),
        "selection": ("running-best = least recorded fitness among ok rows with "
                      "gen <= G; ties to earliest (gen, idx); no interpolation"),
        "drawn_forms": {str(g): P_FORMS[g] for g in sorted(P_DRAWN)},
        "withheld": ("no objective curve (convergence row 16), no mass curve, "
                     "no slope numeral, no derived difference"),
        "outputs": {f"{SLUG}.svg": sha256(svg), f"{SLUG}.pdf": sha256(pdf),
                    f"{SLUG}.png": sha256(png),
                    "label-ledger.txt": sha256(outdir / "label-ledger.txt")},
    }
    (outdir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8")

    log = [f"check: {n}: {g}  ({'OK' if ok else 'OFF vs ' + str(w)})"
           for n, g, w, ok in checks]
    log.append(f"ledger strings: {len(ledger)}")
    log.append(f"outputs sha256: png {sha256(png)}")
    log.append(f"                svg {sha256(svg)}")
    log.append(f"                pdf {sha256(pdf)}")
    log.append("checks: ALL OK")
    (outdir / "checks.log").write_text("\n".join(log) + "\n", encoding="utf-8")
    for line in log:
        print(line)
    print(f"written: {SLUG}.svg / .pdf / .png, label-ledger.txt, manifest.json")
    print("F-LABEL self-check: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
