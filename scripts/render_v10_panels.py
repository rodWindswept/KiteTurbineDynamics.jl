#!/usr/bin/env python3
"""Render each of the 9 V10 parameter landscape panels as standalone publication figures."""
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from glob import glob
import os

OUT_DIR = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams"
TRAJ_DIR = "/tmp"
BEST_ISLAND = 41

# ── Load data once ─────────────────────────────────────────────────────────
data = np.genfromtxt(f"{TRAJ_DIR}/v10_atlas.csv", delimiter=',', names=True, dtype=None, encoding='utf-8')
q1, q99 = np.percentile(data['pc1'], [1, 99])
q2_1, q2_99 = np.percentile(data['pc2'], [1, 99])
mask = (data['pc1'] > q1) & (data['pc1'] < q99) & (data['pc2'] > q2_1) & (data['pc2'] < q2_99)
data = data[mask]
pc1 = data['pc1']; pc2 = data['pc2']

traj_files = sorted(glob(f"{TRAJ_DIR}/v10_traj_*.txt"))
colors_traj = plt.colormaps['plasma'](np.linspace(0.1, 0.9, len(traj_files)))

# ── Panel definitions ──────────────────────────────────────────────────────
PANELS = [
    ('mass',      'viridis_r',  'Best Mass (kg)',             None, None,
     'The objective function landscape. Yellow valleys are low-mass designs (<80 kg);\npurple peaks are heavy designs (>100 kg). Island 41 navigated from the\nbottom-right to the top-left yellow basin.'),
    ('n_lines',   'plasma',     'Polygon Lines (n)',          3,    16,
     'Number of tether lines forming the TRPT polygon. Dark = few lines (triangle/hexagon);\nbright = many lines (dodecagon+). The optimum sits at n=12 — more lines distribute\ntether tension, reducing the load per line and satisfying the FoS constraint.'),
    ('n_rotors',  'magma',      'Active Rotors',              0,    4,
     'Number of active expansion rotors on the shaft. Dark = zero rotors (hub only);\nbright = full 4-rotor complement. The optimum uses 1 rotor — the tether FoS\nconstraint discourages multiple rotors, each of which adds axial thrust.'),
    ('r_hub',     'coolwarm',   'Hub Radius (m)',             None, None,
     'Hub ring radius — the widest point of the TRPT. Blue = narrow hub (<2 m);\nred = wide hub (>4 m). A wider hub provides more leverage for radial spreading\nbut adds beam mass. The optimum sits at 3.7 m.'),
    ('r_bottom',  'coolwarm',   'Ground Ring Radius (m)',     None, None,
     'Ground ring radius at the PTO end. Blue = narrow ground ring; red = wide.\nThe tether FoS constraint drove r_bottom up to 3.7 m — nearly cylindrical,\nbecause wider rings share tether tension across a larger perimeter.'),
    ('bank_top',  'RdYlBu_r',   'Bank Angle Top Rotor (°)',   0,    35,
     'Bank angle of the topmost rotor. Blue = shallow bank (axial thrust);\nred = steep bank (radial spreading). The optimum settled near 35° — almost\npure spreading — because thrust triggers the tether FoS constraint.'),
    ('lambda_top','YlOrRd',     'Blade Scale λ (top rotor)',  0.03, 1.2,
     'Blade scale factor for the top rotor — ratio of blade tip radius to BEM\nrotor radius. Dark = small blades (<0.1); bright = large blades (>0.5).\nThe optimum uses λ≈0.23 — moderate blades balancing thrust and mass.'),
    ('t_over_D',  'cividis',    'Wall Thickness Ratio t/D',   0.005, 0.05,
     'Beam wall thickness divided by outer diameter. Dark = thin walls; bright =\nthick walls. Shown at 2× vertical exaggeration to reveal the topography.\nNearly all designs sit at the 0.01 manufacturing minimum — the true optimum\nis below the fabrication floor. This bound screams.'),
    ('target_Lr', 'viridis',    'Slenderness Ratio L/r',      0.2,  3.0,
     'Target segment length-to-radius ratio — controls ring spacing density.\nDark = sparse rings; bright = dense rings. The optimum uses L/r≈3.0, the\nmaximum allowed — fewer rings save beam mass but increase Euler buckling risk.\nThis bound also screams.'),
]

# ── Render each panel ──────────────────────────────────────────────────────
plt.rcParams.update({
    'figure.facecolor': '#080810', 'axes.facecolor': '#080810',
    'text.color': 'white', 'axes.edgecolor': '#444', 'axes.labelcolor': 'white',
    'xtick.labelsize': 7, 'xtick.color': '#888', 'ytick.labelsize': 7, 'ytick.color': '#888',
    'font.size': 8,
})

