#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""eval-timeline: generating script for the row-4 plate (the evaluator protocol).

Plate: docs/reporting/figures/eval-timeline/SPEC.md (GENERATE stage, R2).
Draws the measurement-window evaluation timeline for the island-3 winner
from the committed extracts (docs/reporting/figures/eval-timeline-extract/,
tree 980de02; docs/reporting/figures/window-trace-extract/, tree 8d01394):

  lane 1  angular rate, ground ring and top ring (cold extract)
  lane 2  generator power, with the window mean and P_end marks
  lane 3  peak line strain / break strain: cold, warm as coded, ruling-mode
          condition run; inset over the first 12 ms
  lane 4  gate map: when each gate reads the run

The two lane-3 strain annotations ride the NR-013 extension (signed
2026-10-12).  Quote forms as signed: 1.00081 at t = 2.841 ms; 1.448 at
t = 5.798 ms, the extract grid max.  The ruling-mode curve prints under
the condition-run label only.  No label claims the machine "would pass".

v2 (the round-6 hub-name retirement, 2026-10-14): the lane-1 label
reads "ω top" and the gate row reads "top · tip · Betz". The
drawn rows list takes NR-042 (its recorded next-build item). No
drawn value moves.

v3 (the placement landed, 2026-10-15): the lane-3 label takes the
landed form "rope-break gate off during relax". The head comment sweeps
to the top form. No drawn value moves.

