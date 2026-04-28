import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
import glob, os

repo = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"
worktree = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/.claude/worktrees/sleepy-meninsky-1d9bb0"

def load_islands(base):
    rows = []
    for f in sorted(glob.glob(f"{base}/island_*/best_design.csv")):
        rows.append(pd.read_csv(f))
    return pd.concat(rows, ignore_index=True)

v5 = load_islands(f"{worktree}/scripts/results/trpt_opt_v5")
v4 = load_islands(f"{repo}/scripts/results/trpt_opt_v4")

# Print key facts
v5_10kw = v5[v5['cfg_name'] == '10kw']
v5_50kw = v5[v5['cfg_name'] == '50kw']
v4_10kw = v4[v4['cfg_name'] == '10kw']
v4_50kw = v4[v4['cfg_name'] == '50kw']

winner = v5.loc[v5['best_mass_kg'].idxmin()]
print("v5 winner:", winner[['cfg_name','beam_profile','n_lines','best_mass_kg','min_fos']].to_dict())
print(f"v5 best 10kw mass: {v5_10kw['best_mass_kg'].min():.3f} kg  beam: {v5_10kw.loc[v5_10kw['best_mass_kg'].idxmin(),'beam_profile']}")
print(f"v5 best 50kw mass: {v5_50kw['best_mass_kg'].min():.3f} kg  beam: {v5_50kw.loc[v5_50kw['best_mass_kg'].idxmin(),'beam_profile']}")
print(f"v4 best 10kw mass: {v4_10kw['best_mass_kg'].min():.3f} kg")
print(f"v4 best 50kw mass: {v4_50kw['best_mass_kg'].min():.3f} kg")
print(f"50kw mass reduction v4→v5: {v4_50kw['best_mass_kg'].min()/v5_50kw['best_mass_kg'].min():.2f}×")
print("v5 n_lines distribution:", v5['n_lines'].value_counts().to_dict())
print("v4 n_lines distribution:", v4['n_lines'].value_counts().to_dict())

# Unique mass by beam_profile and config
v5_summary = v5.groupby(['cfg_name','beam_profile'])['best_mass_kg'].min().reset_index()
v4_summary = v4.groupby(['cfg_name','beam_profile'])['best_mass_kg'].min().reset_index()
print("\nv5 best mass by config+beam:\n", v5_summary.to_string(index=False))
print("\nv4 best mass by config+beam:\n", v4_summary.to_string(index=False))

# Fig 1: mass by beam_profile for v4 vs v5, split by config
fig, axes = plt.subplots(1, 2, figsize=(11, 5))
beam_order = ['circular', 'elliptical', 'airfoil']
colors_v4 = '#aaaaaa'
colors_v5 = '#1a6b9a'
x = range(len(beam_order))

for ax, cfg in zip(axes, ['10kw', '50kw']):
    df4 = v4_summary[v4_summary['cfg_name'] == cfg].set_index('beam_profile')['best_mass_kg']
    df5 = v5_summary[v5_summary['cfg_name'] == cfg].set_index('beam_profile')['best_mass_kg']
    bars4 = [df4.get(b, float('nan')) for b in beam_order]
    bars5 = [df5.get(b, float('nan')) for b in beam_order]
    width = 0.35
    xi = list(range(len(beam_order)))
    ax.bar([i - width/2 for i in xi], bars4, width, label='v4 (fixed CT)', color=colors_v4, edgecolor='white')
    ax.bar([i + width/2 for i in xi], bars5, width, label='v5 (BEM-coupled)', color=colors_v5, edgecolor='white')
    ax.set_xticks(xi)
    ax.set_xticklabels(beam_order)
    ax.set_title(f'{cfg}: mass by beam profile')
    ax.set_ylabel('Best mass (kg)')
    ax.legend()

plt.suptitle('v4 (fixed CT) vs v5 (BEM-coupled): structural mass by beam profile', fontsize=12)
plt.tight_layout()
plt.savefig(f'{repo}/figures/fig_v5_nlines_vs_v4.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 1 saved.")

# Fig 2: scatter — v4 vs v5 mass by beam_profile, all islands
fig, ax = plt.subplots(figsize=(8, 5))
bp_colors = {'circular': '#2196F3', 'elliptical': '#4CAF50', 'airfoil': '#FF5722'}
for bp in beam_order:
    v4_bp = v4[v4['beam_profile'] == bp]
    v5_bp = v5[v5['beam_profile'] == bp]
    ax.scatter(v4_bp['best_mass_kg'], v5_bp['best_mass_kg'].values[:len(v4_bp)],
               alpha=0.7, label=bp, color=bp_colors[bp], s=40)

lims = [min(ax.get_xlim()[0], ax.get_ylim()[0]),
        max(ax.get_xlim()[1], ax.get_ylim()[1])]
ax.plot(lims, lims, 'k--', alpha=0.4, lw=1, label='v4=v5')
ax.set_xlabel('v4 mass (kg)')
ax.set_ylabel('v5 mass (kg)')
ax.set_title('v4 vs v5 structural mass — BEM coupling effect by beam profile')
ax.legend()
plt.tight_layout()
plt.savefig(f'{repo}/figures/fig_v5_mass_vs_nlines.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 2 saved.")
