# scripts/vortex_expansion_analysis.py
import os
import json
import numpy as np
import matplotlib.pyplot as plt

# Aesthetics
plt.style.use('seaborn-v0_8-whitegrid' if 'seaborn-v0_8-whitegrid' in plt.style.available else 'default')
plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.size': 11,
    'axes.labelsize': 12,
    'axes.titlesize': 13,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'figure.dpi': 150,
})

COLORS = {
    'primary': '#0f4c81',
    'secondary': '#f58220',
    'accent': '#00a896',
    'dark': '#2b2b2b',
}

OUT_DIR = "scripts/results/conical_stack"
os.makedirs(OUT_DIR, exist_ok=True)
FIG_DIR = "figures"
os.makedirs(FIG_DIR, exist_ok=True)

# ----------------------------------------------------------------------
# 1. Wind Shear and Radius Sizing Physics
# ----------------------------------------------------------------------
v_ref = 11.0
z_ref = 15.0
alpha = 1/7
omega_rated = 9.02  # rad/s
lambda_opt = 4.15
R_ref = 5.0  # m

heights = np.array([15.0, 30.0, 45.0])
# Hellmann wind shear
v_wind = v_ref * (heights / z_ref)**alpha
# Optimal rotor radius to maintain constant rated TSR & omega
R_opt = lambda_opt * v_wind / omega_rated
# Swept area and power multipliers
area_mult = (R_opt / R_ref)**2
power_mult_wind = (v_wind / v_ref)**3
power_mult_combined = area_mult * power_mult_wind

print("conical stack rotor parameters:")
for idx, (h, v, R, pm) in enumerate(zip(heights, v_wind, R_opt, power_mult_combined)):
    print(f"  Rotor {idx+1}: Height={h:.1f}m | Wind={v:.2f} m/s | Opt Radius={R:.2f}m | Power Mult={pm:.3f}x")

# ----------------------------------------------------------------------
# 2. 1D Wake / Vortex Expansion (Jensen Model)
# ----------------------------------------------------------------------
# Wake decay coefficient (standard onshore value = 0.075)
k_decay = 0.075
# Axial induction factor (a = 1/3 at Betz limit)
a_induction = 1.0 / 3.0

def jensen_wake(x, D):
    # Wake diameter: D_w = D * (1 + 2 * k_decay * x / D)
    # Wake velocity: u(x) = u_0 * (1 - 2 * a_induction / (1 + 2 * k_decay * x / D)^2)
    dw = D * (1.0 + 2.0 * k_decay * x / D)
    u_ratio = 1.0 - 2.0 * a_induction / (1.0 + 2.0 * k_decay * x / D)**2
    return dw, u_ratio

# Spacing between rotors (30m tethers)
x_spacing = 30.0
dw_rot2, u_rot2 = jensen_wake(x_spacing, 2 * R_opt[0])
dw_rot3, u_rot3 = jensen_wake(2 * x_spacing, 2 * R_opt[0])

# ----------------------------------------------------------------------
# 3. Export Summary JSON
# ----------------------------------------------------------------------
summary_data = {
    "physics_constants": {
        "v_ref_mps": v_ref,
        "z_ref_m": z_ref,
        "hellmann_exponent": alpha,
        "omega_rated_rad_s": omega_rated,
        "lambda_opt": lambda_opt,
        "R_ref_m": R_ref
    },
    "rotors": [
        {
            "rotor_idx": i+1,
            "height_m": float(heights[i]),
            "wind_mps": float(v_wind[i]),
            "radius_opt_m": float(R_opt[i]),
            "power_multiplier": float(power_mult_combined[i])
        } for i in range(len(heights))
    ],
    "wake_analysis": {
        "spacing_m": x_spacing,
        "jensen_k_decay": k_decay,
        "axial_induction": a_induction,
        "rotor2_wake_diameter_m": float(dw_rot2),
        "rotor2_velocity_ratio": float(u_rot2),
        "rotor3_wake_diameter_m": float(dw_rot3),
        "rotor3_velocity_ratio": float(u_rot3)
    }
}

json_path = os.path.join(OUT_DIR, "vortex_summary.json")
with open(json_path, 'w') as f:
    json.dump(summary_data, f, indent=4)
print(f"\nSaved summary JSON to: {json_path}")

# ----------------------------------------------------------------------
# 4. Plot Sizing and Wake Profiles
# ----------------------------------------------------------------------
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 5))

# Panel A: Wind Shear & Rotor Sizing
z_continuous = np.linspace(0, 50, 100)
v_continuous = v_ref * (z_continuous / z_ref)**alpha

ax1.plot(v_continuous, z_continuous, color=COLORS['primary'], linewidth=2.0, label='Hellmann Wind Profile')
ax1.scatter(v_wind, heights, color=COLORS['secondary'], s=80, zorder=5, label='Stacked Rotors')

# Draw rotor diameters as horizontal bars at their heights
for i, (h, R) in enumerate(zip(heights, R_opt)):
    ax1.plot([v_wind[i] - R, v_wind[i] + R], [h, h], color=COLORS['dark'], linewidth=4, zorder=4)
    ax1.text(v_wind[i], h + 1.2, f"R={R:.2f}m", ha='center', fontsize=9, fontweight='bold')

ax1.set_title("Conical Stack Rotor Sizing vs. Wind Shear", pad=15)
ax1.set_xlabel("Wind Speed (m/s) / Rotor Span (m scale)")
ax1.set_ylabel("Height Above Ground (m)")
ax1.set_xlim(0, 20)
ax1.set_ylim(0, 55)
ax1.legend(loc='upper left', frameon=True)

# Panel B: Jensen Wake Velocity Recovery
x_distance = np.linspace(0, 100, 100)
_, wake_recovery = jensen_wake(x_distance, 2 * R_ref)

ax2.plot(x_distance, wake_recovery * 100, color=COLORS['accent'], linewidth=2.5, label='Velocity Recovery (%)')
ax2.axvline(x=x_spacing, color='red', linestyle='--', alpha=0.7, label='Rotor 2 Spacing (30m)')
ax2.axvline(x=2*x_spacing, color='orange', linestyle='--', alpha=0.7, label='Rotor 3 Spacing (60m)')

ax2.set_title("Jensen Wake Velocity Recovery vs. Downwind Distance", pad=15)
ax2.set_xlabel("Downwind Distance (m)")
ax2.set_ylabel("Velocity Ratio (%)")
ax2.set_xlim(0, 100)
ax2.set_ylim(30, 105)
ax2.legend(loc='lower right', frameon=True)

plt.tight_layout()
fig.savefig(os.path.join(FIG_DIR, "fig_conical_stack_geometry.png"), dpi=200)
plt.close(fig)
print(f"Generated fig_conical_stack_geometry.png in '{FIG_DIR}/'")
