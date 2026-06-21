#!/usr/bin/env python3
"""V10 Parameter Pair Grid — 4×3 grid of real design variable vs design variable plots.
No PCA. Each panel: scatter density colored by mass, best trajectory, optimum marker."""

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from glob import glob
import os

OUT = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v10-parameter-pairs.png"
TRAJ_DIR = "/tmp"
BEST_ISLAND = 41

data = np.genfromtxt("/tmp/v10_atlas.csv", delimiter=',', names=True, dtype=None, encoding='utf-8')
# Remove infeasible (>200 kg) and clip outlier masses
mask = (data['mass'] < 200) & (data['mass'] > 10)
data = data[mask]

# Round discrete variables
n_lines_r = np.round(data['n_lines']).astype(int)
n_rotors_r = np.round(data['n_rotors']).astype(int)

mass = data['mass']
best_mass = mass.min()
print(f"Points: {len(data)}  Mass: {mass.min():.1f} - {mass.max():.1f} kg")

# ── Pair definitions: (x_var, y_var, x_label, y_label, x_ticks, y_ticks) ──
PAIRS = [
    # Row 1: Structural geometry
    ('n_lines', 'r_hub', 'n_lines', 'r_hub (m)',
     [3,6,8,10,12,14,16], None,
     'More lines → shorter polygon segments → higher Euler buckling resistance.\nThe optimum at n=12 balances structural benefit against solidity penalty.'),
    ('n_lines', 'r_bottom', 'n_lines', 'r_bottom (m)',
     [3,6,8,10,12,14,16], None,
     'Ground ring radius vs polygon count. Wide ground rings (r>2m)\nshare tether tension across a larger perimeter, satisfying FoS.'),
    ('n_lines', 'n_rotors', 'n_lines', 'n_rotors',
     [3,6,8,10,12,14,16], [0,1,2,3,4],
     'Tether FoS constraint drives designs toward fewer rotors.\nThe optimum uses a single rotor — each additional rotor adds\naxial thrust that must be carried by the tethers.'),

    # Row 2: Radial geometry
    ('r_hub', 'r_bottom', 'r_hub (m)', 'r_bottom (m)',
     None, None,
     'Hub vs ground ring radius. Diagonal line = cylindrical shaft.\nThe optimum is nearly cylindrical (3.7m / 3.7m) — taper provides\nno benefit under tether FoS constraint.'),
    ('r_hub', 'bank_top', 'r_hub (m)', 'Bank top rotor (°)',
     None, [0,10,20,30,35],
     'Hub radius vs bank angle. Steep bank (30-35°) dominates —\nrotors act as spreaders rather than thrust producers because\naxial thrust triggers the tether FoS constraint.'),
    ('r_hub', 'lambda_top', 'r_hub (m)', 'λ top rotor',
     None, None,
     'Hub radius vs blade scale. Larger hubs allow larger blades.\nThe optimum at λ≈0.23 uses moderate blades — enough for power\nwithout excessive tether tension.'),

    # Row 3: Rotor design trade-offs
    ('bank_top', 'lambda_top', 'Bank top rotor (°)', 'λ top rotor',
     [0,10,20,30,35], None,
     'The rotor design plane. λ×cos(bank) = useful blade area.\nSteep bank + small λ = useless rotor (penalized). The optimum\nbalances spreading (bank) against power production (λ).'),
    ('lambda_top', 'n_rotors', 'λ top rotor', 'n_rotors',
     None, [0,1,2,3,4],
     'Blade scale vs rotor count. With a single rotor, λ is free\nto optimize. Multiple rotors force smaller λ to stay under\ntether FoS — another reason the single-rotor design wins.'),
    ('bank_top', 'n_rotors', 'Bank top rotor (°)', 'n_rotors',
     [0,10,20,30,35], [0,1,2,3,4],
     'Bank angle vs rotor count. Single-rotor designs cluster at\nhigh bank (30-35°) — pure spreaders. Multiple rotors explore\nshallower banks but are eliminated by FoS constraint.'),

    # Row 4: Beam sizing
    ('n_lines', 't_over_D', 'n_lines', 't/D wall ratio',
     [3,6,8,10,12,14,16], None,
     'Wall thickness sits at the 0.01 manufacturing minimum across\nall polygon counts. The true optimum is below the fabrication\nfloor — thinner walls would save mass if manufacturable.'),
    ('n_lines', 'target_Lr', 'n_lines', 'target L/r',
     [3,6,8,10,12,14,16], [0.5,1.0,1.5,2.0,2.5,3.0],
     'Slenderness ratio vs polygon count. Designs cluster at L/r≈3.0\n(the upper bound) regardless of n_lines — fewer rings save beam\nmass but increase Euler buckling risk.'),
    ('r_hub', 'target_Lr', 'r_hub (m)', 'target L/r',
     None, [0.5,1.0,1.5,2.0,2.5,3.0],
     'Hub radius vs slenderness. High L/r (fewer rings) dominates\nacross all hub sizes. The L/r=3.0 bound screams — the true\noptimum likely has even fewer, longer segments.'),
]

# ── Load best trajectory for overlay ───────────────────────────────────────
best_traj = None
tf_best = f"{TRAJ_DIR}/v10_traj_{BEST_ISLAND}.txt"
if os.path.exists(tf_best):
    best_traj = np.loadtxt(tf_best)
    if best_traj.ndim == 1: best_traj = best_traj.reshape(1, -1)

