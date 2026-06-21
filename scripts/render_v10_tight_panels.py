#!/usr/bin/env python3
"""Generate standalone rich-context individual panel diagrams for V10 tight campaign.
Each panel from the 3x3 non-dimensional atlas and parameter atlas gets its own
full-context image with annotations, data callouts, and physics interpretation."""
import numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from matplotlib.patches import FancyBboxPatch
import os

OUT_DIR = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams"
DATA_PREFIX = "/tmp/v10_tight"

# ── Load data ──────────────────────────────────────────────────────────
pc1 = np.loadtxt(f"{DATA_PREFIX}_pc1.txt")
pc2 = np.loadtxt(f"{DATA_PREFIX}_pc2.txt")
mass = np.loadtxt(f"{DATA_PREFIX}_mass.txt")

atlas = np.genfromtxt(f"{DATA_PREFIX}_atlas.csv", delimiter=',', names=True, dtype=None, encoding='utf-8')
amask = atlas['mass'] < 200
atlas = atlas[amask]
apc1 = atlas['pc1']; apc2 = atlas['pc2']

q1, q99 = np.percentile(apc1, [1, 99])
q2_1, q2_99 = np.percentile(apc2, [1, 99])

rho_air = 1.225; V_wind = 11.0; P_rated = 50000.0; c_per_R = 0.113

def compute_pi(data):
    Do = data['Do_top']; td = data['t_over_D']; rh = data['r_hub']; rb = data['r_bottom']
    Lr = data['target_Lr']; nl = data['n_lines']; bt = data['bank_top']; lt = data['lambda_top']
    nrot = data['n_rotors']
    pi = {}
    pi['Slenderness'] = np.where(Do > 1e-6, Lr / Do, 0)
    pi['Beam Efficiency'] = td * pi['Slenderness']
    pi['TRPT Aspect'] = np.where(rh > 0, Lr * nl / rh, 0)
    pi['Ring Packing'] = np.where(nl * Do > 1e-6, Lr / (nl * Do), 0)
    pi['Power Loading'] = np.where(rh > 0, P_rated / (0.5 * rho_air * np.pi * rh**2 * V_wind**3), 0)
    pi['Ring Taper'] = np.where(rh > 0, (rh - rb) / rh, 0)
    pi['Solidity'] = nl * c_per_R * lt / (2 * np.pi)
    raw = np.where(Do > 1e-6, nrot * (lt * rh)**2 * np.cos(np.radians(bt)) / (nl * Do**2), 1e-6)
    pi['Exp/Struct log10'] = np.log10(np.maximum(raw, 1e-6))
    return pi

pi_data = compute_pi(atlas)
best_i = atlas['mass'].argmin()

plt.rcParams.update({
    'figure.facecolor': '#080810', 'axes.facecolor': '#080810',
    'text.color': 'white', 'axes.edgecolor': '#333', 'axes.labelcolor': 'white',
    'xtick.labelsize': 8, 'xtick.color': '#666', 'ytick.labelsize': 8, 'ytick.color': '#666',
    'font.size': 9,
})

# ══════════════════════════════════════════════════════════════════════════
# NON-DIMENSIONAL PI-GROUP PANELS (9 individual images)
# ══════════════════════════════════════════════════════════════════════════

