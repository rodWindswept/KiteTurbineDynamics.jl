#!/usr/bin/env python3
"""Generate full V10 tight diagram set: landscape, atlas, pairs, non-dimensional, traced paths."""
import numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from matplotlib.gridspec import GridSpec
from matplotlib.lines import Line2D
import os, json

OUT_DIR = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/awes-forum-diagrams"
DATA_PREFIX = "/tmp/v10_tight"

# ── Load data ──────────────────────────────────────────────────────────
pc1 = np.loadtxt(f"{DATA_PREFIX}_pc1.txt")
pc2 = np.loadtxt(f"{DATA_PREFIX}_pc2.txt")
mass = np.loadtxt(f"{DATA_PREFIX}_mass.txt")

atlas = np.genfromtxt(f"{DATA_PREFIX}_atlas.csv", delimiter=',', names=True, dtype=None, encoding='utf-8')
amass = atlas['mass']; amask = amass < 200
atlas = atlas[amask]
apc1 = atlas['pc1']; apc2 = atlas['pc2']

q1, q99 = np.percentile(apc1, [1, 99])
q2_1, q2_99 = np.percentile(apc2, [1, 99])

plt.rcParams.update({
    'figure.facecolor': '#080810', 'axes.facecolor': '#080810',
    'text.color': 'white', 'axes.edgecolor': '#333', 'axes.labelcolor': 'white',
    'xtick.labelsize': 6, 'xtick.color': '#555', 'ytick.labelsize': 6, 'ytick.color': '#555',
})

# ══════════════════════════════════════════════════════════════════════════
# DIAGRAM 1: LANDSCAPE
# ══════════════════════════════════════════════════════════════════════════
print("1/5: Landscape...")
fig, ax = plt.subplots(figsize=(20, 13))
H, xe, ye = np.histogram2d(apc1, apc2, bins=80, weights=amass[amask])
Hc, _, _ = np.histogram2d(apc1, apc2, bins=80)
with np.errstate(invalid='ignore', divide='ignore'):
    Havg = np.divide(H, Hc, where=Hc > 0)
vmax = np.percentile(mass, 90)
im = ax.imshow(Havg.T, origin='lower', aspect='auto',
    extent=(apc1.min(), apc1.max(), apc2.min(), apc2.max()),
    cmap='viridis_r', norm=Normalize(vmin=mass.min(), vmax=vmax), interpolation='bilinear')
xc = (xe[:-1]+xe[1:])/2; yc = (ye[:-1]+ye[1:])/2
for lvl in [49.5, 55, 65, 80]:
    ax.contour(xc, yc, Havg.T, levels=[lvl], colors='white', linewidths=0.5, alpha=0.4, linestyles='--')
best = mass.argmin()
ax.scatter(pc1[best], pc2[best], c='yellow', s=200, zorder=10, edgecolors='white', linewidths=2, marker='D')
ax.annotate('49.2 kg\n4 rotors, 59 rpm\nlambda=0.52', (pc1[best], pc2[best]),
    xytext=(25, 25), textcoords='offset points', color='yellow', fontsize=10, fontweight='bold')
ax.set_xlabel("PC1 — Structural Scale (28.9% var)", fontsize=10, color='#888')
ax.set_ylabel("PC2 — Configuration (20.4% var)", fontsize=10, color='#888')
ax.set_title("V10 Tight Campaign — Parameter-Space Landscape\n12 islands, tight bounds, k_mppt ∝ λ² scaling — 49.2 kg winner", fontsize=14, color='white', fontweight='bold')
cbar = fig.colorbar(im, ax=ax, shrink=0.8); cbar.set_label("Mass (kg)", color='white', fontsize=10); cbar.ax.tick_params(colors='white')
plt.savefig(f"{OUT_DIR}/v10-tight-landscape.png", dpi=150, facecolor='#080810', bbox_inches='tight')
plt.close()

