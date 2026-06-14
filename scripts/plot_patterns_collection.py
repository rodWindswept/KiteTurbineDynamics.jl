#!/usr/bin/env python3
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
RESULTS_DIR  = os.path.join(SCRIPT_DIR, "results", "pitch_depower_campaign")
METRICS_CSV  = os.path.join(RESULTS_DIR, "campaign_metrics.csv")

# ── Styles ────────────────────────────────────────────────────────────────────
plt.style.use("dark_background")
fig_dpi = 150

# ── 1. Pattern 7: Tether Tension Slack Hysteresis Loop ─────────────────────────
def plot_tension_hysteresis():
    print("── Generating Tether Tension Hysteresis Loop (Pattern #7) ──")
    path_base = os.path.join(RESULTS_DIR, "timeseries_0001.csv")
    path_win  = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_base) and os.path.exists(path_win)):
        print("[WARN] Timeseries files missing. Skipping Hysteresis.")
        return
        
    df_base = pd.read_csv(path_base)
    df_win  = pd.read_csv(path_win)
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # Plot Tension vs Payout Length
    # Baseline (Winch OFF)
    ax.plot(df_base["backline_payout"], df_base["T_max"], color="#ff1744", linewidth=2, 
            label="Run #1: Winch OFF (Decoupled Slack path)")
    # Winner (Winch ON)
    ax.plot(df_win["backline_payout"], df_win["T_max"], color="#00e676", linewidth=2.5,
            label="Run #429: Winch ON (Active Tension control loop)")
    
    ax.axhline(250, color="white", linestyle="--", alpha=0.5)
    ax.text(14.5, 270, "Tension Slack Boundary (250 N)", color="white", fontsize=9, alpha=0.7, ha="right")
    
    ax.set_xlabel("Backline Winch Payout Length (meters) — [Winch Extending →]", fontsize=11, fontweight="bold")
    ax.set_ylabel("Maximum Segment Tension $T_{max}$ (N)", fontsize=11, fontweight="bold")
    ax.set_title("Tether Tension Hysteresis Loop: Slack Decoupling Mitigation\n"
                 "(Comparing tension preloads over backline payout extension)", 
                 fontsize=12, fontweight="bold", pad=15)
    ax.grid(True, linestyle="--", alpha=0.15)
    ax.legend(loc="upper right", framealpha=0.9, edgecolor="gray")
    
    out_path = os.path.join(RESULTS_DIR, "science_tension_hysteresis.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved Tension Hysteresis to: {out_path}")

# ── 2. Pattern 8: Generator Torque-Speed Phase Portrait ────────────────────────
def plot_torque_speed_phase():
    print("── Generating Generator Torque-Speed Phase Portrait (Pattern #8) ──")
    # Let's compare Run 3 (MPPT Stall ON, high recoil) and Run 429 (MPPT Stall OFF, smooth)
    path_stall = os.path.join(RESULTS_DIR, "timeseries_0003.csv")
    path_smooth = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_stall) and os.path.exists(path_smooth)):
        print("[WARN] Timeseries files missing. Skipping Torque-Speed Phase.")
        return
        
    df_stall  = pd.read_csv(path_stall)
    df_smooth = pd.read_csv(path_smooth)
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # Plot Generator Torque vs Ground Speed
    ax.plot(df_stall["omega_gnd"], df_stall["tau_gen"], color="#ff1744", linewidth=1.5, alpha=0.7,
            label="Run #3: MPPT Stall ON (Elastic energy recoil & torque spikes)")
    ax.plot(df_smooth["omega_gnd"], df_smooth["tau_gen"], color="#00e676", linewidth=2.5,
            label="Run #429: MPPT Stall OFF (LPF Smooth deceleration path)")
    
    ax.set_xlabel("Generator Ground Ring Speed $\\omega_{gnd}$ (rad/s)", fontsize=11, fontweight="bold")
    ax.set_ylabel("Electromagnetic Generator Torque $\\tau_{gen}$ (N·m)", fontsize=11, fontweight="bold")
    ax.set_title("Generator Torque-Speed Phase Portrait: MPPT Stall Recoil\n"
                 "(Visualizing how rotor stalling injects violent elastic torque back-spikes)", 
                 fontsize=12, fontweight="bold", pad=15)
    ax.grid(True, linestyle="--", alpha=0.15)
    ax.legend(loc="upper right", framealpha=0.9, edgecolor="gray")
    
    out_path = os.path.join(RESULTS_DIR, "science_torque_speed_phase.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved Torque-Speed Phase to: {out_path}")

