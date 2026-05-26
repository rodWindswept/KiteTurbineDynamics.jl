# scripts/reconstruct_lift_kite_figures.py
import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# Aesthetics setup
plt.style.use('seaborn-v0_8-whitegrid' if 'seaborn-v0_8-whitegrid' in plt.style.available else 'default')
plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.size': 11,
    'axes.labelsize': 12,
    'axes.titlesize': 13,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'figure.titlesize': 14,
    'figure.dpi': 150,
})

# Harmonious color palette
COLORS = {
    'primary': '#0f4c81',      # Classic blue
    'secondary': '#f58220',    # Orange
    'accent': '#00a896',       # Teal
    'dark': '#2b2b2b',         # Charcoal
    'light': '#f7f7f7',        # Cool light gray
    'single': '#1f77b4',
    'stack': '#2ca02c',
    'rotary': '#d62728',
    'nolift': '#7f7f7f'
}

OUT_DIR = "figures"
os.makedirs(OUT_DIR, exist_ok=True)
DATA_DIR = "scripts/results/lift_kite"

# ----------------------------------------------------------------------
# Fig 2: Dynamic Pressure Parabola (q vs v)
# ----------------------------------------------------------------------
def generate_fig2():
    print("Generating fig2_dynamic_pressure.png...")
    v = np.linspace(0, 20, 100)
    rho = 1.225
    q = 0.5 * rho * v**2
    
    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.plot(v, q, color=COLORS['primary'], linewidth=2.5, label=r'$q = \frac{1}{2}\rho v^2$')
    ax.fill_between(v, q, color=COLORS['primary'], alpha=0.1)
    
    ax.set_title("Dynamic Pressure ($q$) vs. Wind Speed ($v$)", pad=15)
    ax.set_xlabel("Wind Speed (m/s)")
    ax.set_ylabel("Dynamic Pressure (Pa)")
    ax.set_xlim(0, 20)
    ax.set_ylim(0, 260)
    ax.legend(loc='upper left', frameon=True)
    
    plt.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "fig2_dynamic_pressure.png"), dpi=200)
    plt.close(fig)

# ----------------------------------------------------------------------
# Fig 3: Force Balance (Vertical Lift vs Wind Speed)
# ----------------------------------------------------------------------
def generate_fig3():
    print("Generating fig3_force_balance.png...")
    v = np.linspace(6, 16, 50)
    # Required hub vertical force: airborne weight (245 N) + vertical component of rotor thrust
    # T_rotor = 0.5 * rho * v^2 * pi * R^2 * CT * cos^2(beta)
    # T_shaft_vertical = T_rotor * sin(beta)
    rho = 1.225
    R = 5.0
    beta = np.radians(30)
    CT = 0.548
    W_airborne = 245.0  # N
    
    t_rotor = 0.5 * rho * v**2 * np.pi * R**2 * CT * np.cos(beta)**2
    f_vert_thrust = t_rotor * np.sin(beta)
    f_req_total = W_airborne + f_vert_thrust
    
    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.plot(v, f_req_total, color=COLORS['secondary'], linewidth=2.5, label='Total Required Lift Force')
    ax.plot(v, [W_airborne]*len(v), '--', color=COLORS['dark'], alpha=0.6, label='Airborne Structural Weight (245 N)')
    ax.fill_between(v, [W_airborne]*len(v), f_req_total, color=COLORS['secondary'], alpha=0.1, label='Rotor Thrust Vertical Component')
    
    ax.set_title("Hub Force Balance & Lift Requirement vs. Wind Speed", pad=15)
    ax.set_xlabel("Wind Speed (m/s)")
    ax.set_ylabel("Vertical Force Component (N)")
    ax.set_xlim(6, 16)
    ax.set_ylim(0, 2200)
    ax.legend(loc='upper left', frameon=True)
    
    plt.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "fig3_force_balance.png"), dpi=200)
    plt.close(fig)

