#!/usr/bin/env python3
"""Generate standalone rich-context individual PARAMETER panels for V10 tight campaign."""
import numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize

OUT_DIR = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams"
DATA_PREFIX = "/tmp/v10_tight"

atlas = np.genfromtxt(f"{DATA_PREFIX}_atlas.csv", delimiter=',', names=True, dtype=None, encoding='utf-8')
amask = atlas['mass'] < 200
atlas = atlas[amask]
apc1 = atlas['pc1']; apc2 = atlas['pc2']
best_i = atlas['mass'].argmin()

plt.rcParams.update({
    'figure.facecolor': '#080810', 'axes.facecolor': '#080810',
    'text.color': 'white', 'axes.edgecolor': '#333', 'axes.labelcolor': 'white',
    'xtick.labelsize': 8, 'xtick.color': '#666', 'ytick.labelsize': 8, 'ytick.color': '#666',
})

PARAM_PANELS = [
    ('mass', 'viridis_r', 'Mass (kg)',
     'Total airborne mass × power-accuracy penalty.\nWinner: 49.20 kg — 36% lighter than V10v1 (76.75 kg).\nThe single strongest indicator of design quality.',
     'The mass landscape shows a clear basin at 49-55 kg in the\nbottom-left quadrant. The tight bounds compress the feasible\nregion into a narrow corridor along PC2. The DE explores the\nfull width of PC1 but converges rapidly in PC2.',
     45, 80),
    ('n_lines', 'plasma', 'n_lines — Polygon Sides',
     'Number of tether lines (and polygon sides).\nWinner: 13 sides — one more than V10v1 (12).\nTight bounds: [8, 16] — triangles and pentagons excluded.',
     'The DE consistently selects n=11-14, peaking at 13. Higher\npolygon counts distribute tether tension across more lines but\nincrease knuckle mass. The 13-line optimum balances structural\nload distribution against mass.',
     8, 16),
    ('n_rotors', 'magma', 'n_rotors — Active Expansion Rotors',
     'Number of active rotors from the 19-valid-mask set.\nWinner: 4 rotors — V10v1 had only 1.\nThe k_mppt λ² scaling opens the multi-rotor basin.',
     'The rotor count landscape shows a clear preference for 3-4\nrotors in the low-mass region. Single-rotor designs (the V10v1\nbasin) are heavier because they require larger hub radii and\nhigher λ to produce rated power. Multi-rotor designs distribute\nthrust, enabling compact hubs.',
     0, 4),
    ('r_hub', 'coolwarm', 'r_hub — Hub Ring Radius (m)',
     'Hub ring radius — the structural anchor point.\nWinner: 2.89m — 22% smaller than V10v1 (3.70m).\nTight bounds: [2.5, 5.0] — compact region.',
     'The hub radius shows a strong gradient across PC1: smaller\nhubs dominate the low-mass region. The 2.89m winner is near the\nbottom of the explored range. The multi-rotor configuration\nenables this compactness — a single large hub rotor is no longer\nrequired to produce all 50 kW.',
     2.5, 4.5),
    ('r_bottom', 'coolwarm', 'r_bottom — Ground Ring Radius (m)',
     'Ground ring radius — the base of the TRPT shaft.\nWinner: 2.00m — screaming at the tight bound minimum.\nTight bounds: [2.0, 5.0] — DE cannot go lower.',
     'r_bottom is screaming at 2.0m in every feasible design. The\nDE would select a smaller ground ring if allowed — the true\noptimum lies below the current tight bound. A narrower ground\nring reduces structural mass but must still carry accumulated\ntether tension from all rotors above.',
     2.0, 4.0),
    ('bank_top', 'RdYlBu_r', 'Bank Top — Hub Rotor Bank Angle (°)',
     'Bank angle of the top (hub) rotor.\nWinner: 32° — slightly below the 35° maximum.\nV10v1 was pinned at 35°, now slightly interior.',
     'Bank angle shows a bimodal distribution: designs cluster near\n0° (axial drive) and 30-35° (banked spreading). The winner at 32°\nuses moderate bank — enough radial spreading to distribute thrust\nbut not so much that axial power production suffers. The DE has\nroom to tune: bank is not at a bound.',
     0, 35),
    ('lambda_top', 'YlOrRd', 'λ Top — Hub Rotor Blade Scale',
     'Blade scale factor for the top rotor. λ=1.0 = full BEM size.\nWinner: 0.519 — 2.2× larger than V10v1 (0.234).\nk_mppt λ² scaling forces the DE to use adequate blades.',
     'The blade scale landscape shows the k_mppt scaling working:\ndesigns with λ<0.3 (V10v1-style) are in the high-mass region\nbecause they cannot produce rated power at the scaled generator\nload. The winner at λ=0.519 sits in the sweet spot where blade\nmass and power output balance.',
     0.15, 0.8),
    ('t_over_D', 'cividis', 't/D — Beam Wall Thickness Ratio',
     'Wall thickness / outer diameter of ring beams.\nWinner: 0.01 — pinned at the absolute minimum.\n100% of feasible designs are at this floor.',
     't/D is universally at 0.01 — the DE has fully saturated this\ndimension. There is no remaining mass budget in beam walls. The\nstructural floor is set by manufacturing minimums and Euler\nbuckling constraints. This is the deepest single constraint.',
     0.005, 0.03),
    ('target_Lr', 'viridis', 'Target L/r — Segment Slenderness Target',
     'Target segment length / ring radius ratio.\nWinner: 3.0 — screaming at the tight bound maximum.\nLonger segments = fewer rings = less knuckle mass.',
     'target_Lr is at 3.0 (max) in nearly all feasible designs.\nThe DE would select even longer segments if allowed. Longer\nsegments mean fewer rings, fewer knuckles, and less tether\nlength — all reducing mass. The true optimum in this dimension\nlies above 3.0.',
     2.2, 3.0),
]