for field, cmap, label, vmin_o, vmax_o, description in PANELS:
    print(f"  Rendering {field}...")
    fig = plt.figure(figsize=(24, 18))

    gs = fig.add_gridspec(2, 3, width_ratios=[3, 1, 1], height_ratios=[4, 1],
                          left=0.06, right=0.94, top=0.92, bottom=0.08,
                          hspace=0.35, wspace=0.30)

    ax_main = fig.add_subplot(gs[0, 0])
    ax_legend = fig.add_subplot(gs[0, 1])
    ax_pc1 = fig.add_subplot(gs[0, 2])
    ax_pc2 = fig.add_subplot(gs[1, 1:])
    ax_journey = fig.add_subplot(gs[1, 0])

    # ── Main landscape ─────────────────────────────────────────────────
    vmin = vmin_o if vmin_o is not None else np.percentile(data[field][~np.isnan(data[field])], 2)
    vmax = vmax_o if vmax_o is not None else np.percentile(data[field][~np.isnan(data[field])], 98)
    if field == 't_over_D':
        vmax = min(vmax * 2.0, 0.10)  # stretch to reveal t/D topography

    H, xedges, yedges = np.histogram2d(pc1, pc2, bins=120, weights=data[field])
    Hc, _, _ = np.histogram2d(pc1, pc2, bins=120)
    with np.errstate(invalid='ignore', divide='ignore'):
        H_avg = np.divide(H, Hc, where=Hc > 0)

    im = ax_main.imshow(H_avg.T, origin='lower', aspect='auto',
                         extent=(float(pc1.min()), float(pc1.max()),
                                 float(pc2.min()), float(pc2.max())),
                         cmap=cmap, norm=Normalize(vmin=vmin, vmax=vmax),
                         interpolation='bilinear')
    ax_main.set_xlim(pc1.min(), pc1.max())
    ax_main.set_ylim(pc2.min(), pc2.max())

    # Mass contour lines (subtle)
    if field != 'mass':
        Hm, _, _ = np.histogram2d(pc1, pc2, bins=120, weights=data['mass'])
        Hma = np.divide(Hm, Hc, where=Hc > 0)
        xc = (xedges[:-1] + xedges[1:]) / 2; yc = (yedges[:-1] + yedges[1:]) / 2
        for lvl in [80, 100]:
            ax_main.contour(xc, yc, Hma.T, levels=[lvl], colors='white',
                           linewidths=0.4, alpha=0.35, linestyles='--')
    else:
        xc = (xedges[:-1] + xedges[1:]) / 2; yc = (yedges[:-1] + yedges[1:]) / 2
        for lvl in [80, 90, 100]:
            lw = 0.8 if lvl == 90 else 0.3
            alpha_c = 0.7 if lvl == 90 else 0.35
            ax_main.contour(xc, yc, H_avg.T, levels=[lvl], colors='white',
                           linewidths=lw, alpha=alpha_c, linestyles='-')

    # Trajectories
    for i, tf in enumerate(traj_files):
        island = int(os.path.basename(tf).replace("v10_traj_", "").replace(".txt", ""))
        tdata = np.loadtxt(tf)
        if tdata.ndim == 1: tdata = tdata.reshape(1, -1)
        if len(tdata) < 3: continue
        tm = (tdata[:, 0] > q1) & (tdata[:, 0] < q99) & (tdata[:, 1] > q2_1) & (tdata[:, 1] < q2_99)
        tdata = tdata[tm]
        if len(tdata) < 2: continue
        lw = 1.8 if island == BEST_ISLAND else 0.3
        alpha = 0.9 if island == BEST_ISLAND else 0.08
        color = '#ffffff' if island == BEST_ISLAND else colors_traj[i % len(colors_traj)]
        ax_main.plot(tdata[:, 0], tdata[:, 1], linewidth=lw, alpha=alpha, color=color)

    # Best markers
    tf_best = f"{TRAJ_DIR}/v10_traj_{BEST_ISLAND}.txt"
    if os.path.exists(tf_best):
        bd = np.loadtxt(tf_best)
        if bd.ndim == 1: bd = bd.reshape(1, -1)
        bm = (bd[:, 0] > q1) & (bd[:, 0] < q99) & (bd[:, 1] > q2_1) & (bd[:, 1] < q2_99)
        bd = bd[bm]
        if len(bd) > 1:
            ax_main.scatter(bd[0,0], bd[0,1], c='cyan', s=60, zorder=10, edgecolors='white', linewidths=1)
            ax_main.scatter(bd[-1,0], bd[-1,1], c='yellow', s=100, zorder=10, edgecolors='white', linewidths=1.5, marker='D')
            ax_main.annotate("76.75 kg", (bd[-1,0], bd[-1,1]), xytext=(12, 12),
                           textcoords='offset points', color='yellow', fontsize=9, fontweight='bold')

    ax_main.set_xlabel("PC1 — Structural Scale\n(r_hub, D_top, t/D, λ → larger structure → +PC1)", fontsize=9, labelpad=8)
    ax_main.set_ylabel("PC2 — Configuration Choice\n(L_r, rotors, bank → expansion-dominant → +PC2)", fontsize=9, labelpad=8)

    # ── Colorbar ────────────────────────────────────────────────────────
    cbar = fig.colorbar(im, ax=ax_legend, orientation='vertical', shrink=0.8)
    cbar.set_label(label, color='white', fontsize=10)
    cbar.ax.yaxis.set_tick_params(color='white')
    cbar.outline.set_edgecolor('#444')
    plt.setp(cbar.ax.yaxis.get_ticklabels(), color='white', fontsize=8)
    ax_legend.text(0.5, 0.95, field.replace('_', ' ').title(), transform=ax_legend.transAxes,
                   color='white', fontsize=10, ha='center', fontweight='bold')
    ax_legend.axis('off')

    # ── PC1 interpretation ──────────────────────────────────────────────
    ax_pc1.set_xlim(0, 1); ax_pc1.set_ylim(0, 1); ax_pc1.axis('off')
    ax_pc1.text(0.5, 0.95, "PC1: STRUCTURAL SCALE", transform=ax_pc1.transAxes,
                color='white', fontsize=10, ha='center', fontweight='bold')
    for i, (bold, text) in enumerate([
        ("+ PC1 →", "Larger r_hub, D_top, t/D, λ"),
        ("", "= bigger beams, heavier shaft"),
        ("− PC1 ←", "Smaller, lighter structure"),
        ("", "= lower mass potential"),
    ]):
        y = 0.78 - i * 0.15
        if bold: ax_pc1.text(0.1, y, bold, transform=ax_pc1.transAxes, color='#4fc3f7', fontsize=9, fontweight='bold')
        ax_pc1.text(0.45, y, text, transform=ax_pc1.transAxes, color='#bbb', fontsize=8)

    # ── PC2 interpretation ──────────────────────────────────────────────
    ax_pc2.set_xlim(0, 1); ax_pc2.set_ylim(0, 1); ax_pc2.axis('off')
    for i, (bold, text) in enumerate([
        ("+ PC2 ↑", "Higher target_Lr, more rotors, steeper bank"),
        ("", "= expansion-dominant, spreading forces dominate"),
        ("− PC2 ↓", "Compact, few rotors, shallow bank"),
        ("", "= thrust-dominant, axial power dominates"),
    ]):
        y = 0.85 - i * 0.12
        if bold: ax_pc2.text(0.05, y, bold, transform=ax_pc2.transAxes,
                            color='#4fc3f7' if '↑' in bold else '#ff8a65', fontsize=9, fontweight='bold')
        ax_pc2.text(0.38, y, text, transform=ax_pc2.transAxes, color='#bbb', fontsize=8)

    # ── Description ─────────────────────────────────────────────────────
    ax_journey.set_xlim(0, 1); ax_journey.set_ylim(0, 1); ax_journey.axis('off')
    ax_journey.text(0.5, 0.92, f"V10 CAMPAIGN — {field.replace('_',' ').upper()}", transform=ax_journey.transAxes,
                    color='white', fontsize=10, ha='center', fontweight='bold')
    ax_journey.text(0.5, 0.55, description, transform=ax_journey.transAxes,
                    color='#aaa', fontsize=8, ha='center', va='center', linespacing=1.5)
    ax_journey.text(0.5, 0.05, "310K evaluations · 60 islands · PCA projection (33% variance captured)",
                    transform=ax_journey.transAxes, color='#666', fontsize=7, ha='center')

    # ── Title ───────────────────────────────────────────────────────────
    fig.suptitle(f"V10 Campaign — {label}", fontsize=15, fontweight='bold', color='white', y=0.97)
    fig.text(0.5, 0.94, "14-DoF DE optimisation · parameter-space PCA projection with Island 41 convergence trajectory",
             fontsize=8, color='#888', ha='center')

    out_path = f"{OUT_DIR}/v10-panel-{field.replace('_','-')}.png"
    plt.savefig(out_path, dpi=150, facecolor='#080810', bbox_inches='tight')
    plt.close(fig)
    print(f"    {out_path}")

print("\nAll 9 standalone panels rendered.")