PI_PANELS = [
    ('Slenderness', 'viridis', 'Beam Slenderness  L_r / D',
     'Segment length divided by beam diameter.\nHigher = longer thinner beams, fewer rings, less knuckle mass.\nWinner: ~50 (L_r=3.0m, D=0.06m) — both at tight bounds.\nV10v1 was 39 — tight bounds push slenderness 28% higher.',
     'The DE pushes slenderness to the physical limit: beams are at\nthe minimum diameter (0.06m) and segments at maximum length (3.0m).\nThis is the structural floor of the tight envelope — the DE cannot\nmake beams thinner or segments longer. Further mass reduction\nrequires widening these bounds or shifting to multi-rotor thrust\ndistribution (which the 4-rotor design already does).',
     30, 55),
    ('Beam Efficiency', 'plasma', 'Beam Efficiency  (t/D) × (L_r/D)',
     'Wall thickness ratio × slenderness. Column buckling metric.\nt/D=0.01 is pinned at minimum in 100% of feasible designs.\nWinner: ~0.50 — entirely slenderness-driven, no wall headroom.',
     't/D is screaming at 0.01 (the minimum wall thickness allowed).\nThere is no remaining mass budget in the beam walls — the DE\nhas exhausted this dimension. The efficiency value is purely a\nreflection of segment length (L_r=3.0 max). This is the deepest\nstructural constraint in the design space.',
     0.3, 0.55),
    ('TRPT Aspect', 'coolwarm', 'TRPT Aspect Ratio  L×n / r_hub',
     'Polygon perimeter × segment length / hub radius.\nWinner: ~13.5 (n=13, L_r=3.0, r_hub=2.89m) — 17% higher than V10v1.\nCompact hub + many lines = high structural efficiency.',
     'The aspect ratio increase is driven by the hub radius shrinking\nfrom 3.70m (V10v1) to 2.89m (tight). The 22% smaller hub is enabled\nby the 4-rotor configuration — thrust is distributed across rings\nso the hub doesn\'t need to house the sole power-producing rotor.\nThe polygon count (13 vs 12) and segment length (3.0 vs 2.95) also\ncontribute marginal gains.',
     8, 15),
    ('Ring Packing', 'viridis', 'Ring Packing  L_r / (n×D)',
     'Segment length / (polygon sides × beam diameter).\nHigher = more efficient use of structural material per ring.\nWinner: ~3.8 — 41% denser than V10v1 (2.7).',
     'Ring packing density directly reflects the thinner beams (0.06m\nvs V10v1\'s 0.075m) and longer segments (3.0m vs 2.95m). Each ring\nspans more shaft length with less beam material. The DE finds this\nby pushing both Do_top and target_Lr to their tight bounds.',
     1.5, 4.5),
    ('Power Loading', 'YlOrRd', 'Power Loading  P / (½ρ π r_hub² V³)',
     'Rated power ÷ kinetic energy flux through hub swept area.\n>1.0 = needs expansion rotor contribution (> Betz from geometry).\nWinner: ~2.4 — nearly double V10v1 (1.4). Requires significant\nexpansion rotor power from the 4-rotor configuration.',
     'The power loading has nearly doubled because the hub radius\nshrunk 22% (area down 50%). To extract 50 kW from half the swept\narea, the expansion rotors must contribute 20-30 kW. The 4-rotor\ndesign makes this viable — the DE discovered that a compact hub\nwith distributed power generation is lighter than a large single-\nrotor hub.',
     1.0, 3.0),
    ('Ring Taper', 'coolwarm', 'Ring Taper  (r_hub − r_bottom) / r_hub',
     '0 = cylindrical. Positive = hub wider (normal taper).\nNegative = ground wider (inverted cone, V10v1 style).\nWinner: +0.31 — normal taper, hub 2.89m, ground 2.00m.\nFundamental geometric shift from V10v1\'s inverted −0.24.',
     'The taper sign change is one of the most significant shifts.\nV10v1 had r_bottom > r_hub (inverted cone) to handle accumulated\ntether tension at the ground ring from a single hub rotor.\nThe tight winner has a normal taper: the ground ring is as narrow\nas the bounds allow (r_bottom=2.0m min), because multi-rotor thrust\ndistribution reduces the tension accumulation at each ring.',
     0.0, 0.5),
    ('Solidity', 'magma', 'Rotor Solidity  n_blades × c / (2πR)',
     'Blade chord area ÷ rotor circumference. Higher = more blade\narea per rotor disc, higher torque capacity.\nWinner: ~0.15 — 3× higher than V10v1 (0.052). k_mppt λ² scaling\nforces the DE to select blades that can actually produce rated power.',
     'The solidity increase is a direct consequence of the k_mppt λ²\nscaling fix. Without it, the DE converged to λ=0.234 (solidity 0.05)\nand the static solver compensated with higher ω — but the ODE showed\nthe rotor couldn\'t spin up. With k_mppt scaled by blade area, λ=0.519\n(solidity 0.15) is required to produce 50 kW at the scaled generator\nload of 166. The DE now correctly trades blade mass against power.',
     0.02, 0.20),
    ('Exp/Struct log10', 'cividis', 'Exp/Struct Ratio  log₁₀(ΣA_rotor / ΣA_beam)',
     'Orders of magnitude by which rotor swept area exceeds beam\ncross-section. Winner: ~1.5 (≈32×) — LOWER than V10v1 (2.4, 250×).\nCompact structure with smaller rotors at smaller hub.',
     'Counterintuitively, the 4-rotor design has a LOWER expansion-to-\nstructural ratio than the 1-rotor V10v1. This is because the compact\nhub (2.89m vs 3.70m) reduces individual rotor swept area (∝ r_hub²),\nand the denser ring packing (thinner beams, same n_lines) means the\nstructural area per unit rotor area is higher. The DE trades some\nexpansion dominance for structural compactness.',
     0.5, 2.5),
]

