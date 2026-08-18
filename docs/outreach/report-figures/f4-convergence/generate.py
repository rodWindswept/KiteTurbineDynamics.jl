#!/usr/bin/env python3
"""F4 — convergence traces, 3 islands x 3 lengths (v13 5 kW campaigns)."""
import csv, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "..", "..")
LENS = ["18.0", "21.2", "25.0"]
COLS = ["#1f77b4", "#ff7f0e", "#2ca02c"]

fig, axes = plt.subplots(1, 3, figsize=(10.5, 4.4), dpi=300, sharey=True)

for ax, L in zip(axes, LENS):
    path = os.path.join(ROOT, "scripts", "results", f"v13_5kw_len{L}", "convergence.csv")
    by_island = {}
    for r in csv.DictReader(open(path)):
        by_island.setdefault(r["island"], []).append((int(r["iteration"]), float(r["fitness"])))
    for isl, pts in sorted(by_island.items()):
        its = [p[0] for p in pts]; fs = [p[1] for p in pts]
        ax.plot(its, fs, color=COLS[int(isl) - 1], lw=1.4,
                label=f"island {isl}")
    ax.set_title(f"{L} m", fontsize=11)
    ax.set_xlabel("generation")
    ax.grid(alpha=0.25, lw=0.5)
    ax.set_xlim(0, 31)

axes[0].set_ylabel("fitness (minimised;\nrejects = 1e9 off-scale)")
axes[0].legend(fontsize=8, frameon=True, facecolor="white", edgecolor="none")
for ax in axes:
    ax.set_ylim(-8.6, -2.5)
fig.suptitle("5 kW DE campaigns — best fitness per generation (minimised)", fontsize=12)
fig.tight_layout(rect=(0, 0.14, 1, 0.94))
fig.subplots_adjust(left=0.13)
CAPTION = ("Three 5 kW design campaigns, one per chain length: each line is one of the three parallel search\n"
           "populations ('islands') — its best design per generation. Lower fitness = better design; all searches\n"
           "converge to a plateau — 18 m at \u22126.22, 21.2 m at \u22126.66, 25 m at \u22127.31 — the longer chain reaches\n"
           "the deeper minimum. The plateaus are the edge of the design space, not a stalled search: fitness stopped\n"
           "improving because the remaining designs fail clearance or twist, not because the search gave up.")
fig.text(0.5, 0.02, CAPTION, ha="center", va="bottom", fontsize=8.2, color="#333333")
fig.savefig(os.path.join(HERE, "figure.png"), dpi=300)
fig.savefig(os.path.join(HERE, "figure.pdf"))
print("wrote", os.path.join(HERE, "figure.png"))