# ── 3. Pattern 9: TRPT Torsional Energy Landscape ─────────────────────────────
def plot_torsional_energy():
    print("── Generating TRPT Torsional Energy Landscape (Pattern #9) ──")
    path_base = os.path.join(RESULTS_DIR, "timeseries_0001.csv")
    path_win  = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_base) and os.path.exists(path_win)):
        print("[WARN] Timeseries files missing. Skipping Energy Landscape.")
        return
        
    df_base = pd.read_csv(path_base)
    df_win  = pd.read_csv(path_win)
    
    # Calculate energy components:
    # 1. Kinetic energy twist = 0.5 * I * (omega_hub - omega_gnd)^2
    # 2. Elastic potential energy twist = 0.5 * K * theta_twist^2
    # We use nominal parameters: I = 25.0 kg*m^2 (rotor inertia), K = 1200 N*m/rad (nominal twist stiffness)
    I_rot = 25.0
    K_shaft = 1200.0
    
    def compute_energy(df):
        t = df["t"].values
        d_omega = df["omega_hub"].values - df["omega_gnd"].values
        dt = np.diff(t)[0] if len(t) > 1 else 0.02
        theta = np.cumsum(d_omega) * dt
        
        e_kin = 0.5 * I_rot * (d_omega ** 2)
        e_pot = 0.5 * K_shaft * (theta ** 2)
        return t, e_kin, e_pot, e_kin + e_pot

    t_b, ek_b, ep_b, et_b = compute_energy(df_base)
    t_w, ek_w, ep_w, et_w = compute_energy(df_win)
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6), sharey=True)
    
    # Baseline Run 1
    ax1.plot(t_b, ep_b, color="#ff9100", linestyle="--", alpha=0.7, label="Elastic Potential Energy ($E_{pot}$)")
    ax1.plot(t_b, ek_b, color="#2979ff", linestyle=":", alpha=0.7, label="Rotational Kinetic Energy ($E_{kin}$)")
    ax1.plot(t_b, et_b, color="#ff1744", linewidth=2.5, label="Total Torsional Energy ($E_{tot}$)")
    ax1.set_xlabel("Time $t$ (seconds)", fontsize=11, fontweight="bold")
    ax1.set_ylabel("Drivetrain Energy (Joules)", fontsize=11, fontweight="bold")
    ax1.set_title("Run #1: Decoupled Baseline\n[Violent Torsional Energy Resonances]", fontsize=12, fontweight="bold", color="#ff1744")
    ax1.grid(True, linestyle="--", alpha=0.15)
    ax1.legend(loc="upper right", fontsize=9)
    
    # Winner Run 429
    ax2.plot(t_w, ep_w, color="#ff9100", linestyle="--", alpha=0.7, label="Elastic Potential Energy ($E_{pot}$)")
    ax2.plot(t_w, ek_w, color="#2979ff", linestyle=":", alpha=0.7, label="Rotational Kinetic Energy ($E_{kin}$)")
    ax2.plot(t_w, et_w, color="#00e676", linewidth=2.5, label="Total Torsional Energy ($E_{tot}$)")
    ax2.set_xlabel("Time $t$ (seconds)", fontsize=11, fontweight="bold")
    ax2.set_title("Run #429: Stabilized Winner\n[Rapid Energy Dissipation & Latching]", fontsize=12, fontweight="bold", color="#00e676")
    ax2.grid(True, linestyle="--", alpha=0.15)
    ax2.legend(loc="upper right", fontsize=9)
    
    plt.suptitle("TRPT Drivetrain Torsional Energy Landscape\n"
                 "(Comparing persistent self-excited energy exchange against active controlled dissipation)", 
                 fontsize=14, fontweight="bold", y=0.98)
    
    out_path = os.path.join(RESULTS_DIR, "science_torsional_energy.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved Torsional Energy Landscape to: {out_path}")