for field, cmap, title, callout, context, vmin_o, vmax_o in PARAM_PANELS:
    print(f"  Param: {field}...")
    vals = atlas[field]
    
    fig = plt.figure(figsize=(18, 12))
    gs = fig.add_gridspec(1, 2, width_ratios=[3, 1.2], left=0.05, right=0.95, top=0.90, bottom=0.08, wspace=0.35)
    
    ax = fig.add_subplot(gs[0, 0])
    vmin = vmin_o; vmax = vmax_o
    H, xe, ye = np.histogram2d(apc1, apc2, bins=80, weights=vals)
    Hc, _, _ = np.histogram2d(apc1, apc2, bins=80)
    with np.errstate(invalid='ignore', divide='ignore'):
        Havg = np.divide(H, Hc, where=Hc > 0)
    
    im = ax.imshow(Havg.T, origin='lower', aspect='auto',
        extent=(apc1.min(), apc1.max(), apc2.min(), apc2.max()),
        cmap=cmap, norm=Normalize(vmin=vmin, vmax=vmax), interpolation='bilinear')
    
    Hm, _, _ = np.histogram2d(apc1, apc2, bins=80, weights=atlas['mass'])
    Hma = np.divide(Hm, Hc, where=Hc > 0)
    xc = (xe[:-1]+xe[1:])/2; yc = (ye[:-1]+ye[1:])/2
    for lvl, lw, a in [(50, 0.8, 0.5), (60, 0.5, 0.3), (75, 0.3, 0.2)]:
        ax.contour(xc, yc, Hma.T, levels=[lvl], colors='white', linewidths=lw, alpha=a, linestyles='--')
    
    ax.scatter(apc1[best_i], apc2[best_i], c='yellow', s=200, zorder=10, edgecolors='white', linewidths=2.5, marker='D')
    winner_val = vals[best_i]
    ax.annotate(f'{winner_val:.2f}' if winner_val < 100 else f'{winner_val:.1f}',
        (apc1[best_i], apc2[best_i]), xytext=(20, -25), textcoords='offset points',
        color='yellow', fontsize=11, fontweight='bold',
        bbox=dict(boxstyle='round,pad=0.3', facecolor='black', alpha=0.7, edgecolor='yellow'))
    
    ax.set_xlabel("PC1 — Structural Scale (28.9% var) →", fontsize=10, color='#888')
    ax.set_ylabel("PC2 — Configuration (20.4% var) →", fontsize=10, color='#888')
    ax.set_title(title, fontsize=13, color='white', fontweight='bold', pad=8)
    ax.set_xlim(apc1.min(), apc1.max()); ax.set_ylim(apc2.min(), apc2.max())
    
    cbar_ax = fig.add_axes([0.78, 0.55, 0.012, 0.25])
    cbar = fig.colorbar(im, cax=cbar_ax)
    cbar.ax.tick_params(labelsize=7, colors='white'); cbar.outline.set_edgecolor('#444')
    
    ax_r = fig.add_subplot(gs[0, 1]); ax_r.set_xlim(0, 1); ax_r.set_ylim(0, 1); ax_r.axis('off')
    ax_r.text(0.05, 0.92, "WINNER VALUE", transform=ax_r.transAxes, color='yellow', fontsize=10, fontweight='bold')
    ax_r.text(0.05, 0.78, callout, transform=ax_r.transAxes, color='#ccc', fontsize=8.5, va='top', linespacing=1.4)
    ax_r.text(0.05, 0.38, "PHYSICAL CONTEXT", transform=ax_r.transAxes, color='#4fc3f7', fontsize=10, fontweight='bold')
    ax_r.text(0.05, 0.28, context, transform=ax_r.transAxes, color='#999', fontsize=8, va='top', linespacing=1.35)
    ax_r.text(0.05, 0.05, f"Bounds: [{vmin_o}, {vmax_o}]\nWinner: {winner_val:.2f}" if winner_val < 100 else f"Bounds: [{vmin_o}, {vmax_o}]\nWinner: {winner_val:.1f}",
              transform=ax_r.transAxes, color='#666', fontsize=7.5)
    
    fig.suptitle(f"V10 Tight Campaign — {title.split('  ')[0]}\n12 islands, tight bounds, k_mppt ∝ λ² scaling — 49.2 kg winner",
                 fontsize=12, color='#888', y=0.96)
    
    fname = field.lower().replace('/', '-').replace(' ', '_')
    plt.savefig(f"{OUT_DIR}/v10-tight-param-{fname}.png", dpi=150, facecolor='#080810', bbox_inches='tight')
    plt.close()
    print(" done")

print(f"\nParameter panels saved to {OUT_DIR}/")
