#!/usr/bin/env python3
"""
generate_rich_figures.py — Phase 2.5 rich figure set for TRPT AWES
Generates funder/engineer-quality figures from all available campaign data.

Figures produced:
  fig01_phi_scaling_cliff.pdf/png       — THE main result: φ vs power, all versions
  fig02_version_progression_10kw.pdf    — campaign evolution 10kW ladder
  fig03_v5_landscape_10kw.pdf           — 60-island mass histogram (10kW islands)
  fig04_v5_landscape_50kw.pdf           — 60-island mass histogram (50kW islands)
  fig05_v4_vs_v5_50kw.pdf               — head-to-head: V4 79.5 kg vs V5 39.3 kg
  fig06_design_consensus.pdf            — key design variables all islands agree on
  fig07_v5_design_comparison.pdf        — 10kW vs 50kW design dimension comparison
  fig08_scaling_ratio_history.pdf       — how φ(50)/φ(10) evolved v3→v5
  fig09_v5_island_convergence.pdf       — log-scale convergence quality
  fig10_expansion_model_status.pdf      — expansion sweep: zero-variance diagnosis

Usage:
  /usr/bin/python3 scripts/generate_rich_figures.py
"""

import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.ticker as ticker
import os
import sys

# ── Paths ─────────────────────────────────────────────────────────────────────
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS = os.path.join(REPO, 'scripts', 'results')
FIGURES = os.path.join(REPO, 'scripts', 'figures')
os.makedirs(FIGURES, exist_ok=True)

# ── Style ──────────────────────────────────────────────────────────────────────
COLORS = {
    'v3': '#d62728',
    'v4': '#ff7f0e',
    'v5': '#2ca02c',
    'v6': '#9467bd',
    '10kw': '#1f77b4',
    '50kw': '#d62728',
    'grey': '#7f7f7f',
    'grid': '#e8e8e8',
}

def style_axes(ax, grid=True):
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#bbbbbb')
    ax.spines['bottom'].set_color('#bbbbbb')
    if grid:
        ax.yaxis.grid(True, color=COLORS['grid'], linewidth=0.8, zorder=0)
        ax.set_axisbelow(True)

def save_fig(fig, name, dpi=180):
    pdf_path = os.path.join(FIGURES, name + '.pdf')
    png_path = os.path.join(FIGURES, name + '.png')
    fig.savefig(pdf_path, bbox_inches='tight')
    fig.savefig(png_path, dpi=dpi, bbox_inches='tight')
    plt.close(fig)
    print(f"  ✓ {name}.pdf / .png")

# ── Load data ─────────────────────────────────────────────────────────────────
def load_v5_islands():
    rows = []
    for i in range(1, 61):
        idir = os.path.join(RESULTS, f'trpt_opt_v5/island_{i:02d}')
        if os.path.exists(idir):
            d = pd.read_csv(os.path.join(idir, 'best_design.csv'))
            rows.append(d)
    return pd.concat(rows, ignore_index=True)

def load_v4_islands():
    rows = []
    for i in range(1, 61):
        idir = os.path.join(RESULTS, f'trpt_opt_v4/island_{i:02d}')
        if os.path.exists(idir):
            for f in os.listdir(idir):
                if f.endswith('.csv') and 'best' in f.lower():
                    d = pd.read_csv(os.path.join(idir, f))
                    d['island'] = i
                    rows.append(d)
    return pd.concat(rows, ignore_index=True)

print("Loading campaign data...")
v5_all = load_v5_islands()
v4_all = load_v4_islands()
exp_df = pd.read_csv(os.path.join(RESULTS, 'expansion_sweep.csv'))

v5_10 = v5_all[v5_all['cfg_name'] == '10kw']
v5_50 = v5_all[v5_all['cfg_name'] == '50kw']
v4_10 = v4_all[v4_all['cfg_name'] == '10kw']
v4_50 = v4_all[v4_all['cfg_name'] == '50kw']
print(f"  V5: {len(v5_10)} 10kW islands, {len(v5_50)} 50kW islands")
print(f"  V4: {len(v4_10)} 10kW islands, {len(v4_50)} 50kW islands")


