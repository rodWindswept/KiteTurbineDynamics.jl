#!/usr/bin/env python3
"""Generate Phase 2.5 paper figures from expansion sweep and v5 campaign data."""

import json
import glob
import warnings
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from pathlib import Path

warnings.filterwarnings("ignore")

# ── Paths ──────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).parent.parent
RESULTS = ROOT / "scripts" / "results"
OUT = ROOT / "scripts" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

EXPANSION_CSV = RESULTS / "expansion_sweep.csv"
V5_SUMMARY    = RESULTS / "trpt_opt_v5" / "campaign_summary.csv"
V5_ISLANDS    = sorted(glob.glob(str(RESULTS / "trpt_opt_v5" / "island_*" / "best_design.csv")))
V6_JSON       = RESULTS / "v6_campaign" / "best_design.json"

# ── Style ──────────────────────────────────────────────────────────────────────
plt.rcParams.update({
    "font.family":       "sans-serif",
    "font.size":         9,
    "axes.labelsize":    9,
    "axes.titlesize":    9,
    "xtick.labelsize":   8,
    "ytick.labelsize":   8,
    "legend.fontsize":   8,
    "axes.grid":         True,
    "grid.color":        "#cccccc",
    "grid.alpha":        0.3,
    "grid.linewidth":    0.5,
    "axes.spines.top":   False,
    "axes.spines.right": False,
    "figure.dpi":        150,
})

POWER_COLORS = {10: "#1f77b4", 20: "#ff7f0e", 50: "#2ca02c"}
POWER_LABELS = {10: "10 kW", 20: "20 kW", 50: "50 kW"}

def save(fig, stem):
    for ext in ("pdf", "png"):
        fig.savefig(OUT / f"{stem}.{ext}", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"  saved {stem}.pdf / .png")


# ── Load data ──────────────────────────────────────────────────────────────────
df = pd.read_csv(EXPANSION_CSV)

v5_summary = pd.read_csv(V5_SUMMARY)
v5_islands = pd.concat([pd.read_csv(f) for f in V5_ISLANDS], ignore_index=True)

with open(V6_JSON) as fh:
    v6 = json.load(fh)

# ── Fig 2 — φ vs n_expansion ───────────────────────────────────────────────────
print("Generating Fig 2 — phi vs n_expansion …")

# Aggregate: mean phi per (power_kw, n_expansion) — baseline n_expansion=0
agg = df.groupby(["power_kw", "n_expansion"])["phi_kg_per_kw"].mean().reset_index()

fig, ax = plt.subplots(figsize=(3.5, 2.8))

for pw in [10, 20, 50]:
    sub = agg[agg.power_kw == pw].sort_values("n_expansion")
    baseline = sub[sub.n_expansion == 0]["phi_kg_per_kw"].values[0]
    ax.axhline(baseline, color=POWER_COLORS[pw], lw=0.8, ls="--", alpha=0.5)
    ax.plot(sub["n_expansion"], sub["phi_kg_per_kw"],
            color=POWER_COLORS[pw], marker="o", ms=4, lw=1.4,
            label=POWER_LABELS[pw])

ax.set_xlabel("Number of expansion rotors $n_\\mathrm{exp}$")
ax.set_ylabel("φ  (kg kW⁻¹)")
ax.set_xticks([0, 1, 2, 3, 4])
ax.legend(loc="upper left", framealpha=0.8)
ax.annotate("dashed = rigid v5 baseline", xy=(0.01, 0.02),
            xycoords="axes fraction", fontsize=7, color="#555555")
fig.tight_layout()
save(fig, "fig02_phi_vs_n_expansion")


# ── Fig A — Ring radius spread vs n_expansion ──────────────────────────────────
# mean_radius_spread_m is uniformly 0.0 in this dataset — skip
print("Fig A — mean_radius_spread_m is all-zero in expansion_sweep.csv; figure skipped.")


# ── Fig C — Placement strategy comparison ─────────────────────────────────────
print("Generating Fig C — placement comparison …")