# ----------------------------------------------------------------------
# Fig 4: Apparent Wind Vector Triangle
# ----------------------------------------------------------------------
def generate_fig4():
    print("Generating fig4_rotary_lifter.png...")
    # Plots the apparent wind vector triangle for the Rotary Lifter
    # V_wind = 11 m/s, V_blade = omega * r_mean = 29.7 m/s
    v_wind = 11.0
    v_blade = 29.7
    v_app = np.sqrt(v_wind**2 + v_blade**2)
    
    fig, ax = plt.subplots(figsize=(7, 4.5))
    
    # Draw true wind vector (horizontal, pointing right)
    ax.quiver(0, 0, v_wind, 0, angles='xy', scale_units='xy', scale=1, color=COLORS['single'], label='True Wind ($v_{wind} = 11.0$ m/s)')
    # Draw blade rotation velocity vector (vertical, pointing up)
    ax.quiver(v_wind, 0, 0, v_blade, angles='xy', scale_units='xy', scale=1, color=COLORS['secondary'], label=r'Blade Velocity ($\omega r = 29.7$ m/s)')
    # Draw apparent wind vector (hypotenuse)
    ax.quiver(0, 0, v_wind, v_blade, angles='xy', scale_units='xy', scale=1, color=COLORS['rotary'], label='Apparent Wind ($v_{app} = 31.7$ m/s)')
    
    ax.text(v_wind/2, -2.5, "$v_{wind}$", color=COLORS['single'], ha='center', fontweight='bold')
    ax.text(v_wind + 1.5, v_blade/2, r"$\omega r$", color=COLORS['secondary'], va='center', fontweight='bold')
    ax.text(v_wind/2 - 2.5, v_blade/2 + 1, "$v_{app}$", color=COLORS['rotary'], ha='right', fontweight='bold')
    
    ax.set_title("Rotary Lifter Apparent Wind Vector Triangle", pad=15)
    ax.set_xlim(-5, 40)
    ax.set_ylim(-5, 35)
    ax.set_aspect('equal')
    ax.grid(True, linestyle='--', alpha=0.5)
    ax.legend(loc='upper right', frameon=True)
    
    plt.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "fig4_rotary_lifter.png"), dpi=200)
    plt.close(fig)

# ----------------------------------------------------------------------
# Fig 5: Tension Comparison (Steady State Tension vs Wind Speed)
# ----------------------------------------------------------------------
def generate_fig5():
    print("Generating fig5_tension_comparison.png...")
    csv_path = os.path.join(DATA_DIR, "lift_equilibrium.csv")
    if not os.path.exists(csv_path):
        print(f"Data file {csv_path} not found. Run lift_kite_equilibrium.jl first.")
        return
        
    df = pd.read_csv(csv_path)
    
    fig, ax = plt.subplots(figsize=(7, 4.5))
    
    devices_plot = [
        ("SingleKite", COLORS['single'], 'o-', 'Single Passive Kite'),
        ("Stack×3", COLORS['stack'], 's-', 'Stacked Kites (3x)'),
        ("RotaryLifter", COLORS['rotary'], '^-', 'Rotary Lifter (Passive)')
    ]
    
    for dev_name, color, marker, label in devices_plot:
        dev_df = df[df['device'] == dev_name]
        if not dev_df.empty:
            ax.plot(dev_df['v_wind'], dev_df['T_line_N'], marker, color=color, linewidth=2.0, label=label)
            
    ax.set_title("Steady-State Lift Line Tension vs. Wind Speed", pad=15)
    ax.set_xlabel("Wind Speed (m/s)")
    ax.set_ylabel("Tension (N)")
    ax.set_xlim(6, 16)
    ax.set_ylim(0, 1500)
    ax.legend(loc='upper left', frameon=True)
    
    plt.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "fig5_tension_comparison.png"), dpi=200)
    plt.close(fig)

if __name__ == "__main__":
    generate_fig2()
    generate_fig3()
    generate_fig4()
    generate_fig5()
    print("All 4 figures successfully reconstructed and saved in 'figures/'!")