# ════════════════════════════════════════════════════════════════════════════════
# FIG 01 — THE MAIN RESULT: φ vs power class, all versions
# Shows the torsional scaling cliff in V3/V4 and V5 breaking it
# ════════════════════════════════════════════════════════════════════════════════
print("\nGenerating fig01_phi_scaling_cliff ...")
fig, ax = plt.subplots(figsize=(8, 5.5))

data = {
    'V3': {10: 15.435/10, 50: 145.881/50},
    'V4': {10: v4_10['best_mass_kg'].min()/10, 50: v4_50['best_mass_kg'].min()/50},
    'V5': {10: v5_10['best_mass_kg'].min()/10, 50: v5_50['best_mass_kg'].min()/50},
}
powers = [10, 50]
xpos = [0, 1]
markers = {'V3': 's', 'V4': 'D', 'V5': 'o'}
ver_colors = {'V3': COLORS['v3'], 'V4': COLORS['v4'], 'V5': COLORS['v5']}

for ver, d in data.items():
    ys = [d[p] for p in powers]
    ax.plot(xpos, ys, marker=markers[ver], linewidth=2.2, markersize=9,
            color=ver_colors[ver], label=ver, zorder=3)
    for xi, yi in zip(xpos, ys):
        ax.annotate(f'{yi:.3f}', xy=(xi, yi), xytext=(8, 4),
                    textcoords='offset points', fontsize=9,
                    color=ver_colors[ver], fontweight='bold')

# Shade V5 improvement region
ax.fill_between([0, 1],
                [data['V3'][10], data['V3'][50]],
                [data['V5'][10], data['V5'][50]],
                alpha=0.07, color=COLORS['v5'])

# Annotate the cliff direction
ax.annotate('', xy=(0.95, data['V3'][50]),
            xytext=(0.95, data['V5'][50] + 0.05),
            arrowprops=dict(arrowstyle='<->', color='#555555', lw=1.5))
ax.text(0.97, (data['V3'][50] + data['V5'][50])/2 + 0.1,
        f'−{(1 - data["V5"][50]/data["V3"][50])*100:.0f}%\nat 50 kW',
        fontsize=9, color='#333333', ha='left', va='center')

ax.set_xticks(xpos)
ax.set_xticklabels(['10 kW', '50 kW'], fontsize=12)
ax.set_ylabel('Specific airborne mass  φ  (kg kW⁻¹)', fontsize=11)
ax.set_title('TRPT System Mass-per-Power vs Rated Power Class\n'
             'V5 breaks the torsional scaling cliff', fontsize=12, fontweight='bold')
ax.legend(loc='upper left', fontsize=10, framealpha=0.9)

# Add "cliff" annotation for V3/V4
ax.annotate('Scaling cliff:\nφ worsens with scale', xy=(0.5, (data['V3'][10]+data['V3'][50])/2),
            xytext=(0.3, 2.6), fontsize=8.5, color=COLORS['v3'],
            arrowprops=dict(arrowstyle='->', color=COLORS['v3'], lw=1.2))
ax.annotate('V5 breakthrough:\nφ improves with scale', xy=(0.5, (data['V5'][10]+data['V5'][50])/2),
            xytext=(0.55, 0.55), fontsize=8.5, color=COLORS['v5'],
            arrowprops=dict(arrowstyle='->', color=COLORS['v5'], lw=1.2))

ax.set_ylim(0, 3.4)
ax.set_xlim(-0.15, 1.25)
style_axes(ax)
fig.tight_layout()
save_fig(fig, 'fig01_phi_scaling_cliff')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 02 — Version progression 10 kW (campaign evolution ladder)
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig02_version_progression_10kw ...")
fig, ax = plt.subplots(figsize=(7, 4.5))

versions = ['V3\n(2022)', 'V4\n(2023)', 'V5\n(2024)']
masses = [15.435, v4_10['best_mass_kg'].min(), v5_10['best_mass_kg'].min()]
clrs = [COLORS['v3'], COLORS['v4'], COLORS['v5']]
xp = [0, 1, 2]

bars = ax.bar(xp, masses, color=clrs, width=0.55, zorder=3, alpha=0.85, edgecolor='white', linewidth=1.5)

