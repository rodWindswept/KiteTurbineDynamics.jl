#!/usr/bin/env python3
"""Render V10 parameter-space landscape with matplotlib — fully labeled."""
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Circle
from matplotlib.colors import Normalize
from glob import glob
import os

OUT = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v10-landscape.png"

# ── Load density data ──────────────────────────────────────────────────────
pc1 = np.loadtxt("/tmp/v10_pc1.txt")
pc2 = np.loadtxt("/tmp/v10_pc2.txt")
mass = np.loadtxt("/tmp/v10_mass.txt")

print(f"Points: {len(pc1)}")
print(f"Mass range: {mass.min():.1f} - {mass.max():.1f} kg")

# Clip outliers
q1, q99 = np.percentile(pc1, [1, 99])
q2_1, q2_99 = np.percentile(pc2, [1, 99])
mask = (pc1 > q1) & (pc1 < q99) & (pc2 > q2_1) & (pc2 < q2_99)
pc1, pc2, mass = pc1[mask], pc2[mask], mass[mask]

# ── Figure setup ───────────────────────────────────────────────────────────
plt.rcParams.update({
    'figure.facecolor': '#0a0a0f',
    'axes.facecolor': '#0a0a0f',
    'text.color': 'white',
    'axes.edgecolor': '#444',
    'axes.labelcolor': 'white',
    'xtick.labelsize': 7, 'xtick.color': '#888',
    'ytick.labelsize': 7, 'ytick.color': '#888',
    'grid.color': '#222',
    'figure.dpi': 150,
})

fig = plt.figure(figsize=(24, 16))
gs = fig.add_gridspec(2, 3, width_ratios=[3, 1, 1], height_ratios=[4, 1],
                      left=0.06, right=0.94, top=0.92, bottom=0.08,
                      hspace=0.35, wspace=0.30)

ax_main = fig.add_subplot(gs[0, 0])    # Main density landscape
ax_legend = fig.add_subplot(gs[0, 1])  # Colorbar + legend
ax_pc1 = fig.add_subplot(gs[0, 2])     # PC1 interpretation
ax_pc2 = fig.add_subplot(gs[1, 1:])    # PC2 interpretation
ax_journey = fig.add_subplot(gs[1, 0]) # Journey summary

# ── Main panel: 2D histogram via imshow ────────────────────────────────────
H, xedges, yedges = np.histogram2d(pc1, pc2, bins=120, weights=mass)
H_counts, _, _ = np.histogram2d(pc1, pc2, bins=120)
with np.errstate(invalid='ignore'):
    H_avg = np.divide(H, H_counts, where=H_counts>0)

# Use percentile-based normalization — clip top 20% to make low-mass region visible
vmax_clip = np.percentile(mass, 85)  # clip top 15% to highlight the interesting region
im = ax_main.imshow(H_avg.T, origin='lower', aspect='auto',
                     extent=(float(pc1.min()), float(pc1.max()), float(pc2.min()), float(pc2.max())),
                     cmap='viridis_r', norm=Normalize(vmin=mass.min(), vmax=vmax_clip),
                     interpolation='bilinear')
ax_main.set_xlim(pc1.min(), pc1.max())
ax_main.set_ylim(pc2.min(), pc2.max())

# Contour lines at key mass levels
x_centers = (xedges[:-1] + xedges[1:]) / 2
y_centers = (yedges[:-1] + yedges[1:]) / 2
contour_levels = [78, 80, 82, 84, 90, 100]
for level in contour_levels:
    lw = 0.8 if level == 90 else 0.4
    alpha_c = 0.8 if level == 90 else 0.5
    ax_main.contour(x_centers, y_centers, H_avg.T, levels=[level],
                    colors='white', linewidths=lw, alpha=alpha_c, linestyles='-')
# Simple text labels for contour levels at fixed positions
for level, pos in [(90, (0.1, 0.92)), (100, (0.88, 0.85)), (120, (0.9, 0.15))]:
    ax_main.annotate(f'{level} kg', pos, xycoords='axes fraction',
                    color='white', fontsize=8, alpha=0.85, fontweight='bold',
                    bbox=dict(boxstyle='round,pad=0.2', facecolor='black', alpha=0.4, edgecolor='none'))
ax_main.set_xlabel("PC1 — Structural Scale\n(r_hub, D_top, t/D, λ → larger structure → +PC1)",
                   fontsize=9, labelpad=8)
ax_main.set_ylabel("PC2 — Configuration Choice\n(L_r, rotors, bank → expansion-dominant → +PC2)",
                   fontsize=9, labelpad=8)

# ── Trajectories overlay ───────────────────────────────────────────────────
traj_files = sorted(glob("/tmp/v10_traj_*.txt"))
colors = plt.colormaps['plasma'](np.linspace(0.1, 0.9, len(traj_files)))

best_island = 41
best_traj = None

