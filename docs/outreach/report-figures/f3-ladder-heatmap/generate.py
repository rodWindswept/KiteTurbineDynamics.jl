#!/usr/bin/env python3
"""F3 — ladder heatmap: P_gen across rungs x lengths (ladder_v13.csv @ 2aad90d).

Data accuracy: every plotted cell is one CSV row; the figure is a direct
pivot of ladder_v13.csv. No aggregation, no smoothing.
"""
import csv, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Rectangle

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "..", "..", "..", "..", "scripts", "results", "ladder_v13.csv")
OUT = os.path.join(HERE, "figure.png")

rows = list(csv.DictReader(open(CSV)))
rungs = sorted({float(r["kw"]) for r in rows})
lens = sorted({float(r["L"]) for r in rows})
grid = np.full((len(rungs), len(lens)), np.nan)
verdict = np.zeros((len(rungs), len(lens)), dtype=bool)
stalled = np.zeros((len(rungs), len(lens)), dtype=bool)
for r in rows:
    i = rungs.index(float(r["kw"]))
    j = lens.index(float(r["L"]))
    grid[i, j] = float(r["P_gen_kW"])
    verdict[i, j] = r["verdict"].strip().lower() == "true"
    # Gate stall = never spun up (ω_gnd < the gate's 0.5 rad/s minimum)
    # and did NOT collapse on twist — these cells carry no physics verdict.
    stalled[i, j] = (float(r["w_gnd"]) < 0.5) and (r["crossed"].strip().lower() != "true")

fig, ax = plt.subplots(figsize=(7.2, 6.8), dpi=300)
im = ax.imshow(grid, cmap="viridis", aspect="auto")

# Cell annotations: P_gen value + verdict glyph; stall cells get hatch
for i in range(len(rungs)):
    for j in range(len(lens)):
        v = grid[i, j]
        if np.isnan(v):
            continue
        if stalled[i, j]:
            ax.add_patch(Rectangle((j - 0.5, i - 0.5), 1, 1, fill=False,
                                   hatch="///", edgecolor="0.55", lw=0.7))
            ax.text(j, i, "stall", ha="center", va="center", fontsize=8.5,
                    style="italic", color="0.35")
            continue
        txt = f"{v:.2g}" if v >= 0.1 else "0"
        ax.text(j, i, txt, ha="center", va="center", fontsize=8.5,
                color="white" if v < 0.55 * np.nanmax(grid) else "black")
        if not verdict[i, j]:
            ax.text(j, i + 0.34, "\u2717", ha="center", va="center",
                    fontsize=9, color="#d62728", fontweight="bold")

ax.set_xticks(range(len(lens)))
ax.set_xticklabels([f"{int(L)}" for L in lens])
ax.set_yticks(range(len(rungs)))
ax.set_yticklabels([f"{int(k)}" for k in rungs])
ax.set_xlabel("TRPT chain length (m)")
ax.set_ylabel("Rated-power target (kW)")
ax.set_title("Delivered power at the ground ring — 42 baseline designs (v13)")

cbar = fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
cbar.set_label("P_gen at ground ring (kW)")

fig.tight_layout(rect=(0, 0.19, 1, 1))
CAPTION = ("Every cell is one simulation, not a test: the baseline design family scaled to a rated-power target\n"
           "(rows, 5\u201350 kW) and a chain length (columns, 12\u201340 m), run through the full ODE model for 30 s at\n"
           "11 m/s; the number is the power delivered at the ground ring. The 5\u201315 kW targets deliver\n"
           "4.6\u20138.7 kW at the short lengths (12\u201318 m) and degrade with length; the 40 m column is the twist\n"
           "wall \u2014 the longest chains cross their torsional limit (7\u201315 kW cells) and the 15 kW cell collapses\n"
           "to zero. The hatched 25\u201350 kW cells never spun up in the run \u2014 a gate start-up limitation at this\n"
           "scale, so they carry no verdict, not a failure. \u2717 = ran but failed the gate (power \u2265 2.5 kW,\n"
           "\u03c9 > 0.5 rad/s, no twist crossing, \u2265 1.5 m clearance).")
fig.text(0.5, 0.012, CAPTION, ha="center", va="bottom", fontsize=7.0, color="#333333")
fig.savefig(OUT, dpi=300)
fig.savefig(os.path.join(HERE, "figure.pdf"))
print("wrote", OUT)