for x, m, c in zip(xp, masses, clrs):
    ax.text(x, m + 0.3, f'{m:.2f} kg\nφ={m/10:.3f}', ha='center', va='bottom',
            fontsize=10, color=c, fontweight='bold')

# Draw improvement arrows
for i in range(len(masses)-1):
    pct = (masses[i] - masses[i+1]) / masses[i] * 100
    ax.annotate(f'−{pct:.1f}%',
                xy=((xp[i]+xp[i+1])/2, (masses[i]+masses[i+1])/2),
                ha='center', va='center', fontsize=9, color='#333333',
                bbox=dict(boxstyle='round,pad=0.2', facecolor='white', alpha=0.8, edgecolor='#cccccc'))

ax.set_xticks(xp)
ax.set_xticklabels(versions, fontsize=11)
ax.set_ylabel('Minimum airborne mass (kg) at 10 kW', fontsize=11)
ax.set_title('TRPT Optimisation Campaign Progression — 10 kW Target', fontsize=12, fontweight='bold')
ax.set_ylim(0, 20)
style_axes(ax)
fig.tight_layout()
save_fig(fig, 'fig02_version_progression_10kw')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 03 — V5 optimisation landscape: 10 kW (60 islands)
# Shows bi-modal distribution and tight convergence of good basin
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig03_v5_landscape_10kw ...")
fig, ax = plt.subplots(figsize=(7, 4.5))

masses_10 = v5_10['best_mass_kg'].sort_values().values
ax.scatter(range(len(masses_10)), masses_10, c=[COLORS['10kw'] if m < 20 else COLORS['v3'] for m in masses_10],
           s=60, zorder=3, edgecolors='white', linewidth=0.5)

ax.axhline(masses_10.min(), color=COLORS['10kw'], linestyle='--', linewidth=1.5,
           label=f'Best: {masses_10.min():.2f} kg (φ={masses_10.min()/10:.3f} kg/kW)')
ax.axhline(masses_10.max(), color=COLORS['v3'], linestyle=':', linewidth=1.5,
           label=f'Local optimum: {masses_10.max():.2f} kg')

converged = np.sum(masses_10 < 20)
ax.text(0.98, 0.95, f'{converged}/{len(masses_10)} islands\nfound global basin',
        ha='right', va='top', transform=ax.transAxes, fontsize=10,
        bbox=dict(boxstyle='round', facecolor=COLORS['10kw'], alpha=0.15))

ax.set_xlabel('Island index (sorted by final mass)', fontsize=11)
ax.set_ylabel('Final best mass (kg)', fontsize=11)
ax.set_title('V5 Optimisation Landscape — 10 kW\n60 independent DE islands', fontsize=12, fontweight='bold')
ax.legend(fontsize=9, loc='center left')
ax.set_ylim(0, 100)
style_axes(ax)
fig.tight_layout()
save_fig(fig, 'fig03_v5_landscape_10kw')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 04 — V5 optimisation landscape: 50 kW
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig04_v5_landscape_50kw ...")
fig, ax = plt.subplots(figsize=(7, 4.5))

masses_50 = v5_50['best_mass_kg'].sort_values().values
ax.scatter(range(len(masses_50)), masses_50,
           c=[COLORS['50kw'] if m < 200 else '#555555' for m in masses_50],
           s=60, zorder=3, edgecolors='white', linewidth=0.5)

ax.axhline(masses_50.min(), color=COLORS['50kw'], linestyle='--', linewidth=1.5,
           label=f'Best: {masses_50.min():.2f} kg (φ={masses_50.min()/50:.3f} kg/kW)')
ax.axhline(masses_50.max(), color='#555555', linestyle=':', linewidth=1.5,
           label=f'Stuck: {masses_50.max():.2f} kg (φ={masses_50.max()/50:.2f} kg/kW)')

converged_50 = np.sum(masses_50 < 200)
ax.text(0.98, 0.95, f'{converged_50}/{len(masses_50)} islands\nfound global basin',
        ha='right', va='top', transform=ax.transAxes, fontsize=10,
        bbox=dict(boxstyle='round', facecolor=COLORS['50kw'], alpha=0.15))

