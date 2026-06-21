#!/usr/bin/env python3
"""V10 Tight campaign — parameter-space landscape."""
import numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize

OUT = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v10-tight-landscape.png"

pc1 = np.loadtxt("/tmp/v10_tight_pc1.txt")
pc2 = np.loadtxt("/tmp/v10_tight_pc2.txt")
mass = np.loadtxt("/tmp/v10_tight_mass.txt")

q1, q99 = np.percentile(pc1, [1,99]); q2_1, q2_99 = np.percentile(pc2, [1,99])
mask = (pc1 > q1) & (pc1 < q99) & (pc2 > q2_1) & (pc2 < q2_99)
pc1, pc2, mass = pc1[mask], pc2[mask], mass[mask]

plt.rcParams.update({
    'figure.facecolor': '#080810', 'axes.facecolor': '#080810',
    'text.color': 'white', 'axes.edgecolor': '#333', 'axes.labelcolor': 'white',
    'xtick.labelsize': 7, 'xtick.color': '#555', 'ytick.labelsize': 7, 'ytick.color': '#555',
})
fig, ax = plt.subplots(figsize=(18, 12))

H, xe, ye = np.histogram2d(pc1, pc2, bins=80, weights=mass)
Hc, _, _ = np.histogram2d(pc1, pc2, bins=80)
with np.errstate(invalid='ignore', divide='ignore'):
    Havg = np.divide(H, Hc, where=Hc > 0)

vmax = np.percentile(mass, 90)
im = ax.imshow(Havg.T, origin='lower', aspect='auto',
    extent=(pc1.min(), pc1.max(), pc2.min(), pc2.max()),
    cmap='viridis_r', norm=Normalize(vmin=mass.min(), vmax=vmax), interpolation='bilinear')

xc = (xe[:-1]+xe[1:])/2; yc = (ye[:-1]+ye[1:])/2
for lvl in [49.5, 55, 65, 80]:
    ax.contour(xc, yc, Havg.T, levels=[lvl], colors='white', linewidths=0.5, alpha=0.4, linestyles='--')

# Mark best point
best = mass.argmin()
ax.scatter(pc1[best], pc2[best], c='yellow', s=150, zorder=10, edgecolors='white', linewidths=2, marker='D')
ax.annotate(f'49.2 kg\n4 rotors, 59 rpm', (pc1[best], pc2[best]),
    xytext=(20, 20), textcoords='offset points', color='yellow', fontsize=10, fontweight='bold')

ax.set_xlabel("PC1 — $(28.9)% var", fontsize=10, color='#888')
ax.set_ylabel("PC2 — $(20.4)% var", fontsize=10, color='#888')
ax.set_title("V10 Tight Campaign — Parameter-Space Landscape\n12 islands, tight bounds, k_mppt ∝ λ² scaling", fontsize=14, color='white', fontweight='bold')

cbar = fig.colorbar(im, ax=ax, shrink=0.8)
cbar.set_label("Mass (kg)", color='white', fontsize=10)
cbar.ax.tick_params(colors='white')

plt.savefig(OUT, dpi=150, facecolor='#080810', bbox_inches='tight')
print(f"Saved: {OUT}")
