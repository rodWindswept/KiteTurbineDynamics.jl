#!/usr/bin/env python3
"""F6 — coherence traces: corrected-era campaigns (solid) vs voided pre-fix
attempt (dashed). Sources: v13_5kw_len*/convergence.csv @ ec44148 et al. and
void_v13_pre-fix_len*/convergence.csv (audit artifacts, pre-7183f96)."""
import csv, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "..", "..")
LENS = ["18.0", "21.2", "25.0"]
COLS = ["#1f77b4", "#ff7f0e", "#2ca02c"]

def load(path):
    by = {}
    for r in csv.DictReader(open(path)):
        by.setdefault(r["island"], []).append((int(r["iteration"]), float(r["fitness"])))
    return by

fig, axes = plt.subplots(1, 3, figsize=(10.5, 4.4), dpi=300, sharey=True)
for ax, L in zip(axes, LENS):
    win = load(os.path.join(ROOT, "scripts", "results", f"v13_5kw_len{L}", "convergence.csv"))
    void = load(os.path.join(ROOT, "scripts", "results", f"void_v13_pre-fix_len{L}", "convergence.csv"))
    for isl, pts in sorted(win.items()):
        ax.plot([p[0] for p in pts], [p[1] for p in pts], color=COLS[int(isl) - 1],
                lw=1.3, label="corrected era" if isl == "1" else None)
    for isl, pts in sorted(void.items()):
        ax.plot([p[0] for p in pts], [p[1] for p in pts], color=COLS[int(isl) - 1],
                lw=1.1, ls="--", alpha=0.75, label="voided era (pre-fix)" if isl == "1" else None)
    ax.set_title(f"{L} m", fontsize=11)
    ax.set_xlabel("generation")
    ax.set_xlim(0, 31)
    ax.set_ylim(-8.6, -2.5)
    ax.grid(alpha=0.25, lw=0.5)

axes[0].set_ylabel("fitness (v12 objective; lower = better,\nrejects = 1e9 off-scale)")
axes[0].legend(fontsize=8, frameon=True, facecolor="white", edgecolor="none")
fig.suptitle("5 kW campaigns — corrected era (solid) vs voided pre-fix attempt (dashed)", fontsize=11.5)
fig.tight_layout(rect=(0, 0.14, 1, 0.94))
CAPTION = ("The same three chain lengths, two eras of the evaluator: the corrected campaigns (solid lines) and\n"
           "the earlier attempt, voided after a bug was found (dashed). The traces run almost in step \u2014 and at\n"
           "18 m the voided attempt even scores deeper (\u22126.66 vs \u22126.22) \u2014 the trap: the pre-fix evaluator\n"
           "missed a sanity check on the hub geometry, its scores were artificially generous, and \u2018better\u2019 was\n"
           "an artifact. The voided run is kept as evidence of why the check exists, not as a result.")
fig.text(0.5, 0.02, CAPTION, ha="center", va="bottom", fontsize=8.2, color="#333333")
fig.savefig(os.path.join(HERE, "figure.png"), dpi=300)
fig.savefig(os.path.join(HERE, "figure.pdf"))
print("wrote", os.path.join(HERE, "figure.png"))