ax.set_xlabel('Island index (sorted by final mass)', fontsize=11)
ax.set_ylabel('Final best mass (kg)', fontsize=11)
ax.set_title('V5 Optimisation Landscape — 50 kW\n60 independent DE islands', fontsize=12, fontweight='bold')
ax.legend(fontsize=9, loc='center left')
style_axes(ax)
fig.tight_layout()
save_fig(fig, 'fig04_v5_landscape_50kw')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 05 — V4 vs V5 at 50 kW: head-to-head
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig05_v4_vs_v5_50kw ...")
fig, axes = plt.subplots(1, 2, figsize=(9, 4.5))

for ax, (ver, df, clr) in zip(axes, [('V4', v4_50, COLORS['v4']), ('V5', v5_50, COLORS['v5'])]):
    masses = df['best_mass_kg'].sort_values().values
    ax.bar(range(len(masses)), masses, color=clr, alpha=0.75, zorder=3, width=0.7)
    ax.axhline(masses.min(), color=clr, linestyle='--', linewidth=2,
               label=f'Min: {masses.min():.1f} kg\nφ={masses.min()/50:.3f} kg/kW')
    ax.set_title(f'{ver} — 50 kW\n60 islands', fontsize=11, fontweight='bold')
    ax.set_ylabel('Final mass (kg)')
    ax.set_xlabel('Island (sorted)')
    ax.legend(fontsize=9, loc='upper left')
    style_axes(ax)

# Add improvement callout
axes[1].text(0.95, 0.50,
             f'V4→V5 improvement:\n'
             f'−{(1 - v5_50["best_mass_kg"].min()/v4_50["best_mass_kg"].min())*100:.0f}% mass\n'
             f'at 50 kW',
             ha='right', va='center', transform=axes[1].transAxes, fontsize=10,
             color=COLORS['v5'], fontweight='bold',
             bbox=dict(boxstyle='round', facecolor='white', alpha=0.9, edgecolor=COLORS['v5']))

fig.suptitle('V4 vs V5: 50 kW Optimisation — Island Final Masses', fontsize=12, fontweight='bold')
fig.tight_layout()
save_fig(fig, 'fig05_v4_vs_v5_50kw')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 06 — Design variable consensus across all V5 islands
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig06_design_consensus ...")
fig, axes = plt.subplots(2, 3, figsize=(11, 6.5))

vars_10kw = v5_10[['r_hub_m', 'r_bottom_m', 'Do_top_m', 't_over_D', 'Do_scale_exp', 'knuckle_kg']].values
vars_50kw = v5_50[['r_hub_m', 'r_bottom_m', 'Do_top_m', 't_over_D', 'Do_scale_exp', 'knuckle_kg']].values
var_names = ['Hub radius r_hub (m)', 'Ground radius r_bottom (m)',
             'Top beam diameter Do_top (m)', 'Wall ratio t/D',
             'Diameter taper exponent', 'Knuckle mass (kg)']

for idx, (ax, vname) in enumerate(zip(axes.flat, var_names)):
    v10 = vars_10kw[:, idx]
    v50 = vars_50kw[:, idx]

    bins = np.linspace(min(v10.min(), v50.min()) - 1e-6,
                       max(v10.max(), v50.max()) + 1e-6, 15)
    ax.hist(v10, bins=bins, alpha=0.6, color=COLORS['10kw'], label='10 kW', zorder=3)
    ax.hist(v50, bins=bins, alpha=0.6, color=COLORS['50kw'], label='50 kW', zorder=3)
    ax.set_title(vname, fontsize=9, fontweight='bold')
    ax.set_ylabel('Count')
    style_axes(ax, grid=False)

    # Show CV
    if v10.std() < 1e-8:
        ax.text(0.5, 0.85, '10kW: unanimous', ha='center', va='top',
                transform=ax.transAxes, fontsize=7.5, color=COLORS['10kw'],
                bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))

axes.flat[0].legend(fontsize=8, loc='upper right')
fig.suptitle('V5 Design Variable Distributions — 10 kW vs 50 kW Islands\n'
             'Tight clustering = robust optimum; spread = scale-dependent choice',
             fontsize=11, fontweight='bold')