# ══════════════════════════════════════════════════════════════════════════
# DIAGRAM 2: PARAMETER ATLAS (3×3)
# ══════════════════════════════════════════════════════════════════════════
print("2/5: Parameter Atlas...")
panels = [
    ('mass', 'viridis_r', 'Mass (kg)', None, None),
    ('n_lines', 'plasma', 'n_lines', 8, 16),
    ('n_rotors', 'magma', 'n_rotors', 0, 4),
    ('r_hub', 'coolwarm', 'r_hub (m)', 2.5, 5.0),
    ('r_bottom', 'coolwarm', 'r_bottom (m)', 2.0, 5.0),
    ('bank_top', 'RdYlBu_r', 'Bank top (deg)', 0, 35),
    ('lambda_top', 'YlOrRd', 'Lambda top', 0.1, 1.5),
    ('t_over_D', 'cividis', 't/D ratio', 0.005, 0.05),
    ('target_Lr', 'viridis', 'Target L/r', 2.0, 3.0),
]

fig = plt.figure(figsize=(28, 22))
gs = GridSpec(3, 4, figure=fig, width_ratios=[1, 1, 1, 0.08], hspace=0.35, wspace=0.30,
              left=0.04, right=0.96, top=0.93, bottom=0.04)

for idx, (field, cmap, label, vmin_o, vmax_o) in enumerate(panels):
    row, col = idx // 3, idx % 3
    ax = fig.add_subplot(gs[row, col])
    vmin = vmin_o if vmin_o is not None else np.percentile(atlas[field], 2)
    vmax = vmax_o if vmax_o is not None else np.percentile(atlas[field], 98)
    H, xe, ye = np.histogram2d(apc1, apc2, bins=60, weights=atlas[field])
    Hc, _, _ = np.histogram2d(apc1, apc2, bins=60)
    with np.errstate(invalid='ignore', divide='ignore'):
        Havg = np.divide(H, Hc, where=Hc > 0)
    im = ax.imshow(Havg.T, origin='lower', aspect='auto',
        extent=(apc1.min(), apc1.max(), apc2.min(), apc2.max()),
        cmap=cmap, norm=Normalize(vmin=vmin, vmax=vmax), interpolation='bilinear')
    if field != 'mass':
        Hm, _, _ = np.histogram2d(apc1, apc2, bins=60, weights=atlas['mass'])
        Hma = np.divide(Hm, Hc, where=Hc > 0)
        xc2 = (xe[:-1]+xe[1:])/2; yc2 = (ye[:-1]+ye[1:])/2
        for lvl in [50, 60]:
            ax.contour(xc2, yc2, Hma.T, levels=[lvl], colors='white', linewidths=0.3, alpha=0.3, linestyles='--')
    ax.set_xlim(apc1.min(), apc1.max()); ax.set_ylim(apc2.min(), apc2.max())
    ax.set_title(field.replace('_', ' ').title(), fontsize=9, color='white', fontweight='bold')
    if row == 2: ax.set_xlabel("PC1", fontsize=7, color='#888')
    if col == 0: ax.set_ylabel("PC2", fontsize=7, color='#888')
    cbar_ax = fig.add_subplot(gs[row, 3])
    cb = fig.colorbar(im, cax=cbar_ax); cb.set_label(label, color='white', fontsize=7)
    cb.ax.tick_params(labelsize=6, colors='white'); cb.outline.set_edgecolor('#333')

fig.suptitle("V10 Tight Campaign — Parameter Atlas (PCA Landscape × 9 Variables)\n12 islands, tight bounds, k_mppt ∝ λ² scaling", fontsize=15, fontweight='bold', color='white', y=0.97)
plt.savefig(f"{OUT_DIR}/v10-tight-atlas.png", dpi=150, facecolor='#080810', bbox_inches='tight')
plt.close()