v4 (the readability re-cut, 2026-10-21): the lane-4 labels go from four
blocks of three or four short fragments to eleven lines at four anchors
(3.80 / 2.80 / 1.50 / 0.35), so the blocks separate at 0.55 against the
0.30 in-block pitch.  A first pass at 0.45 gaps (1.5 times the pitch)
still read as one paragraph in the render, so the four gaps are uniform
at 1.8 times the pitch. The gate key enters as one drawn line
(band, tick, box, diamond), the phase-strip label reads "relax (grey)",
the cold-path label carries its sampling cadence ("one value every
10 ms"), and the lesson line moves from faint italic 6.8 to ink 7.5.
The power-floor block keeps its four lines, so NR-039's name stays
drawn. The footer keeps the nine rows. No drawn value moves; the label
census goes 52 to 50 strings (14 out, 11 in, two rewrites, one new key).

v5 (the lane-key re-cut, 2026-10-21): the gate-map rows name the gate
and the key carries when it reads, so the row no longer repeats the
key.  The four rows read one line each ("rope break", "twist, top, tip
and Betz", "power floor, over-power", "ground clearance"), except the
clearance row, which keeps NR-042's signed string (">= 1.5 m, at
decode") whole on its own line.  The key draws the four marks as glyphs
at the form the lane uses, each named by its cadence ("every step, relax
included" / "one read per second" / "mean of the last five samples" /
"one read, at decode").  The old one-line key named two different marks
"one read", which is the ambiguity the founder flagged.  The panel takes
a 0.150 height at 0.150 so the two key lines clear the x label.  No
drawn value moves.

Run:
  /usr/bin/python3 docs/reporting/figures/eval-timeline/eval-timeline.py \
      --script-commit <hex>

Toolchain pin: /usr/bin/python3 (CPython 3.12.3), matplotlib 3.10.8,
numpy 2.4.4.  F-REPRO: svg.hashsalt set, SVG dc:date normalised, PDF
CreationDate pinned, no timestamps anywhere.

Outputs (in this directory): eval-timeline.svg / .pdf / .png,
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
from matplotlib.lines import Line2D
from matplotlib.patches import Rectangle

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
EXTRACT = REPO / "docs" / "reporting" / "figures" / "eval-timeline-extract"
TAPS_DIR = REPO / "docs" / "reporting" / "figures" / "window-trace-extract"
SLUG = "eval-timeline"

DATA_COMMIT = "dd3cc6a"
ROWS = ("NR-008 \u00b7 NR-012 \u00b7 NR-013 \u00b7 NR-013 ext \u00b7 NR-016 "
        "\u00b7 NR-027 \u00b7 NR-029 \u00b7 NR-039 \u00b7 NR-042")

INK = "#1a1a1a"
LINE = "#333333"
GREY = "#555555"
FAINT = "#777777"
MUTED = "#98a0a8"
RED = "#b32222"
STEEL = "#3d6b8e"
REF = "#8a8a8a"
SHADE = "#f0f0f0"
EDGE = "#c9c9c9"

TITLE = "The cold path holds the window; the warm start breaks in milliseconds"
SUB = ("Winner island-3 machine \u00b7 as-coded cold and warm paths \u00b7 "
       "100 Hz extract at tree 980de02 \u00b7 era post-95c385d_wind-authority")

KEY_BAND = "every step, relax included"
KEY_TICK = "one read per second"
KEY_BOX = "mean of the last five samples"
KEY_DIAMOND = "one read, at decode"

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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script-commit", default="uncommitted")
    ap.add_argument("--outdir", default=str(HERE))
    args = ap.parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    cold = load(EXTRACT / "extract-eval-timeline-cold.csv")
    warm = load(EXTRACT / "extract-eval-timeline-warm.csv")
    rule = load(EXTRACT / "extract-eval-timeline-warm-rulingmode.csv")
    taps = load(TAPS_DIR / "extract-winner-window-taps.csv")

    ct = [float(r["t"]) for r in cold]
    cwg = [float(r["omega_gnd"]) for r in cold]
    cwh = [float(r["omega_hub"]) for r in cold]
    cP = [float(r["P_gen_kw"]) for r in cold]
    cs = [float(r["strain_max_over_break"]) for r in cold]
    wt = [float(r["t"]) * 1e3 for r in warm]           # ms
    wt_s = [w / 1e3 for w in wt]                       # seconds (main lane)
    ws = [float(r["strain_max_over_break"]) for r in warm]
    rt = [float(r["t"]) for r in rule]
    rs = [float(r["strain_max_over_break"]) for r in rule]
    rtm = [t * 1e3 for t in rt]                        # ms (inset)

    # ---------------------------------------------------------------- checks
    checks = []
    checks.append(("cold rows", len(cold), 5000))
    checks.append(("warm rows", len(warm), 98))
    checks.append(("ruling rows", len(rule), 1823))
    checks.append(("taps rows", len(taps), 52))
    checks.append(("taps phases (relax / window)",
                   [r["phase"] for r in taps].count("relax"), 11))
    checks.append(("taps phases (window)",
                   [r["phase"] for r in taps].count("window"), 41))
    t_win = [i for i, r in enumerate(taps) if r["phase"] == "window"]
    t_mean = sum(float(taps[i]["omega_gnd"]) for i in t_win) / len(t_win)
    checks.append(("taps window mean omega (NR-029)", t_mean, 13.380259861740395))
    win = [i for i, t in enumerate(ct) if t > 10.0]
    Pbar = sum(cP[i] for i in win) / len(win)
    checks.append(("cold window mean P (100 Hz)", Pbar, 5.3098))
    checks.append(("cold latch count", sum(int(r["any_broken"]) for r in cold), 0))
    checks.append(("warm end t (s)", wt_s[-1], 0.002841))
    checks.append(("warm end strain", ws[-1], 1.00081))
    checks.append(("ruling grid max", max(rs), 1.4480))
    checks.append(("ruling latch count", sum(int(r["any_broken"]) for r in rule), 0))
    for name, got, want in checks:
        ok = abs(got - want) / max(abs(want), 1e-12) < 5e-3 if isinstance(got, float) else got == want
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

    fig = plt.figure(figsize=(7.6, 9.0))
    fig.text(0.012, 0.976, keep(TITLE), size=10.5, weight="bold", color=INK)
    fig.text(0.012, 0.953, keep(SUB), size=7.5, color=GREY)

    ML, MW = 0.19, 0.775
    ax1 = fig.add_axes([ML, 0.718, MW, 0.130])
    ax2 = fig.add_axes([ML, 0.560, MW, 0.130])
    ax3 = fig.add_axes([ML, 0.312, MW, 0.212])
    ax4 = fig.add_axes([ML, 0.150, MW, 0.150])

    for ax in (ax1, ax2, ax3, ax4):
        ax.set_xlim(0, 50)
        ax.axvspan(0, 10, color=SHADE, zorder=0)
        ax.axvline(10, color="#b0b0b0", lw=0.8, ls=(0, (2, 3)), zorder=1)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        for sp in ("left", "bottom"):
            ax.spines[sp].set_color(MUTED)
            ax.spines[sp].set_linewidth(0.8)
        ax.tick_params(labelsize=7, colors=GREY, length=2.5)

    # ------------------------------------------------------------ phase strip
    axp = fig.add_axes([ML, 0.878, MW, 0.030])
    axp.set_axis_off()
    axp.set_xlim(0, 50)
    axp.set_ylim(0, 1)
    axp.add_patch(Rectangle((0, 0.15), 10, 0.7, facecolor=SHADE, edgecolor=EDGE, lw=0.7))
    axp.add_patch(Rectangle((10, 0.15), 40, 0.7, facecolor="white", edgecolor=EDGE, lw=0.7))
    axp.text(5, 0.5, keep("relax (grey)"), ha="center", va="center", size=7.5, color=GREY)
    axp.text(30, 0.5, keep("measurement window"), ha="center", va="center", size=7.5, color=GREY)
    axp.plot([10, 10], [0.05, 0.95], color="#b0b0b0", lw=0.8)

    # ---------------------------------------------------------------- lane 1
    ax1.plot(ct, cwg, color=INK, lw=1.4, zorder=3)
    ax1.plot(ct, cwh, color="#9a9a9a", lw=1.0, ls=(0, (4, 2)), zorder=4)
    ax1.set_ylim(9, 15)
    ax1.set_yticks([9, 11, 13, 15])
    ax1.set_yticklabels([keep("9"), keep("11"), keep("13"), keep("15")])
    ax1.set_ylabel(keep("rate \u03c9 (rad/s)"), size=7.5, color=GREY)
    ax1.axhline(10.17, color=REF, lw=0.9, ls=(0, (3, 3)), zorder=2)
    ax1.axhline(13.38, color=REF, lw=0.9, ls=(0, (3, 3)), zorder=2)
    ax1.text(49.6, 10.42, keep("10.17 \u2014 start: rotor Cp-peak speed (NR-016)"),
             ha="right", va="bottom", size=7, color=GREY)
    ax1.text(49.6, 13.02, keep("13.38 \u2014 window mean (NR-029)"),
             ha="right", va="top", size=7, color=GREY)
    ax1.text(0.6, 14.55, keep("\u03c9 gnd (solid) \u00b7 \u03c9 top (dashed)"),
             ha="left", va="top", size=7, color=GREY)
    ax1.set_xticks([])

    # ---------------------------------------------------------------- lane 2
    ax2.plot(ct, cP, color=INK, lw=1.4, zorder=3)
    ax2.set_ylim(0, 7)
    ax2.set_yticks([0, 2, 4, 6])
    ax2.set_yticklabels([keep("0"), keep("2"), keep("4"), keep("6")])
    ax2.set_ylabel(keep("generator power (kW)"), size=7.5, color=GREY)
    ax2.axhline(5.0, color=RED, lw=1.0, ls=(0, (4, 3)), zorder=2)
    ax2.plot([10, 50], [5.309, 5.309], color=REF, lw=1.0, ls=(0, (3, 3)), zorder=2)
    ax2.plot([46, 50], [5.314, 5.314], color=INK, lw=2.2, zorder=2)
    ax2.text(49.6, 4.72, keep("5 kW floor \u2014 read on P_end"),
             ha="right", va="top", size=7, color=RED)
    ax2.text(49.6, 5.52, keep("window mean P 5.309 kW \u00b7 P_end 5.314 kW last five (NR-008)"),
             ha="right", va="bottom", size=7, color=GREY)
    ax2.set_xticks([])

    # ---------------------------------------------------------------- lane 3
    ax3.plot(ct, cs, color=INK, lw=1.3, zorder=3)
    ax3.plot(rt, rs, color=STEEL, lw=1.1, ls=(0, (4, 2)), zorder=3)
    ax3.plot(wt_s, ws, color=RED, lw=1.8, zorder=4)
    ax3.set_ylim(0, 1.5)
    ax3.set_yticks([0, 0.5, 1.0, 1.5])
    ax3.set_yticklabels([keep("0"), keep("0.5"), keep("1.0"), keep("1.5")])
    ax3.set_ylabel(keep("peak strain / break strain"), size=7.5, color=GREY)
    ax3.axhline(1.0, color=RED, lw=1.4, ls=(0, (5, 4)), zorder=2)

    wbox = dict(boxstyle="round,pad=0.18", fc="white", ec="none", alpha=1.0)
    ax3.text(49.6, 1.11, keep("break strain \u2014 rope-break gate"),
             ha="right", va="bottom", size=7, color=RED)
    ax3.text(2.0, 1.47, keep("warm as coded: breaks at t = 2.841 ms \u2014 run ends"),
             ha="left", va="top", size=7, color=RED)
    ax3.text(49.6, 0.80, keep("ruling-mode condition run (dashed) \u2014 peak 1.448 at t = 5.798 ms"),
             ha="right", va="bottom", size=7, color=STEEL, bbox=wbox)
    ax3.text(49.6, 0.66, keep("rope-break gate off during relax"),
             ha="right", va="bottom", size=7, color=STEEL, bbox=wbox)
    ax3.text(49.6, 0.08, keep("cold path (solid line) \u2014 one value every 10 ms"),
             ha="right", va="bottom", size=7, color=INK, bbox=wbox)
    ax3.set_xticks([])

    # inset: first 12 ms.  The frame is placed so the inset break line sits at
    # the same height as the lane break line (y0 = 0.3786).  No ticks: the
    # label rides inside the frame, so nothing lands in the dash field below.
    axi = fig.add_axes([0.213, 0.3786, 0.235, 0.112])
    axi.set_xlim(0, 12)
    axi.set_ylim(0, 1.5)
    axi.axhline(1.0, color=RED, lw=1.0, ls=(0, (5, 4)))
    axi.plot(rtm, rs, color=STEEL, lw=1.0, ls=(0, (4, 2)))
    axi.plot(wt, ws, color=RED, lw=1.4)
    axi.set_xticks([])
    axi.set_yticks([])
    axi.text(11.6, 1.45, keep("first 12 ms"), ha="right", va="top", size=6.5, color=GREY)
    for sp in ("top", "right"):
        axi.spines[sp].set_visible(False)
    for sp in ("left", "bottom"):
        axi.spines[sp].set_color(MUTED)
        axi.spines[sp].set_linewidth(0.7)

    # ---------------------------------------------------------------- lane 4
    ax4.set_ylim(0, 4.4)
    ax4.set_yticks([])
    ax4.spines["left"].set_visible(False)
    ax4.set_xticks([0, 10, 20, 30, 40, 50])
    ax4.set_xticklabels([keep("0"), keep("10"), keep("20"), keep("30"), keep("40"), keep("50")])
    ax4.tick_params(axis="x", pad=2)
    ax4.set_xlabel(keep("evaluation time (s)"), size=7.5, color=GREY, labelpad=2)

    # v5: the row names the gate; the key carries when that gate reads.  One
    # line per row at 7 pt, so the four gates separate at a glance instead of
    # reading as a paragraph of fragments.  The clearance row keeps NR-042's
    # signed string ("\u2265 1.5 m, at decode") whole on its own line.
    def row_label(y: float, s: str) -> None:
        ax4.text(-0.8, y, keep(s), ha="right", va="center", size=7, color=INK)

    row_label(3.8, "rope break")
    ax4.add_patch(Rectangle((0, 3.375), 50, 0.85, facecolor=RED, edgecolor=RED,
                            lw=0.7, alpha=0.13, zorder=2))
    ax4.plot([0, 50], [3.375, 3.375], color=RED, lw=0.7)
    ax4.plot([0, 50], [4.225, 4.225], color=RED, lw=0.7)

    row_label(2.80, "twist, top, tip and Betz")
    ax4.plot([10, 50], [2.80, 2.80], color=GREY, lw=1.0, zorder=2)
    for k in range(11, 51):
        ax4.plot([k, k], [2.63, 2.97], color=GREY, lw=0.8, zorder=3)

    row_label(1.50, "power floor, over-power")
    ax4.add_patch(Rectangle((46, 1.075), 4, 0.85, facecolor="#888888", edgecolor=GREY,
                            lw=0.7, alpha=0.30, zorder=2))

    row_label(0.50, "ground clearance")
    row_label(0.20, "\u2265 1.5 m, at decode")
    ax4.plot([0.75], [0.35], marker="D", ms=3.4, color=GREY, zorder=3)

    # The key draws each mark at the form the lane uses: four glyphs, each
    # named by the cadence it stands for, in two columns under the panel.
    # The reader gets shape -> meaning here, and gate name -> row above.
    KY1, KY2 = 0.096, 0.074

    def key_mark(x: float, y: float, kind: str) -> float:
        if kind == "band":
            fig.add_artist(Rectangle((x, y - 0.0055), 0.036, 0.011,
                                     transform=fig.transFigure, facecolor=RED,
                                     edgecolor=RED, lw=0.7, alpha=0.13))
        elif kind == "tick":
            fig.add_artist(Line2D([x + 0.018, x + 0.018], [y - 0.0075, y + 0.0075],
                                  transform=fig.transFigure, color=GREY, lw=0.9))
        elif kind == "box":
            fig.add_artist(Rectangle((x, y - 0.0055), 0.028, 0.011,
                                     transform=fig.transFigure, facecolor="#888888",
                                     edgecolor=GREY, lw=0.7, alpha=0.30))
        else:
            fig.add_artist(Line2D([x + 0.014], [y], transform=fig.transFigure,
                                  marker="D", ms=3.4, color=GREY, linestyle="none"))
        return x + 0.046

    for x0, y, kind, s in ((ML, KY1, "band", KEY_BAND),
                           (0.600, KY1, "tick", KEY_TICK),
                           (ML, KY2, "box", KEY_BOX),
                           (0.600, KY2, "diamond", KEY_DIAMOND)):
        fig.text(key_mark(x0, y, kind), y, keep(s), size=7.5, color=GREY,
                 ha="left", va="center")

    fig.text(ML, 0.050, keep("The rope-break gate is the only read that covers the relax; the per-second reads can miss a crossing."),
             size=7.5, color=INK)
    stamp1 = ("sources: eval-timeline-extract \u00b7 window-trace-extract \u00b7 "
              f"data commit {DATA_COMMIT} \u00b7 trees 980de02 / 8d01394")
    stamp2 = f"rows {ROWS} \u00b7 script commit {args.script_commit}"
    fig.text(0.012, 0.030, keep(stamp1), size=6.5, color=FAINT)
    fig.text(0.012, 0.013, keep(stamp2), size=6.5, color=FAINT)

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
            "extracts": [
                {"path": "docs/reporting/figures/eval-timeline-extract/extract-eval-timeline-cold.csv",
                 "sha256": sha256(EXTRACT / "extract-eval-timeline-cold.csv")},
                {"path": "docs/reporting/figures/eval-timeline-extract/extract-eval-timeline-warm.csv",
                 "sha256": sha256(EXTRACT / "extract-eval-timeline-warm.csv")},
                {"path": "docs/reporting/figures/eval-timeline-extract/extract-eval-timeline-warm-rulingmode.csv",
                 "sha256": sha256(EXTRACT / "extract-eval-timeline-warm-rulingmode.csv")},
                {"path": "docs/reporting/figures/window-trace-extract/extract-winner-window-taps.csv",
                 "sha256": sha256(TAPS_DIR / "extract-winner-window-taps.csv")},
            ],
            "register_rows": ["NR-008", "NR-012", "NR-013", "NR-013 ext",
                              "NR-016", "NR-027", "NR-029", "NR-039", "NR-042"],
        },
        "data_commit": DATA_COMMIT,
        "script_commit": args.script_commit,
        "command": (f"/usr/bin/python3 docs/reporting/figures/{SLUG}/{SLUG}.py "
                    f"--script-commit {args.script_commit}"),
        "precision": ("rates 2 dp; power 3 dp; strain annotations as signed; "
                      "floor 5.0 kW"),
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