fig.tight_layout()
save_fig(fig, 'fig06_design_consensus')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 07 — V5 10kW vs 50kW optimal design comparison (bar chart)
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig07_v5_design_comparison ...")
fig, ax = plt.subplots(figsize=(8, 5))

best_10 = v5_10.sort_values('best_mass_kg').iloc[0]
best_50 = v5_50.sort_values('best_mass_kg').iloc[0]

params = ['r_hub (m)', 'r_bottom (m)', 'Do_top (m)', 't/D (×10)', 'Do_scale_exp']
vals_10 = [best_10['r_hub_m'], best_10['r_bottom_m'], best_10['Do_top_m'],
           best_10['t_over_D']*10, best_10['Do_scale_exp']]
vals_50 = [best_50['r_hub_m'], best_50['r_bottom_m'], best_50['Do_top_m'],
           best_50['t_over_D']*10, best_50['Do_scale_exp']]

x = np.arange(len(params))
w = 0.35
b1 = ax.bar(x - w/2, vals_10, w, label=f'10 kW  (m={best_10["best_mass_kg"]:.1f} kg)',
            color=COLORS['10kw'], alpha=0.82, zorder=3, edgecolor='white')
b2 = ax.bar(x + w/2, vals_50, w, label=f'50 kW  (m={best_50["best_mass_kg"]:.1f} kg)',
            color=COLORS['50kw'], alpha=0.82, zorder=3, edgecolor='white')

for bar in list(b1) + list(b2):
    h = bar.get_height()
    ax.text(bar.get_x() + bar.get_width()/2, h + 0.01, f'{h:.3f}',
            ha='center', va='bottom', fontsize=7.5, rotation=45)

ax.set_xticks(x)
ax.set_xticklabels(params, fontsize=10)
ax.set_ylabel('Parameter value (see labels)', fontsize=10)
ax.set_title('V5 Optimal Design Parameters — 10 kW vs 50 kW\n'
             '(t/D shown ×10 for visibility)', fontsize=11, fontweight='bold')
ax.legend(fontsize=10)
style_axes(ax)
fig.tight_layout()
save_fig(fig, 'fig07_v5_design_comparison')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 08 — Scaling ratio evolution: φ(50kW)/φ(10kW) across versions
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig08_scaling_ratio_history ...")
fig, ax = plt.subplots(figsize=(7, 4.5))

ver_labels = ['V3\n(2022)', 'V4\n(2023)', 'V5\n(2024)']
phi_10 = [15.435/10, v4_10['best_mass_kg'].min()/10, v5_10['best_mass_kg'].min()/10]
phi_50 = [145.881/50, v4_50['best_mass_kg'].min()/50, v5_50['best_mass_kg'].min()/50]
ratios = [p50/p10 for p10, p50 in zip(phi_10, phi_50)]

clrs_bar = [COLORS['v3'], COLORS['v4'], COLORS['v5']]
bars = ax.bar(range(3), ratios, color=clrs_bar, width=0.5, zorder=3, alpha=0.82, edgecolor='white')

ax.axhline(1.0, color='#333333', linewidth=1.5, linestyle='--', zorder=4,
           label='φ(50 kW) = φ(10 kW)  (neutral scaling)')
ax.fill_between([-0.5, 2.5], [1.0, 1.0], [0, 0], alpha=0.08, color=COLORS['v5'], label='Beneficial scaling regime')

for x, r, c in zip(range(3), ratios, clrs_bar):
    label = f'{r:.2f}×' if r > 1 else f'{r:.2f}×\n(better at scale!)'
    ax.text(x, r + 0.03, label, ha='center', va='bottom', fontsize=10,
            color=c, fontweight='bold')