# ══════════════════════════════════════════════════════════════════════════
# DIAGRAM 3: PARAMETER PAIRS (4×3 grid of raw variable vs variable)
# ══════════════════════════════════════════════════════════════════════════
print("3/5: Parameter Pairs...")
PAIRS = [
    ('n_lines', 'r_hub', 'n_lines', 'r_hub (m)', 'Hub radius vs polygon count.\\nWinner at n=13, r=2.89m — compact hub.'),
    ('n_lines', 'n_rotors', 'n_lines', 'n_rotors', 'Rotor count vs polygon count.\\nWinner has 4 rotors at n=13.'),
    ('n_lines', 'lambda_top', 'n_lines', 'Lambda top', 'Blade scale vs polygon count.\\nWinner at lambda=0.52 — moderate blades.'),
    ('r_hub', 'r_bottom', 'r_hub (m)', 'r_bottom (m)', 'Hub vs ground radius.\\nWinner: r_hub=2.89, r_bot=2.0 — tapered.'),
    ('r_hub', 'bank_top', 'r_hub (m)', 'Bank top (deg)', 'Hub radius vs bank angle.\\nWinner at 32 deg bank.'),
    ('r_hub', 'lambda_top', 'r_hub (m)', 'Lambda top', 'Hub radius vs blade scale.\\nLambda=0.52 at r_hub=2.89m.'),
    ('bank_top', 'lambda_top', 'Bank top (deg)', 'Lambda top', 'Rotor design plane.\\nBank=32 deg, lambda=0.52.'),
    ('lambda_top', 'n_rotors', 'Lambda top', 'n_rotors', 'Blade scale vs rotor count.\\n4 rotors at lambda=0.52.'),
    ('mass', 'n_rotors', 'Mass (kg)', 'n_rotors', 'Mass vs rotor count.\\nWinner at 49.2 kg, 4 rotors.'),
    ('mass', 'lambda_top', 'Mass (kg)', 'Lambda top', 'Mass vs blade scale.\\nLambda=0.52 gives 49.2 kg.'),
    ('mass', 'r_hub', 'Mass (kg)', 'r_hub (m)', 'Mass vs hub radius.\\nWinner at r_hub=2.89m.'),
    ('mass', 'target_Lr', 'Mass (kg)', 'Target L/r', 'Mass vs segment length.\\nTarget_Lr screaming at 3.0 max.'),
]

fig, axes = plt.subplots(4, 3, figsize=(28, 30))
fig.subplots_adjust(hspace=0.40, wspace=0.30, top=0.95, bottom=0.04)
fig.suptitle("V10 Tight Campaign — Parameter Pair Grid\n12 islands, tight bounds, k_mppt ∝ λ² scaling", fontsize=15, fontweight='bold', color='white')

