#!/usr/bin/env python3
"""V10 Parameter Atlas — 3×3 grid of PCA landscapes colored by each design variable."""
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from matplotlib.gridspec import GridSpec
from glob import glob
import os

OUT = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v10-parameter-atlas.png"
TRAJ_DIR = "/tmp"

# ── Load data ──────────────────────────────────────────────────────────────
data = np.genfromtxt("/tmp/v10_atlas.csv", delimiter=',', names=True,
                      dtype=None, encoding='utf-8')
print(f"Points: {len(data)}")
print(f"Mass range: {data['mass'].min():.1f} - {data['mass'].max():.1f} kg")

pc1 = data['pc1']; pc2 = data['pc2']

# Clip outliers — apply mask to entire structured array
q1, q99 = np.percentile(pc1, [1, 99])
q2_1, q2_99 = np.percentile(pc2, [1, 99])
mask = (pc1 > q1) & (pc1 < q99) & (pc2 > q2_1) & (pc2 < q2_99)
data = data[mask]
pc1 = data['pc1']; pc2 = data['pc2']

# ── Figure setup ───────────────────────────────────────────────────────────
plt.rcParams.update({
    'figure.facecolor': '#080810', 'axes.facecolor': '#080810',
    'text.color': 'white', 'axes.edgecolor': '#333', 'axes.labelcolor': 'white',
    'xtick.labelsize': 5, 'xtick.color': '#555', 'ytick.labelsize': 5, 'ytick.color': '#555',
    'font.size': 7,
})

fig = plt.figure(figsize=(30, 24))

# 3×3 grid of axes + colorbar slots
gs = GridSpec(4, 4, figure=fig, width_ratios=[1, 1, 1, 0.12],
              height_ratios=[1, 1, 1, 0.06], hspace=0.38, wspace=0.35,
              left=0.04, right=0.96, top=0.93, bottom=0.04)

# ── Panel definitions ──────────────────────────────────────────────────────
panels = [
    # (row, col, field, cmap, label, vmin_override, vmax_override)
    (0, 0, 'mass',     'viridis_r',  'Mass (kg)',              None, None),
    (0, 1, 'n_lines',  'plasma',     'n_lines (polygon sides)', 3,    16),
    (0, 2, 'n_rotors', 'magma',      'n_rotors (active)',      0,    4),
    (1, 0, 'r_hub',    'coolwarm',   'r_hub (m)',              None, None),
    (1, 1, 'r_bottom', 'coolwarm',   'r_bottom (m)',           None, None),
    (1, 2, 'bank_top', 'RdYlBu_r',   'Bank top rotor (°)',     0,    35),
    (2, 0, 'lambda_top','YlOrRd',    'λ top rotor (blade scale)', 0.03, 1.2),
    (2, 1, 't_over_D', 'cividis',    't/D (wall thickness ratio)', 0.005, 0.05),
    (2, 2, 'target_Lr','viridis',    'target L/r (slenderness)', 0.2,  3.0),
]

# Load trajectories once
traj_files = sorted(glob(f"{TRAJ_DIR}/v10_traj_*.txt"))
BEST_ISLAND = 41

# ── Master title ───────────────────────────────────────────────────────────
fig.suptitle("V10 Campaign — Parameter Atlas (PCA Landscape × 9 Variables)",
             fontsize=18, fontweight='bold', color='white', y=0.97)
fig.text(0.5, 0.955, "14-DoF DE optimisation, 60 islands, 310K evaluations — each panel shows the same PCA projection colored by a different design variable",
         fontsize=9, color='#888', ha='center')