ax.set_xticks(range(3))
ax.set_xticklabels(ver_labels, fontsize=11)
ax.set_ylabel('Scaling ratio  φ(50 kW) / φ(10 kW)', fontsize=11)
ax.set_title('Torsional Scaling Cliff Progress\nφ ratio < 1.0 = system improves at scale', fontsize=12, fontweight='bold')
ax.legend(fontsize=9, loc='upper right')
ax.set_ylim(0, 3.5)
style_axes(ax)
fig.tight_layout()
save_fig(fig, 'fig08_scaling_ratio_history')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 09 — V5 island convergence quality (evaluations vs final mass)
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig09_v5_island_convergence ...")
fig, axes = plt.subplots(1, 2, figsize=(10, 4.5))

for ax, (cfg, df, clr, power) in zip(axes, [
    ('10 kW', v5_10, COLORS['10kw'], 10),
    ('50 kW', v5_50, COLORS['50kw'], 50),
]):
    if 'evaluations' in df.columns and 'elapsed_s' in df.columns:
        sc = ax.scatter(df['evaluations']/1e6, df['best_mass_kg'],
                        c=df['elapsed_s']/3600, cmap='viridis', s=60, zorder=3,
                        edgecolors='white', linewidth=0.5)
        plt.colorbar(sc, ax=ax, label='Elapsed (h)')
    else:
        ax.scatter(range(len(df)), df['best_mass_kg'].sort_values(),
                   c=clr, s=60, zorder=3)
    ax.set_xlabel('Objective evaluations (×10⁶)', fontsize=10)
    ax.set_ylabel('Final mass (kg)', fontsize=10)
    ax.set_title(f'V5 {cfg} Islands\nFinal mass vs. evaluations', fontsize=10, fontweight='bold')
    style_axes(ax)

fig.suptitle('V5 Convergence Quality — 60 Islands per Power Class', fontsize=12, fontweight='bold')
fig.tight_layout()
save_fig(fig, 'fig09_v5_island_convergence')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 10 — Expansion rotor model status: zero-variance diagnosis
# This is an honest accounting of where v6 stands
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig10_expansion_model_status ...")
fig, axes = plt.subplots(1, 3, figsize=(12, 4.5))

# Panel A: phi vs n_expansion at min phi (shows monotonic dead-weight increase)
ax = axes[0]
for pw, clr, ls in [(10, COLORS['10kw'], '-'), (20, '#ff7f0e', '--'), (50, COLORS['50kw'], ':')]:
    sub = exp_df[exp_df['power_kw'] == pw].groupby('n_expansion')['phi_kg_per_kw'].min()
    ax.plot(sub.index, sub.values, marker='o', color=clr, linestyle=ls,
            linewidth=2, label=f'{pw} kW')
ax.set_xlabel('Number of expansion rotors', fontsize=10)
ax.set_ylabel('Min φ (kg kW⁻¹)', fontsize=10)
ax.set_title('φ monotonically increases\nwith n_expansion', fontsize=10, fontweight='bold')
ax.legend(fontsize=9)
style_axes(ax)

# Panel B: phi vs blade_radius for n_expansion=2 — should vary but is flat
ax = axes[1]
sub = exp_df[(exp_df['n_expansion'] == 2) & (exp_df['power_kw'] == 20)]
for ba in [5, 15, 25]:
    s2 = sub[sub['bridle_angle_deg'] == ba]
    ax.plot(s2['blade_radius_m'].values, s2['phi_kg_per_kw'].values,
            marker='o', label=f'bridle={ba}°', linewidth=1.5)
ax.set_xlabel('Blade radius (m)', fontsize=10)
ax.set_ylabel('φ (kg kW⁻¹)', fontsize=10)
ax.set_title('φ vs blade_radius (20 kW, n_exp=2)\nFlat = no aerodynamic feedback', fontsize=10, fontweight='bold')
ax.legend(fontsize=8)
ax.set_ylim(exp_df[(exp_df['power_kw']==20)]['phi_kg_per_kw'].min() - 0.05,
            exp_df[(exp_df['power_kw']==20)]['phi_kg_per_kw'].min() + 0.15)
style_axes(ax)

# Panel C: mass_expansion_kg vs n_expansion — should scale with blade geometry
ax = axes[2]
sub = exp_df[exp_df['power_kw'] == 10].groupby(['n_expansion','blade_radius_m'])['mass_expansion_kg'].mean().reset_index()
for br in sorted(sub['blade_radius_m'].unique()):
    s2 = sub[sub['blade_radius_m'] == br]
    ax.plot(s2['n_expansion'], s2['mass_expansion_kg'], marker='o', label=f'r={br} m', linewidth=1.5)