# Aggregate phi by (placement, n_expansion) for all power classes combined
agg_c = df.groupby(["placement", "n_expansion"])["phi_kg_per_kw"].mean().reset_index()

placements = ["none", "single", "alternating", "clustered"]
n_exps     = sorted(agg_c.n_expansion.unique())
x          = np.arange(len(n_exps))
bar_w      = 0.18
colors_p   = {"none": "#4878d0", "single": "#ee854a",
              "alternating": "#6acc65", "clustered": "#d65f5f"}

fig, ax = plt.subplots(figsize=(7.0, 2.8))

for i, pl in enumerate(placements):
    sub = agg_c[agg_c.placement == pl].sort_values("n_expansion")
    if sub.empty:
        continue
    # align bars: some placements only appear at certain n_expansion values
    vals = []
    for ne in n_exps:
        row = sub[sub.n_expansion == ne]
        vals.append(row["phi_kg_per_kw"].values[0] if not row.empty else np.nan)
    offset = (i - 1.5) * bar_w
    ax.bar(x + offset, vals, width=bar_w, label=pl.capitalize(),
           color=colors_p[pl], alpha=0.85, edgecolor="white", lw=0.4)

ax.set_xticks(x)
ax.set_xticklabels([str(n) for n in n_exps])
ax.set_xlabel("Number of expansion rotors $n_\\mathrm{exp}$")
ax.set_ylabel("φ  (kg kW⁻¹, mean over power classes)")
ax.legend(title="Placement", framealpha=0.8)
ax.annotate("Note: 'alternating' and 'clustered' are identical in this sweep dataset",
            xy=(0.01, 0.97), xycoords="axes fraction",
            fontsize=7, color="#555555", va="top")
fig.tight_layout()
save(fig, "figC_placement_comparison")


# ── Fig D — bridle_angle sensitivity on φ (10 kW) ─────────────────────────────
print("Generating Fig D — bridle_angle sensitivity …")

df10 = df[df.power_kw == 10].copy()
agg_d = df10.groupby(["n_expansion", "bridle_angle_deg"])["phi_kg_per_kw"].mean().reset_index()

fig, ax = plt.subplots(figsize=(3.5, 2.8))

cmap = plt.cm.viridis
selected_nexp = [0, 2, 4]
for k, ne in enumerate(selected_nexp):
    sub = agg_d[agg_d.n_expansion == ne].sort_values("bridle_angle_deg")
    col = cmap(k / (len(selected_nexp) - 1))
    ax.plot(sub["bridle_angle_deg"], sub["phi_kg_per_kw"],
            color=col, marker="s", ms=4, lw=1.4,
            label=f"$n_{{\\mathrm{{exp}}}}={ne}$")

ax.set_xlabel("Bridle angle (°)")
ax.set_ylabel("φ  (kg kW⁻¹)")
ax.legend(framealpha=0.8)
ax.annotate("10 kW class — φ is constant w.r.t. bridle angle in this sweep\n"
            "(geometry not coupled to bridle_angle in parametric dataset)",
            xy=(0.01, 0.02), xycoords="axes fraction",
            fontsize=7, color="#555555")
fig.tight_layout()
save(fig, "figD_bridle_angle_sensitivity")


# ── Fig F — Cross-scale φ curves (x = power_kw, lines per n_expansion) ────────
print("Generating Fig F — cross-scale phi curves …")

agg_f = df.groupby(["power_kw", "n_expansion"])["phi_kg_per_kw"].mean().reset_index()

fig, ax = plt.subplots(figsize=(3.5, 2.8))

cmap_f = plt.cm.plasma
n_exps_all = sorted(agg_f.n_expansion.unique())
for k, ne in enumerate(n_exps_all):
    sub = agg_f[agg_f.n_expansion == ne].sort_values("power_kw")
    col = cmap_f(k / max(len(n_exps_all) - 1, 1))
    ax.plot(sub["power_kw"], sub["phi_kg_per_kw"],
            color=col, marker="o", ms=4, lw=1.4,
            label=f"$n_{{\\mathrm{{exp}}}}={ne}$")