for field, cmap, title, callout, context, vmin_o, vmax_o in PI_PANELS:
    print(f"  Non-dim: {field}...")
    vals = pi_data[field]
    
    fig = plt.figure(figsize=(18, 12))
    gs = fig.add_gridspec(1, 2, width_ratios=[3, 1.2], left=0.05, right=0.95, top=0.90, bottom=0.08, wspace=0.35)
    
    # Main heatmap
    ax = fig.add_subplot(gs[0, 0])
    vmin = vmin_o; vmax = vmax_o
    H, xe, ye = np.histogram2d(apc1, apc2, bins=80, weights=vals)
    Hc, _, _ = np.histogram2d(apc1, apc2, bins=80)
    with np.errstate(invalid='ignore', divide='ignore'):
        Havg = np.divide(H, Hc, where=Hc > 0)
    
    im = ax.imshow(Havg.T, origin='lower', aspect='auto',
        extent=(apc1.min(), apc1.max(), apc2.min(), apc2.max()),
        cmap=cmap, norm=Normalize(vmin=vmin, vmax=vmax), interpolation='bilinear')
    
    # Iso-mass contours
    Hm, _, _ = np.histogram2d(apc1, apc2, bins=80, weights=atlas['mass'])
    Hma = np.divide(Hm, Hc, where=Hc > 0)
    xc = (xe[:-1]+xe[1:])/2; yc = (ye[:-1]+ye[1:])/2
    for lvl, lw, a in [(50, 0.8, 0.5), (60, 0.5, 0.3), (75, 0.3, 0.2)]:
        ax.contour(xc, yc, Hma.T, levels=[lvl], colors='white', linewidths=lw, alpha=a, linestyles='--')
    
    # Winner marker
    ax.scatter(apc1[best_i], apc2[best_i], c='yellow', s=200, zorder=10, edgecolors='white', linewidths=2.5, marker='D')
    
    # Winner value callout
    winner_val = vals[best_i]
    ax.annotate(f'{winner_val:.2f}', (apc1[best_i], apc2[best_i]),
        xytext=(20, -25), textcoords='offset points', color='yellow', fontsize=11, fontweight='bold',
        bbox=dict(boxstyle='round,pad=0.3', facecolor='black', alpha=0.7, edgecolor='yellow'))
    
    ax.set_xlabel("PC1 — Structural Scale (28.9% var) →", fontsize=10, color='#888')
    ax.set_ylabel("PC2 — Configuration (20.4% var) →", fontsize=10, color='#888')
    ax.set_title(title, fontsize=13, color='white', fontweight='bold', pad=8)
    ax.set_xlim(apc1.min(), apc1.max()); ax.set_ylim(apc2.min(), apc2.max())
    
    # Colorbar — vertical, inside heatmap right margin
    # GridSpec width_ratios [3, 1.2] with wspace=0.35, left=0.05, right=0.95
    # Heatmap spans ~3/(3+1.2+0.35) of 0.90 = ~0.59, ending at ~0.64
    ax_pos = ax.get_position()
    cbar_ax = fig.add_axes([ax_pos.x1 + 0.005, ax_pos.y0, 0.012, ax_pos.height])
    cbar = fig.colorbar(im, cax=cbar_ax, orientation='vertical')
    cbar.ax.tick_params(labelsize=7, colors='white'); cbar.outline.set_edgecolor('#444')
    
    # Right panel: context + callout
    ax_r = fig.add_subplot(gs[0, 1]); ax_r.set_xlim(0, 1); ax_r.set_ylim(0, 1); ax_r.axis('off')
    
    # Callout box
    ax_r.text(0.05, 0.92, "WINNER VALUE", transform=ax_r.transAxes,
              color='yellow', fontsize=10, fontweight='bold')
    ax_r.text(0.05, 0.82, callout, transform=ax_r.transAxes,
              color='#ccc', fontsize=8.5, va='top', linespacing=1.4)
    
    # Context box
    ax_r.text(0.05, 0.42, "PHYSICAL CONTEXT", transform=ax_r.transAxes,
              color='#4fc3f7', fontsize=10, fontweight='bold')
    ax_r.text(0.05, 0.32, context, transform=ax_r.transAxes,
              color='#999', fontsize=8, va='top', linespacing=1.35)
    
    # Data range
    ax_r.text(0.05, 0.05, f"Data range: {vmin:.2f} – {vmax:.2f}\nWinner: {winner_val:.2f}",
              transform=ax_r.transAxes, color='#666', fontsize=7.5)
    
    fig.suptitle(f"V10 Tight Campaign — {title.split('  ')[0]}\n12 islands, tight bounds, k_mppt ∝ λ² scaling — 49.2 kg winner",
                 fontsize=12, color='#888', fontweight='normal', y=0.96)
    
    fname = field.lower().replace('/', '-').replace(' ', '_')
    plt.savefig(f"{OUT_DIR}/v10-tight-panel-{fname}.png", dpi=150, facecolor='#080810', bbox_inches='tight')
    plt.close()
    print(" done")

print(f"\nNon-dimensional panels saved to {OUT_DIR}/")