ax.set_xlabel('n_expansion', fontsize=10)
ax.set_ylabel('Expansion mass (kg)', fontsize=10)
ax.set_title('Expansion mass = n × 0.5 kg fixed\n(geometry-independent)', fontsize=10, fontweight='bold')
ax.legend(fontsize=8, title='Blade radius')
style_axes(ax)

fig.suptitle('Expansion Rotor Model Status (V6)\n'
             'Current: fixed dead-weight penalty only — aerodynamic benefit not yet modelled',
             fontsize=11, fontweight='bold', color='#8B0000')
fig.tight_layout()
save_fig(fig, 'fig10_expansion_model_status')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 11 — The TRPT φ numbers in context vs conventional wind turbines
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig11_trpt_in_context ...")
fig, ax = plt.subplots(figsize=(8.5, 5))

# Reference data (approximate, from literature) — airborne mass / rated power
# For wind turbines: nacelle+rotor mass per rated power ~ 50-200 kg/kW for small, 15-40 for utility
# For TRPT: we have the actual data
# AWE systems literature: kitepower ~ 3 kg/kW, Skysails ~5 kg/kW (rough estimates)
categories = [
    ('Utility WT\nnacelle (typical)', 25, '#aaaaaa', ''),
    ('Small WT\n(< 50 kW)', 90, '#cccccc', ''),
    ('TRPT V3\n(10 kW)', 15.435/10, COLORS['v3'], '★'),
    ('TRPT V4\n(10 kW)', v4_10['best_mass_kg'].min()/10, COLORS['v4'], '★'),
    ('TRPT V5\n(10 kW)', v5_10['best_mass_kg'].min()/10, COLORS['v5'], '★'),
    ('TRPT V5\n(50 kW)', v5_50['best_mass_kg'].min()/50, COLORS['v5'], '★'),
]

xs = range(len(categories))
for xi, (label, val, clr, marker) in enumerate(categories):
    ax.bar(xi, val, color=clr, alpha=0.8, zorder=3, width=0.6, edgecolor='white')
    ax.text(xi, val + 1, f'{val:.2f}', ha='center', va='bottom', fontsize=9,
            fontweight='bold', color=clr)

ax.set_xticks(xs)
ax.set_xticklabels([c[0] for c in categories], fontsize=9.5)
ax.set_ylabel('Airborne mass per rated power (kg kW⁻¹)', fontsize=11)
ax.set_title('TRPT vs Conventional Wind: Specific Airborne Mass\n'
             'TRPT airborne mass 15–70× lower per kW than small wind turbines',
             fontsize=11, fontweight='bold')

ax.annotate('Wind turbine\n(reference only)', xy=(1, 25), xytext=(1.5, 60),
            arrowprops=dict(arrowstyle='->', color='#888888'), fontsize=8.5, color='#888888')
ax.text(3.5, 1.5, 'TRPT results\n(this work)', ha='center', fontsize=9,
        color=COLORS['v5'], fontweight='bold',
        bbox=dict(boxstyle='round', facecolor='white', alpha=0.8, edgecolor=COLORS['v5']))

style_axes(ax)
fig.tight_layout()
save_fig(fig, 'fig11_trpt_in_context')


# ════════════════════════════════════════════════════════════════════════════════
# FIG 12 — Two-panel summary: the pitch for funders
# Left: φ scaling story. Right: route to higher powers.
# ════════════════════════════════════════════════════════════════════════════════
print("Generating fig12_funder_summary ...")
fig, axes = plt.subplots(1, 2, figsize=(12, 5))

# LEFT: φ trajectory across versions and scales
ax = axes[0]
vers = ['V3', 'V4', 'V5']
phi_10_vals = [15.435/10, v4_10['best_mass_kg'].min()/10, v5_10['best_mass_kg'].min()/10]
phi_50_vals = [145.881/50, v4_50['best_mass_kg'].min()/50, v5_50['best_mass_kg'].min()/50]

