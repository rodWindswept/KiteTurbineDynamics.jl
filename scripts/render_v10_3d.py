#!/usr/bin/env python3
"""V10 3D Mass Landscape — PC1×PC2 surface with mass as height, Island 41 trajectory ribbon."""

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize, LightSource
from mpl_toolkits.mplot3d import Axes3D
from glob import glob
import os

OUT = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams/v10-3d-landscape.png"
TRAJ_DIR = "/tmp"
BEST_ISLAND = 41

data = np.genfromtxt("/tmp/v10_atlas.csv", delimiter=',', names=True, dtype=None, encoding='utf-8')
mask = (data['mass'] < 200) & (data['mass'] > 10)
data = data[mask]

pc1 = data['pc1']; pc2 = data['pc2']; mass = data['mass']
q1, q99 = np.percentile(pc1, [1, 99])
q2_1, q2_99 = np.percentile(pc2, [1, 99])
mask = (pc1 > q1) & (pc1 < q99) & (pc2 > q2_1) & (pc2 < q2_99)
pc1, pc2, mass = pc1[mask], pc2[mask], mass[mask]

# Build surface grid
GRID = 80
H, xedges, yedges = np.histogram2d(pc1, pc2, bins=GRID, weights=mass)
Hc, _, _ = np.histogram2d(pc1, pc2, bins=GRID)
with np.errstate(invalid='ignore', divide='ignore'):
    H_avg = np.divide(H, Hc, where=Hc > 0)

xc = (xedges[:-1] + xedges[1:]) / 2
yc = (yedges[:-1] + yedges[1:]) / 2
X, Y = np.meshgrid(xc, yc)
Z = H_avg.T

# Simple 3x3 smooth (no scipy dependency)
Z_smooth = np.zeros_like(Z)
for i in range(1, Z.shape[0]-1):
    for j in range(1, Z.shape[1]-1):
        window = Z[i-1:i+2, j-1:j+2]
        valid = window[~np.isnan(window)]
        Z_smooth[i,j] = np.median(valid) if len(valid) >= 4 else Z[i,j]
# Fill edges
Z_smooth[0,:] = Z[0,:]; Z_smooth[-1,:] = Z[-1,:]
Z_smooth[:,0] = Z[:,0]; Z_smooth[:,-1] = Z[:,-1]

# Clip for visualization
z_clip = np.percentile(mass, 95)
Z_plot = np.clip(Z_smooth, 0, z_clip)

# Load trajectory
best_traj = None
tf = f"{TRAJ_DIR}/v10_traj_{BEST_ISLAND}.txt"
if os.path.exists(tf):
    best_traj = np.loadtxt(tf)
    if best_traj.ndim == 1: best_traj = best_traj.reshape(1, -1)
    # Filter outliers
    tm = (best_traj[:,0] > q1) & (best_traj[:,0] < q99) & (best_traj[:,1] > q2_1) & (best_traj[:,1] < q2_99)
    best_traj = best_traj[tm]

# ── Render ─────────────────────────────────────────────────────────────────
plt.rcParams.update({
    'figure.facecolor': '#080810', 'text.color': 'white', 'font.size': 8,
})

fig = plt.figure(figsize=(22, 16))
ax = fig.add_subplot(111, projection='3d')
ax.set_facecolor('#080810')

# Surface
norm = Normalize(vmin=np.percentile(mass, 2), vmax=z_clip)
surf = ax.plot_surface(X, Y, Z_plot, cmap='viridis_r', norm=norm,
                        edgecolor='none', alpha=0.9, antialiased=True,
                        linewidth=0, rcount=80, ccount=80)

# Trajectory ribbon
if best_traj is not None and len(best_traj) > 5:
    # Subsample
    step = max(1, len(best_traj) // 150)
    traj = best_traj[::step]
    # Interpolate z from the surface grid
    traj_z = []
    for pt in traj:
        ix = np.searchsorted(xc, pt[0])
        iy = np.searchsorted(yc, pt[1])
        ix = min(max(ix, 0), GRID-2)
        iy = min(max(iy, 0), GRID-2)
        z_val = np.mean(Z_smooth[iy:iy+2, ix:ix+2])
        traj_z.append(z_val)
    traj_z = np.array(traj_z)

    ax.plot(traj[:,0], traj[:,1], traj_z + 2,  # slightly above surface
            color='white', linewidth=2.5, alpha=0.9, zorder=10)
    ax.plot(traj[:,0], traj[:,1], np.full_like(traj_z, Z_plot.min() - 5),
            color='white', linewidth=0.5, alpha=0.3, linestyle=':')

    # Drop lines from trajectory to floor
    for i in range(0, len(traj), max(1, len(traj)//20)):
        ax.plot([traj[i,0], traj[i,0]], [traj[i,1], traj[i,1]],
                [Z_plot.min()-5, traj_z[i]+2],
                color='white', linewidth=0.3, alpha=0.15)

    # Start marker
    ax.scatter(traj[0,0], traj[0,1], traj_z[0]+3, c='cyan', s=80, zorder=20, edgecolors='white', linewidths=1.5)
    # End marker
    ax.scatter(traj[-1,0], traj[-1,1], traj_z[-1]+3, c='yellow', s=120, zorder=20, edgecolors='white', linewidths=2, marker='D')

# Optimum location (lowest mass point)
best_idx = np.argmin(mass)
ax.scatter(pc1[best_idx], pc2[best_idx], mass[best_idx]+3, c='yellow', s=150, zorder=25,
           edgecolors='white', linewidths=2, marker='D')

# Labels
ax.set_xlabel('PC1 — Structural Scale →', color='#aaa', fontsize=9, labelpad=10)
ax.set_ylabel('PC2 — Configuration →', color='#aaa', fontsize=9, labelpad=10)
ax.set_zlabel('Mass (kg)', color='#aaa', fontsize=9, labelpad=10)

# View angle
ax.view_init(elev=25, azim=-55)

# Lighting
ax.xaxis.set_pane_color((0.08, 0.08, 0.12, 0.5))
ax.yaxis.set_pane_color((0.08, 0.08, 0.12, 0.5))
ax.zaxis.set_pane_color((0.08, 0.08, 0.12, 0.5))
ax.grid(color='#222', linewidth=0.3)
ax.tick_params(colors='#777', labelsize=6)

# Colorbar
cbar = fig.colorbar(surf, ax=ax, shrink=0.5, aspect=20, pad=0.1)
cbar.set_label('Best Mass (kg)  —  yellow = lower', color='white', fontsize=8)
cbar.ax.tick_params(colors='white', labelsize=7)
cbar.outline.set_edgecolor('#444')

# Title
fig.suptitle("V10 Campaign — 3D Mass Optimisation Landscape",
             fontsize=16, fontweight='bold', color='white', y=0.97)
fig.text(0.5, 0.94, "PC1 × PC2 PCA projection  ·  Mass as height  ·  Island 41 trajectory (white)  ·  Drop-lines to valley floor",
         fontsize=8, color='#888', ha='center')

plt.savefig(OUT, dpi=150, facecolor='#080810', bbox_inches='tight')
print(f"Saved: {OUT}")