# ── Render ─────────────────────────────────────────────────────────────────
plt.rcParams.update({
    'figure.facecolor': '#080810', 'axes.facecolor': '#0a0a14',
    'text.color': 'white', 'axes.edgecolor': '#333', 'axes.labelcolor': 'white',
    'xtick.labelsize': 5.5, 'xtick.color': '#777', 'ytick.labelsize': 5.5, 'ytick.color': '#777',
    'font.size': 7,
})

fig = plt.figure(figsize=(28, 32))
gs = fig.add_gridspec(5, 4, height_ratios=[1,1,1,1,0.04],
                      hspace=0.45, wspace=0.40,
                      left=0.05, right=0.95, top=0.96, bottom=0.03)

# Shared norm for mass coloring
mass_norm = Normalize(vmin=np.percentile(mass, 5), vmax=np.percentile(mass, 90))

for idx, (x_var, y_var, x_label, y_label, x_ticks, y_ticks, desc) in enumerate(PAIRS):
    row, col = idx // 3, idx % 3
    ax = fig.add_subplot(gs[row, col])

    x_vals = data[x_var] if x_var not in ('n_lines', 'n_rotors') else \
             (n_lines_r if x_var == 'n_lines' else n_rotors_r)
    y_vals = data[y_var] if y_var not in ('n_lines', 'n_rotors') else \
             (n_lines_r if y_var == 'n_lines' else n_rotors_r)

    # Scatter density — sample for performance
    n_pts = min(len(x_vals), 8000)
    idx_sample = np.random.choice(len(x_vals), n_pts, replace=False)
    sc = ax.scatter(x_vals[idx_sample], y_vals[idx_sample], c=mass[idx_sample],
                    cmap='viridis_r', norm=mass_norm, s=2, alpha=0.5, rasterized=True)

    # Best trajectory overlay — map via PCA nearest-neighbor
    if best_traj is not None:
        traj_x, traj_y = [], []
        for tp in best_traj[::5]:
            pc1_t, pc2_t = tp[0], tp[1]
            dists = (data['pc1'] - pc1_t)**2 + (data['pc2'] - pc2_t)**2
            nearest = np.argmin(dists)
            traj_x.append(float(x_vals[nearest]))
            traj_y.append(float(y_vals[nearest]))
        if len(traj_x) > 2:
            ax.plot(traj_x, traj_y, color='white', linewidth=1.2, alpha=0.7)
            ax.scatter(traj_x[0], traj_y[0], c='cyan', s=35, zorder=10, edgecolors='white', linewidths=0.6)
            ax.scatter(traj_x[-1], traj_y[-1], c='yellow', s=60, zorder=10, edgecolors='white', linewidths=1, marker='D')

    # Optimum marker
    best_idx = np.argmin(mass)
    ax.scatter(x_vals[best_idx], y_vals[best_idx], c='yellow', s=80, zorder=12,
               edgecolors='white', linewidths=1.5, marker='D')
    ax.annotate(f"{mass[best_idx]:.0f} kg", (x_vals[best_idx], y_vals[best_idx]),
                xytext=(5, 5), textcoords='offset points', color='yellow', fontsize=5.5, fontweight='bold')

    if x_ticks: ax.set_xticks(x_ticks)
    if y_ticks: ax.set_yticks(y_ticks)
    ax.set_xlabel(x_label, fontsize=6.5, color='#aaa')
    ax.set_ylabel(y_label, fontsize=6.5, color='#aaa')

    # Panel title
    title = f"{x_var.replace('_',' ')} vs {y_var.replace('_',' ')}".title()
    ax.set_title(title, fontsize=7.5, color='white', fontweight='bold', pad=2)

    # Description text box
    desc_lines = desc.strip().split('\n')
    desc_y = 0.94
    for line in desc_lines:
        ax.text(0.02, desc_y, line, transform=ax.transAxes, color='#888', fontsize=4.8,
                va='top', linespacing=1.3)
        desc_y -= 0.07

# ── Shared colorbar ────────────────────────────────────────────────────────
cbar_ax = fig.add_subplot(gs[4, 1:3])
sm = plt.cm.ScalarMappable(cmap='viridis_r', norm=mass_norm)
sm.set_array([])
cb = fig.colorbar(sm, cax=cbar_ax, orientation='horizontal')
cb.set_label('Best Mass (kg)  —  yellow = lower mass (better)', color='white', fontsize=8, labelpad=8)
cb.ax.tick_params(colors='white', labelsize=7)
cb.outline.set_edgecolor('#333')

# ── Master title ───────────────────────────────────────────────────────────
fig.suptitle("V10 Campaign — Physical Parameter Pair Grid\n12 design variable pairs, no PCA — each axis is a real engineering parameter",
             fontsize=16, fontweight='bold', color='white', y=0.99)
fig.text(0.5, 0.975, "White line = Island 41 trajectory  ·  Yellow diamond = global optimum (76.75 kg)  ·  97K feasible evaluations",
         fontsize=7.5, color='#888', ha='center')

plt.savefig(OUT, dpi=150, facecolor='#080810', bbox_inches='tight')
print(f"Saved: {OUT}")