ax.set_xscale("log")
ax.set_xticks([10, 20, 50])
ax.get_xaxis().set_major_formatter(ticker.ScalarFormatter())
ax.set_xlabel("Rated power (kW)")
ax.set_ylabel("φ  (kg kW⁻¹)")
ax.legend(framealpha=0.8, ncol=2)
ax.annotate("Parametric sweep — not DE-optimised",
            xy=(0.01, 0.97), xycoords="axes fraction",
            fontsize=7, color="#555555", va="top")
fig.tight_layout()
save(fig, "figF_cross_scale_phi")


# ── Fig G — v5 60-island mass histogram ───────────────────────────────────────
print("Generating Fig G — v5 island mass histogram …")

fig, ax = plt.subplots(figsize=(3.5, 2.8))

for cfg, col in [("10kw", POWER_COLORS[10]), ("50kw", POWER_COLORS[50])]:
    sub = v5_islands[v5_islands.cfg_name == cfg]["best_mass_kg"]
    ax.hist(sub, bins=15, color=col, alpha=0.7, edgecolor="white",
            lw=0.5, label=cfg.upper())

ax.set_xlabel("Shaft mass (kg)")
ax.set_ylabel("Island count")
ax.legend(framealpha=0.8)
ax.annotate("60 DE islands — tight convergence shows robust optimum",
            xy=(0.01, 0.97), xycoords="axes fraction",
            fontsize=7, color="#555555", va="top")
fig.tight_layout()
save(fig, "figG_v5_island_mass_histogram")


# ── Fig H — n_lines unanimity ─────────────────────────────────────────────────
print("Generating Fig H — n_lines unanimity …")

nlines_counts = v5_islands["n_lines"].value_counts().sort_index()

fig, ax = plt.subplots(figsize=(3.5, 2.4))

bars = ax.bar(nlines_counts.index.astype(str), nlines_counts.values,
              color="#1f77b4", alpha=0.85, edgecolor="white", lw=0.5)
for bar, val in zip(bars, nlines_counts.values):
    ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.5,
            str(val), ha="center", va="bottom", fontsize=8)

ax.set_xlabel("$n_\\mathrm{lines}$")
ax.set_ylabel("Islands (out of 60)")
ax.set_ylim(0, max(nlines_counts.values) * 1.15)
ax.annotate("100 % unanimity: every island converges to $n_\\mathrm{lines}=8$",
            xy=(0.01, 0.97), xycoords="axes fraction",
            fontsize=7, color="#555555", va="top")
fig.tight_layout()
save(fig, "figH_nlines_unanimity")


# ── Fig K — Campaign evolution ladder ─────────────────────────────────────────
print("Generating Fig K — campaign evolution ladder …")

# Values from DECISIONS.md and best_design files
campaigns = ["v3",    "v4",    "v5",    "v6\n(quick)"]
masses_10  = [15.435, 10.587, 11.470,  v6["best_mass_kg"]]

fig, ax = plt.subplots(figsize=(3.5, 2.8))

colors_k = ["#aec7e8", "#ffbb78", "#98df8a", "#d62728"]
bars = ax.bar(campaigns, masses_10, color=colors_k, edgecolor="white", lw=0.5, alpha=0.9)
for bar, val in zip(bars, masses_10):
    ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.15,
            f"{val:.2f} kg", ha="center", va="bottom", fontsize=7.5)

ax.set_ylabel("Best airborne shaft mass (kg) — 10 kW")
ax.set_ylim(0, max(masses_10) * 1.2)
ax.annotate("v3–v5: BEM-coupled DE; v6: expansion rotor (quick-mode, 100 iter)\n"
            "Full v6 50 kW campaign pending",
            xy=(0.01, 0.97), xycoords="axes fraction",
            fontsize=7, color="#555555", va="top")
fig.tight_layout()
save(fig, "figK_campaign_evolution")


print("\nDone — all figures written to", OUT)