# ── 4. Pattern 10: Multi-Dimensional Control Cartography Flow ──────────────────
def plot_multivariate_cartography():
    print("── Generating Multivariate Control Flow Parallel Coordinates (Pattern #10) ──")
    df = pd.read_csv(METRICS_CSV)
    
    df_clean = df.dropna(subset=["wind_speed", "payout_duration", "active_winch", "mppt_stall", "composite_score"])
    
    # We will draw a beautiful custom parallel coordinate visual using matplotlib directly
    # Columns to map: Wind Speed, Winch Duration, Active Winch, MPPT Stall, Buckling FoS, Score
    cols = ["wind_speed", "payout_duration", "active_winch", "mppt_stall", "composite_score"]
    
    fig, axes = plt.subplots(1, len(cols)-1, figsize=(16, 7), sharey=False)
    
    # Normalize data for plotting between 0 and 1 per axis
    df_norm = df_clean.copy()
    min_max = {}
    for col in cols:
        val_min = df_clean[col].min()
        val_max = df_clean[col].max()
        df_norm[col] = (df_clean[col] - val_min) / (val_max - val_min) if val_max != val_min else 0.5
        min_max[col] = (val_min, val_max)
        
    # Sort by score to draw optimal runs on top
    df_norm = df_norm.sort_values(by="composite_score")
    
    # Create colormap based on composite score (Red to Green)
    cmap = plt.get_cmap("RdYlGn")
    
    # Plot lines
    for _, row in df_norm.iterrows():
        score = row["composite_score"]
        color = cmap(score)
        # Highlight winner in thick green and failing in thin red/gray
        lw = 2.0 if score > 0.5 else 0.25
        alpha = 0.8 if score > 0.5 else 0.15
        
        # Draw line segment between adjacent axes
        for i in range(len(cols)-1):
            y1 = row[cols[i]]
            y2 = row[cols[i+1]]
            axes[i].plot([i, i+1], [y1, y2], color=color, linewidth=lw, alpha=alpha)
            
    # Set labels and ticks for each axis
    for i in range(len(cols)-1):
        ax = axes[i]
        ax.set_ylim(-0.05, 1.05)
        ax.set_xlim(i, i+1)
        ax.set_xticks([i])
        ax.set_xticklabels([cols[i].replace("_", "\n").upper()], fontsize=10, fontweight="bold")
        
        # Add labels for min and max value at each axis
        ax.text(i, -0.04, f"{min_max[cols[i]][0]:.1f}", ha="center", color="gray", fontsize=8)
        ax.text(i, 1.02, f"{min_max[cols[i]][1]:.1f}", ha="center", color="gray", fontsize=8)
        
        ax.spines['top'].set_visible(False)
        ax.spines['bottom'].set_visible(False)
        if i > 0:
            ax.spines['left'].set_visible(False)
            ax.get_yaxis().set_visible(False)
            
    # Last axis labels
    ax_last = axes[-1]
    ax_last.set_xticks([len(cols)-2, len(cols)-1])
    ax_last.set_xticklabels([cols[-2].replace("_", "\n").upper(), cols[-1].replace("_", "\n").upper()], fontsize=10, fontweight="bold")
    ax_last.text(len(cols)-1, -0.04, f"{min_max[cols[-1]][0]:.1f}", ha="center", color="gray", fontsize=8)
    ax_last.text(len(cols)-1, 1.02, f"{min_max[cols[-1]][1]:.1f}", ha="center", color="gray", fontsize=8)
    ax_last.spines['right'].set_color("gray")
    
    plt.suptitle("Multivariate Design Cartography Flow Map (10th Pattern)\n"
                 "(Connecting control switches, wind variables, structural safety, and final mechatronic scores)", 
                 fontsize=14, fontweight="bold", y=0.98)
    
    plt.tight_layout()
    
    out_path = os.path.join(RESULTS_DIR, "science_parallel_multivariate.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved Multivariate Cartography Flow to: {out_path}")

if __name__ == "__main__":
    plot_tension_hysteresis()
    plot_torque_speed_phase()
    plot_torsional_energy()
    plot_multivariate_cartography()
