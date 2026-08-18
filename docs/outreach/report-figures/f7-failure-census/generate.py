#!/usr/bin/env python3
"""F7 — failure census: telemetry status counts per length (v13 5 kW)."""
import csv, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "..", "..")
LENS = ["18.0", "21.2", "25.0"]
CATS = ["ok", "clearance_reject", "reject", "reject_twist"]
COLS = {"ok": "#2ca02c", "clearance_reject": "#ffb000",
        "reject": "#d62728", "reject_twist": "#7a1f1f"}

counts = {L: {c: 0 for c in CATS} for L in LENS}
for L in LENS:
    path = os.path.join(ROOT, "scripts", "results", f"v13_5kw_len{L}", "telemetry.csv")
    with open(path) as f:
        for line in f:
            if line.startswith("#") or line.startswith("island"):
                continue
            status = line.split(",")[4].strip()
            if status in counts[L]:
                counts[L][status] += 1

fig, ax = plt.subplots(figsize=(7.6, 4.9), dpi=300)
y = np.arange(len(LENS))
for k, cat in enumerate(CATS):
    vals = [counts[L][cat] for L in LENS]
    bars = ax.barh(y + (k - 1.5) * 0.19, vals, height=0.19,
                   color=COLS[cat], label=cat)
    for b, v in zip(bars, vals):
        ax.text(b.get_width() + 4, b.get_y() + b.get_height() / 2,
                str(v), va="center", fontsize=8,
                bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="none", alpha=1.0))

ax.set_yticks(y)
ax.set_yticklabels([f"{L} m" for L in LENS])
ax.set_xlabel("designs evaluated (outcome at the end of the simulation window)")
ax.set_xlim(0, 820)
ax.set_title("5 kW campaigns — evaluation outcomes by TRPT length (v13)", pad=26)
ax.legend(fontsize=8, frameon=False, ncol=4, loc="upper center",
          bbox_to_anchor=(0.5, 1.14))
ax.grid(axis="x", alpha=0.25, lw=0.5)
fig.tight_layout(rect=(0, 0.21, 1, 1))
CAPTION = ("All 2,784 designs the three search campaigns evaluated (each campaign ran one chain length: 18,\n"
           "21.2 or 25 m), tallied by outcome: green passed, amber failed the 1.5 m ground-clearance gate,\n"
           "red ran but failed the scoring gates (sustained power below the floor, structure below the hard\n"
           "FoS gate, or above-Betz power \u2014 a divergence flag), dark red rejected on chain twist. 1,921\n"
           "passed; clearance is the dominant rejection (226/279/151) and twist rejects triple at 25 m \u2014\n"
           "the search scrapes the 1.5 m ground gate, the same safety constraint a real rig respects.")
fig.text(0.5, 0.02, CAPTION, ha="center", va="bottom", fontsize=8.2, color="#333333")
fig.savefig(os.path.join(HERE, "figure.png"), dpi=300)
fig.savefig(os.path.join(HERE, "figure.pdf"))
print("wrote", os.path.join(HERE, "figure.png"))