xi = np.arange(len(vers))
w = 0.35
ax.bar(xi - w/2, phi_10_vals, w, label='10 kW', color=COLORS['10kw'], alpha=0.8, zorder=3)
ax.bar(xi + w/2, phi_50_vals, w, label='50 kW', color=COLORS['50kw'], alpha=0.8, zorder=3)

for i, (p10, p50) in enumerate(zip(phi_10_vals, phi_50_vals)):
    ax.text(i - w/2, p10 + 0.03, f'{p10:.2f}', ha='center', va='bottom', fontsize=8.5,
            color=COLORS['10kw'])
    ax.text(i + w/2, p50 + 0.03, f'{p50:.2f}', ha='center', va='bottom', fontsize=8.5,
            color=COLORS['50kw'])

# V5 outperforms V4 at 50kW — draw attention
ax.annotate('', xy=(2 + w/2, phi_50_vals[2] + 0.05),
            xytext=(1 + w/2, phi_50_vals[1] + 0.05),
            arrowprops=dict(arrowstyle='->', color='#333333', lw=1.5))
ax.text(2.0, 1.75, f'−{(1-phi_50_vals[2]/phi_50_vals[1])*100:.0f}% at 50 kW\nV4→V5',
        ha='center', fontsize=8.5, color='#333333')

ax.set_xticks(xi)
ax.set_xticklabels(['V3\n(2022)', 'V4\n(2023)', 'V5\n(2024)'], fontsize=10)
ax.set_ylabel('φ — specific mass (kg kW⁻¹)', fontsize=10)
ax.set_title('Specific Mass by Version & Power Class', fontsize=11, fontweight='bold')
ax.legend(fontsize=9)
ax.set_ylim(0, 3.4)
style_axes(ax)

# RIGHT: mass vs power — showing V5 scale economy
ax = axes[1]
powers_model = np.array([10, 50])
masses_v3 = np.array([15.435, 145.881])
masses_v4 = np.array([v4_10['best_mass_kg'].min(), v4_50['best_mass_kg'].min()])
masses_v5 = np.array([v5_10['best_mass_kg'].min(), v5_50['best_mass_kg'].min()])

ax.plot(powers_model, masses_v3, 's--', color=COLORS['v3'], linewidth=2, markersize=8, label='V3')
ax.plot(powers_model, masses_v4, 'D--', color=COLORS['v4'], linewidth=2, markersize=8, label='V4')
ax.plot(powers_model, masses_v5, 'o-', color=COLORS['v5'], linewidth=2.5, markersize=9, label='V5 ✓')

# Fit power law for V5
coeffs = np.polyfit(np.log(powers_model), np.log(masses_v5), 1)
alpha = coeffs[0]
p_ext = np.linspace(5, 100, 100)
m_ext = np.exp(np.polyval(coeffs, np.log(p_ext)))
ax.plot(p_ext, m_ext, '--', color=COLORS['v5'], linewidth=1, alpha=0.5)
ax.text(75, m_ext[-1]*1.1, f'm ∝ P^{alpha:.2f}', fontsize=9, color=COLORS['v5'])

ax.set_xlabel('Rated power (kW)', fontsize=10)
ax.set_ylabel('Airborne mass (kg)', fontsize=10)
ax.set_title('Mass vs Power Scaling\n(dotted = power-law extrapolation)', fontsize=11, fontweight='bold')
ax.legend(fontsize=9)
ax.set_xscale('log')
ax.set_yscale('log')
ax.xaxis.set_major_formatter(ticker.ScalarFormatter())
ax.yaxis.set_major_formatter(ticker.ScalarFormatter())
style_axes(ax)

fig.suptitle('TRPT Airborne Wind Energy System — Research Progress Summary', fontsize=13, fontweight='bold')
fig.tight_layout()
save_fig(fig, 'fig12_funder_summary')


print(f"\n✓ All figures written to {FIGURES}")
print("Files generated:")
for f in sorted(os.listdir(FIGURES)):
    if not f.startswith('.'):
        size = os.path.getsize(os.path.join(FIGURES, f))
        print(f"  {f} ({size//1024} kB)")