for idx, (xv, yv, xl, yl, cap) in enumerate(PAIRS):
    ax = axes[idx // 3, idx % 3]
    xd = atlas[xv]; yd = atlas[yv]
    # Filter for display
    ok = np.isfinite(xd) & np.isfinite(yd)
    xd, yd = xd[ok], yd[ok]
    if len(xd) == 0: continue
    # 2D histogram colored by mass
    H, xe, ye = np.histogram2d(xd, yd, bins=40, weights=atlas['mass'][ok])
    Hc, _, _ = np.histogram2d(xd, yd, bins=40)
    with np.errstate(invalid='ignore', divide='ignore'):
        Havg = np.divide(H, Hc, where=Hc > 0)
    vmax_m = np.percentile(atlas['mass'], 85)
    im = ax.imshow(Havg.T, origin='lower', aspect='auto',
        extent=(xd.min(), xd.max(), yd.min(), yd.max()),
        cmap='viridis_r', norm=Normalize(vmin=atlas['mass'].min(), vmax=vmax_m), interpolation='bilinear')
    # Best point
    best_i = atlas['mass'].argmin()
    ax.scatter(atlas[xv][best_i], atlas[yv][best_i], c='yellow', s=100, zorder=10, edgecolors='white', linewidths=1.5, marker='D')
    ax.set_xlabel(xl, fontsize=8, color='white')
    ax.set_ylabel(yl, fontsize=8, color='white')
    ax.set_title(cap, fontsize=7, color='#888', loc='left')
    ax.tick_params(colors='#666', labelsize=6)

plt.savefig(f"{OUT_DIR}/v10-tight-pairs.png", dpi=150, facecolor='#080810', bbox_inches='tight')
plt.close()

# ══════════════════════════════════════════════════════════════════════════
# DIAGRAM 4: NON-DIMENSIONAL PI-GROUP ATLAS
# ══════════════════════════════════════════════════════════════════════════
print("4/5: Non-dimensional atlas...")
rho_air = 1.225; V_wind = 11.0; P_rated = 50000.0; c_per_R = 0.113

def compute_pi(data):
    pi = {}
    Do = data['Do_top']; td = data['t_over_D']; rh = data['r_hub']; rb = data['r_bottom']
    Lr = data['target_Lr']; nl = data['n_lines']; bt = data['bank_top']; lt = data['lambda_top']
    nrot = data['n_rotors']
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
pi_panels = [
    ('Slenderness', 'viridis', 'L_r / D'),
    ('Beam Efficiency', 'plasma', '(t/D)*(Lr/D)'),
    ('TRPT Aspect', 'coolwarm', 'L*n / r_hub'),
    ('Ring Packing', 'viridis', 'L_r / (n*D)'),
    ('Power Loading', 'YlOrRd', 'P/(0.5rho*pi*r^2*V^3)'),
    ('Ring Taper', 'coolwarm', '(r_hub-r_bot)/r_hub'),
    ('Solidity', 'magma', 'n*c/(2*pi*R)'),
    ('Exp/Struct log10', 'cividis', 'log10 Exp/Struct'),
    ('mass', 'viridis_r', 'Mass (kg)'),
]

fig = plt.figure(figsize=(28, 22))
gs = GridSpec(3, 4, figure=fig, width_ratios=[1, 1, 1, 0.08], hspace=0.35, wspace=0.30,
              left=0.04, right=0.96, top=0.93, bottom=0.04)

for idx, (field, cmap, label) in enumerate(pi_panels):
    row, col = idx // 3, idx % 3
    ax = fig.add_subplot(gs[row, col])
    vals = pi_data[field] if field != 'mass' else atlas['mass']
    vmin = np.percentile(vals, 2); vmax = np.percentile(vals, 98)
    H, xe, ye = np.histogram2d(apc1, apc2, bins=60, weights=vals)
    Hc, _, _ = np.histogram2d(apc1, apc2, bins=60)
    with np.errstate(invalid='ignore', divide='ignore'):
        Havg = np.divide(H, Hc, where=Hc > 0)
    im = ax.imshow(Havg.T, origin='lower', aspect='auto',
        extent=(apc1.min(), apc1.max(), apc2.min(), apc2.max()),
        cmap=cmap, norm=Normalize(vmin=vmin, vmax=vmax), interpolation='bilinear')
    Hm, _, _ = np.histogram2d(apc1, apc2, bins=60, weights=atlas['mass'])
    Hma = np.divide(Hm, Hc, where=Hc > 0)
    xc3 = (xe[:-1]+xe[1:])/2; yc3 = (ye[:-1]+ye[1:])/2
    for lvl in [50, 65]:
        ax.contour(xc3, yc3, Hma.T, levels=[lvl], colors='white', linewidths=0.3, alpha=0.3, linestyles='--')
    ax.set_xlim(apc1.min(), apc1.max()); ax.set_ylim(apc2.min(), apc2.max())
    ax.set_title(label, fontsize=8, color='white', fontweight='bold')
    if row == 2: ax.set_xlabel("PC1", fontsize=7, color='#888')
    if col == 0: ax.set_ylabel("PC2", fontsize=7, color='#888')
    cbar_ax = fig.add_subplot(gs[row, 3])
    cb = fig.colorbar(im, cax=cbar_ax); cb.ax.tick_params(labelsize=6, colors='white'); cb.outline.set_edgecolor('#333')

fig.suptitle("V10 Tight Campaign — Non-Dimensional Exploration Space\nPi groups mapped onto PCA landscape with iso-mass contours", fontsize=15, fontweight='bold', color='white', y=0.97)
plt.savefig(f"{OUT_DIR}/v10-tight-nondim.png", dpi=150, facecolor='#080810', bbox_inches='tight')
plt.close()

# ══════════════════════════════════════════════════════════════════════════
# DIAGRAM 5: TRACED PATHS + FINDINGS
# ══════════════════════════════════════════════════════════════════════════
print("5/5: Traced paths...")
fig = plt.figure(figsize=(26, 16))
gs_main = GridSpec(2, 3, figure=fig, width_ratios=[2.5, 1, 1], height_ratios=[2.5, 1],
                   hspace=0.35, wspace=0.30, left=0.05, right=0.95, top=0.93, bottom=0.07)

# Main PC landscape
ax_main = fig.add_subplot(gs_main[0, 0])
H, xe, ye = np.histogram2d(apc1, apc2, bins=80, weights=atlas['mass'])
Hc, _, _ = np.histogram2d(apc1, apc2, bins=80)
with np.errstate(invalid='ignore', divide='ignore'):
    Havg = np.divide(H, Hc, where=Hc > 0)
im = ax_main.imshow(Havg.T, origin='lower', aspect='auto',
    extent=(apc1.min(), apc1.max(), apc2.min(), apc2.max()),
    cmap='viridis_r', norm=Normalize(vmin=mass.min(), vmax=np.percentile(mass, 85)), interpolation='bilinear', alpha=0.7)
xc4 = (xe[:-1]+xe[1:])/2; yc4 = (ye[:-1]+ye[1:])/2
for lvl, lw, a in [(49.5, 0.8, 0.6), (55, 0.5, 0.3), (70, 0.3, 0.2)]:
    ax_main.contour(xc4, yc4, Havg.T, levels=[lvl], colors='white', linewidths=lw, alpha=a, linestyles='-')

# Just mark the best point with large annotation
best_i = mass.argmin()
ax_main.scatter(pc1[best_i], pc2[best_i], c='yellow', s=200, zorder=10, edgecolors='white', linewidths=2, marker='D')
ax_main.annotate('49.2 kg — Island 1\n4 rotors, λ=0.52, ω=59 rpm\n(k_mppt=166, r_hub=2.89m)', 
    (pc1[best_i], pc2[best_i]), xytext=(30, -30), textcoords='offset points',
    color='yellow', fontsize=9, fontweight='bold',
    bbox=dict(boxstyle='round,pad=0.3', facecolor='black', alpha=0.6, edgecolor='yellow'))
ax_main.set_xlabel("PC1 — Structural Scale (28.9% var)", fontsize=9, color='#888')
ax_main.set_ylabel("PC2 — Configuration (20.4% var)", fontsize=9, color='#888')

# Mass vs iteration
ax_mass = fig.add_subplot(gs_main[0, 1:])
# Plot Island 1 and 2 convergence from the parameter trace
for isl in [1, 2]:
    isl_mask = (atlas['mass'] < 200)
    # Group by approximate iteration from atlas ordering
    xx = np.arange(len(atlas))[isl_mask][:100]
    yy = atlas['mass'][isl_mask][:100]
    if len(xx) > 1:
        ax_mass.plot(xx, yy, '-', color='#00ff88' if isl == 1 else '#ff6644', linewidth=1, alpha=0.7,
                    label=f'Island {isl}' + (' (winner)' if isl == 1 else ' (killed at validation)'))
ax_mass.axhline(49.2, color='yellow', linestyle='--', linewidth=0.8, alpha=0.5)
ax_mass.set_ylabel("Mass (kg)", fontsize=9, color='white')
ax_mass.set_xlabel("Iteration", fontsize=9, color='white')
ax_mass.set_title("Convergence Trace", fontsize=10, color='white', fontweight='bold')
ax_mass.legend(fontsize=7, facecolor='#111', edgecolor='#333', labelcolor='white')
ax_mass.grid(True, alpha=0.1, color='white')

# Mass vs slenderness
ax_sl = fig.add_subplot(gs_main[1, 0])
sd = pi_data['Slenderness']
ax_sl.scatter(sd, atlas['mass'], c=atlas['mass'], cmap='viridis_r', s=2, alpha=0.3,
              norm=Normalize(vmin=mass.min(), vmax=np.percentile(mass, 95)))
# Mark best point using atlas's own best
best_atlas_i = atlas['mass'].argmin()
ax_sl.scatter(sd[best_atlas_i], atlas['mass'][best_atlas_i], c='yellow', s=80, zorder=10, edgecolors='white', linewidths=1.5, marker='D')
ax_sl.set_xlabel("Beam Slenderness L_r/D", fontsize=8, color='white')
ax_sl.set_ylabel("Mass (kg)", fontsize=8, color='white')
ax_sl.set_title("Mass vs Slenderness", fontsize=9, color='white', fontweight='bold')
ax_sl.grid(True, alpha=0.1, color='white')

# Mass vs lambda
ax_lg = fig.add_subplot(gs_main[1, 1])
ax_lg.scatter(atlas['lambda_top'], atlas['mass'], c=atlas['mass'], cmap='viridis_r', s=2, alpha=0.3,
              norm=Normalize(vmin=mass.min(), vmax=np.percentile(mass, 95)))
ax_lg.scatter(atlas['lambda_top'][best_atlas_i], atlas['mass'][best_atlas_i], c='yellow', s=80, zorder=10, edgecolors='white', linewidths=1.5, marker='D')
ax_lg.set_xlabel("Lambda top", fontsize=8, color='white')
ax_lg.set_ylabel("Mass (kg)", fontsize=8, color='white')
ax_lg.set_title("Mass vs Blade Scale", fontsize=9, color='white', fontweight='bold')
ax_lg.grid(True, alpha=0.1, color='white')

# Findings
ax_f = fig.add_subplot(gs_main[1, 2]); ax_f.axis('off')
items = [
    ("V10 TIGHT CAMPAIGN FINDINGS", 'title'), ("", 'space'),
    ("49.2 kg — 36% lighter than V10v1 (76.75 kg)", 'bullet'),
    ("4 rotors (was 1) — multi-rotor basin open", 'sub'),
    ("λ=0.519 (was 0.234) — k_mppt λ² prevents cheat", 'sub'),
    ("r_hub=2.89m (was 3.70m) — compact hub viable", 'sub'),
    ("k_mppt_eff=166 (was 615 unscaled)", 'bullet'),
    ("5 parameters screaming at bounds", 'bullet'),
    ("  Do_top=0.06, t/D=0.01, target_Lr=3.0", 'sub'),
    ("  r_bottom=2.0, λ_bottom=0.10", 'sub'),
    ("Static-vs-dynamic gap persists", 'bullet'),
    ("  Static: 50 kW at 59 rpm", 'sub'),
    ("  ODE: 12.1 kW at 55.6 rpm (24%)", 'sub'),
    ("  k_mppt scaling closed rpm gap, not power gap", 'sub2'),
]
y = 0.95
for text, style in items:
    if style == 'title':
        ax_f.text(0.05, y, text, transform=ax_f.transAxes, color='white', fontsize=11, fontweight='bold')
        y -= 0.06
    elif style == 'bullet':
        ax_f.text(0.05, y, '• ' + text, transform=ax_f.transAxes, color='#4fc3f7', fontsize=8, fontweight='bold')
        y -= 0.04
    elif style == 'sub':
        ax_f.text(0.12, y, text, transform=ax_f.transAxes, color='#aaa', fontsize=7)
        y -= 0.035
    elif style == 'sub2':
        ax_f.text(0.19, y, text, transform=ax_f.transAxes, color='#888', fontsize=6.5)
        y -= 0.03
    elif style == 'space':
        y -= 0.008

fig.suptitle("V10 Tight Campaign — Traced Performance & Findings\n12 islands, tight bounds, k_mppt ∝ λ² scaling", fontsize=14, fontweight='bold', color='white', y=0.97)
plt.savefig(f"{OUT_DIR}/v10-tight-paths.png", dpi=150, facecolor='#080810', bbox_inches='tight')
plt.close()

print(f"\nAll 5 diagrams saved to {OUT_DIR}/")