for i, tf in enumerate(traj_files):
    island = int(os.path.basename(tf).replace("v10_traj_", "").replace(".txt", ""))
    data = np.loadtxt(tf)
    if data.ndim == 1: data = data.reshape(1, -1)
    if len(data) < 3: continue

    mask = (data[:, 0] > q1) & (data[:, 0] < q99) & (data[:, 1] > q2_1) & (data[:, 1] < q2_99)
    data = data[mask]
    if len(data) < 2: continue

    lw = 1.8 if island == best_island else 0.3
    alpha = 0.9 if island == best_island else 0.08
    color = '#ffffff' if island == best_island else colors[i % len(colors)]

    ax_main.plot(data[:, 0], data[:, 1], linewidth=lw, alpha=alpha, color=color)

    if island == best_island:
        best_traj = data
        ax_main.scatter(data[0, 0], data[0, 1], c='cyan', s=60, zorder=10,
                        edgecolors='white', linewidths=1)
        ax_main.scatter(data[-1, 0], data[-1, 1], c='yellow', s=100, zorder=10,
                        edgecolors='white', linewidths=1.5, marker='D')
        ax_main.annotate("76.75 kg", (data[-1, 0], data[-1, 1]),
                         xytext=(15, 15), textcoords='offset points',
                         color='yellow', fontsize=8, fontweight='bold')

# ── Colorbar ───────────────────────────────────────────────────────────────
cbar = fig.colorbar(im, ax=ax_legend, orientation='vertical', shrink=0.8)
cbar.set_label("Best Mass (kg)", color='white', fontsize=10)
cbar.ax.yaxis.set_tick_params(color='white')
cbar.outline.set_edgecolor('#444')
plt.setp(cbar.ax.yaxis.get_ticklabels(), color='white', fontsize=8)

ax_legend.text(0.5, 0.95, "Color = Mass", transform=ax_legend.transAxes,
               color='white', fontsize=9, ha='center', fontweight='bold')
ax_legend.text(0.5, 0.07, "Yellow = lower mass\n(better design)",
               transform=ax_legend.transAxes, color='#aaa', fontsize=7, ha='center')
ax_legend.axis('off')

# ── PC1 Interpretation inset ───────────────────────────────────────────────
ax_pc1.set_xlim(0, 1); ax_pc1.set_ylim(0, 1); ax_pc1.axis('off')
ax_pc1.text(0.5, 0.95, "PC1: STRUCTURAL SCALE", transform=ax_pc1.transAxes,
            color='white', fontsize=10, ha='center', fontweight='bold')
items_pc1 = [
    ("+ PC1 →", "Larger r_hub, D_top, t/D, λ"),
    ("", "= bigger beams, heavier shaft"),
    ("− PC1 ←", "Smaller, lighter structure"),
    ("", "= lower mass potential"),
]
for i, (bold, text) in enumerate(items_pc1):
    y = 0.78 - i * 0.15
    if bold:
        ax_pc1.text(0.1, y, bold, transform=ax_pc1.transAxes,
                    color='#4fc3f7', fontsize=9, fontweight='bold')
    ax_pc1.text(0.45, y, text, transform=ax_pc1.transAxes,
                color='#bbb', fontsize=8)

# ── PC2 Interpretation inset ───────────────────────────────────────────────
ax_pc2.set_xlim(0, 1); ax_pc2.set_ylim(0, 1); ax_pc2.axis('off')
items_pc2 = [
    ("+ PC2 ↑", "Higher target_Lr, more rotors, steeper bank"),
    ("", "= expansion-dominant configuration"),
    ("", "spreading forces dominate"),
    ("− PC2 ↓", "Compact, few rotors, shallow bank"),
    ("", "= thrust-dominant configuration"),
    ("", "axial power dominates"),
]
for i, (bold, text) in enumerate(items_pc2):
    y = 0.85 - i * 0.12
    if bold:
        ax_pc2.text(0.05, y, bold, transform=ax_pc2.transAxes,
                    color='#4fc3f7' if '↑' in bold else '#ff8a65',
                    fontsize=9, fontweight='bold')
    ax_pc2.text(0.38, y, text, transform=ax_pc2.transAxes,
                color='#bbb', fontsize=8)

# ── Journey summary ────────────────────────────────────────────────────────
ax_journey.set_xlim(0, 1); ax_journey.set_ylim(0, 1); ax_journey.axis('off')
ax_journey.text(0.5, 0.92, "JOURNEY: ISLAND 41 → 76.75 kg", transform=ax_journey.transAxes,
                color='white', fontsize=10, ha='center', fontweight='bold')
journey_items = [
    "310,000 evaluations across 60 islands",
    "PCA captures 33% of 14-D variance",
    "PC1: structural scale (20.7% var)",
    "PC2: configuration choice (12.5% var)",
    "8 constraint gates + power accuracy",
]
for i, item in enumerate(journey_items):
    ax_journey.text(0.5, 0.75 - i * 0.13, item, transform=ax_journey.transAxes,
                    color='#888', fontsize=8, ha='center')

# ── Title ──────────────────────────────────────────────────────────────────
fig.suptitle("V10 Campaign — Parameter-Space Optimisation Landscape",
             fontsize=16, fontweight='bold', color='white', y=0.97)
fig.text(0.5, 0.94, "14-DoF DE optimisation, 60 islands, power-accuracy objective — PCA projection",
         fontsize=9, color='#888', ha='center')

plt.savefig(OUT, dpi=150, facecolor='#0a0a0f', bbox_inches='tight')
print(f"Saved: {OUT}")