# ── Draw each panel ────────────────────────────────────────────────────────
for (row, col, field, cmap, label, vmin_o, vmax_o) in panels:
    ax = fig.add_subplot(gs[row, col])

    vmin = vmin_o if vmin_o is not None else np.percentile(data[field][~np.isnan(data[field])], 2)
    vmax = vmax_o if vmax_o is not None else np.percentile(data[field][~np.isnan(data[field])], 98)

    # 2D histogram colored by this field
    H, xedges, yedges = np.histogram2d(pc1, pc2, bins=100, weights=data[field])
    Hc, _, _ = np.histogram2d(pc1, pc2, bins=100)
    with np.errstate(invalid='ignore', divide='ignore'):
        H_avg = np.divide(H, Hc, where=Hc > 0)

    im = ax.imshow(H_avg.T, origin='lower', aspect='auto',
                    extent=(float(pc1.min()), float(pc1.max()),
                            float(pc2.min()), float(pc2.max())),
                    cmap=cmap, norm=Normalize(vmin=vmin, vmax=vmax),
                    interpolation='bilinear')

    ax.set_xlim(pc1.min(), pc1.max())
    ax.set_ylim(pc2.min(), pc2.max())

    # Mass contour lines on every panel (subtle)
    if field != 'mass':
        Hm, _, _ = np.histogram2d(pc1, pc2, bins=100, weights=data['mass'])
        Hma = np.divide(Hm, Hc, where=Hc > 0)
        xc = (xedges[:-1] + xedges[1:]) / 2
        yc = (yedges[:-1] + yedges[1:]) / 2
        for lvl in [80, 100]:
            ax.contour(xc, yc, Hma.T, levels=[lvl], colors='white',
                       linewidths=0.3, alpha=0.3, linestyles='--')

    # Trajectories
    for tf in traj_files:
        island = int(os.path.basename(tf).replace("v10_traj_", "").replace(".txt", ""))
        tdata = np.loadtxt(tf)
        if tdata.ndim == 1: tdata = tdata.reshape(1, -1)
        if len(tdata) < 3: continue
        tm = (tdata[:, 0] > q1) & (tdata[:, 0] < q99) & (tdata[:, 1] > q2_1) & (tdata[:, 1] < q2_99)
        tdata = tdata[tm]
        if len(tdata) < 2: continue
        lw = 1.5 if island == BEST_ISLAND else 0.25
        alpha = 0.85 if island == BEST_ISLAND else 0.06
        color = '#ffffff' if island == BEST_ISLAND else '#ff6644'
        ax.plot(tdata[:, 0], tdata[:, 1], linewidth=lw, alpha=alpha, color=color)

    # Best trajectory markers
    if field == 'mass':
        tf_best = f"{TRAJ_DIR}/v10_traj_{BEST_ISLAND}.txt"
        if os.path.exists(tf_best):
            bd = np.loadtxt(tf_best)
            if bd.ndim == 1: bd = bd.reshape(1, -1)
            bm_b = (bd[:, 0] > q1) & (bd[:, 0] < q99) & (bd[:, 1] > q2_1) & (bd[:, 1] < q2_99)
            bd = bd[bm_b]
            if len(bd) > 1:
                ax.scatter(bd[0, 0], bd[0, 1], c='cyan', s=40, zorder=10, edgecolors='white', linewidths=0.8)
                ax.scatter(bd[-1, 0], bd[-1, 1], c='yellow', s=70, zorder=10, edgecolors='white', linewidths=1.2, marker='D')
                ax.annotate("76.75 kg", (bd[-1, 0], bd[-1, 1]), xytext=(8, 8),
                           textcoords='offset points', color='yellow', fontsize=5.5, fontweight='bold')

    # Colorbar
    cbar_ax = fig.add_subplot(gs[row, 3])
    cb = fig.colorbar(im, cax=cbar_ax, orientation='vertical')
    cb.set_label(label, color='white', fontsize=6, labelpad=2)
    cb.ax.tick_params(labelsize=5, colors='white')
    cb.outline.set_edgecolor('#333')

    # Axis labels (only on edge panels)
    if row == 2:
        ax.set_xlabel("PC1 →", fontsize=6, color='#888')
    if col == 0:
        ax.set_ylabel("PC2 →", fontsize=6, color='#888')

    # Panel title
    ax.set_title(field.replace('_', ' ').title(), fontsize=8, color='white',
                 fontweight='bold', pad=3)

    # Tick cleanup
    ax.tick_params(which='both', length=2)

# ── Bottom annotation strip ─────────────────────────────────────────────────
bottom_ax = fig.add_subplot(gs[3, :3])
bottom_ax.set_xlim(0, 1); bottom_ax.set_ylim(0, 1); bottom_ax.axis('off')
bottom_ax.text(0.5, 0.6, "Each panel = same 97K-point PCA landscape, colored by a different design variable.",
               transform=bottom_ax.transAxes, ha='center', color='#888', fontsize=7)
bottom_ax.text(0.5, 0.2, "White line = Island 41 best trajectory. Orange spiderwebs = all 60 island paths. Dashed contours = iso-mass lines.",
               transform=bottom_ax.transAxes, ha='center', color='#666', fontsize=6)

plt.savefig(OUT, dpi=150, facecolor='#080810', bbox_inches='tight')
print(f"Saved: {OUT}")
