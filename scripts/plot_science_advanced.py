#!/usr/bin/env python3
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.interpolate import griddata

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
RESULTS_DIR  = os.path.join(SCRIPT_DIR, "results", "pitch_depower_campaign")
METRICS_CSV  = os.path.join(RESULTS_DIR, "campaign_metrics.csv")

# ── Styles ────────────────────────────────────────────────────────────────────
plt.style.use("dark_background")
fig_dpi = 150

# ── 1. State-Space Phase Portrait (Tulloch Limit Cycle Plane) ──────────────────
def plot_state_space_portrait():
    print("── Generating State-Space Phase Portrait ──")
    path_base = os.path.join(RESULTS_DIR, "timeseries_0001.csv")
    path_win  = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_base) and os.path.exists(path_win)):
        print("[WARN] Timeseries files missing. Skipping Phase Portrait.")
        return
        
    df_base = pd.read_csv(path_base)
    df_win  = pd.read_csv(path_win)
    
    # Extract data during steady depower phase (t >= 8.0s to avoid initial start transients)
    base_cut = df_base[df_base["t"] >= 8.0].copy()
    win_cut  = df_win[df_win["t"] >= 8.0].copy()
    
    # Calculate delta omega (twist speed differential)
    base_cut["delta_omega"] = base_cut["omega_hub"] - base_cut["omega_gnd"]
    win_cut["delta_omega"]  = win_cut["omega_hub"] - win_cut["omega_gnd"]
    
    # Integrate to get cumulative shaft twist angle
    dt_base = np.diff(base_cut["t"].values)[0] if len(base_cut) > 1 else 0.02
    dt_win  = np.diff(win_cut["t"].values)[0] if len(win_cut) > 1 else 0.02
    
    base_cut["theta_twist"] = np.cumsum(base_cut["delta_omega"].values) * dt_base
    win_cut["theta_twist"]  = np.cumsum(win_cut["delta_omega"].values) * dt_win
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 7), sharey=True)
    
    # Run 1: Decoupled Baseline
    t_base = base_cut["t"].values
    theta_base = base_cut["theta_twist"].values
    d_omega_base = base_cut["delta_omega"].values
    
    # Use color gradient for time progression
    sc1 = ax1.scatter(theta_base, d_omega_base, c=t_base, cmap="plasma", s=10, alpha=0.6)
    ax1.plot(theta_base, d_omega_base, color="white", linewidth=0.5, alpha=0.3)
    ax1.set_xlabel("Relative Shaft Twist Angle $\\theta_{twist}$ (rad)", fontsize=12, fontweight="bold")
    ax1.set_ylabel("Twist Speed Differential $\\Delta \\omega$ (rad/s)", fontsize=12, fontweight="bold")
    ax1.set_title("Run #1: Decoupled Baseline (Slack Shaft)\n[Uncontrolled Tulloch Limit Cycle]", fontsize=13, fontweight="bold", color="#ff1744")
    ax1.grid(True, linestyle="--", alpha=0.15)
    
    # Annotate chaotic orbit
    ax1.annotate("Chaotic Limit-Cycle\nResonant Attractor", xy=(theta_base[len(theta_base)//2], d_omega_base[len(d_omega_base)//2]),
                xytext=(theta_base[len(theta_base)//2] - 4, d_omega_base[len(d_omega_base)//2] + 2),
                arrowprops=dict(facecolor='#ff1744', shrink=0.05, width=1, headwidth=5),
                color="#ff1744", fontsize=10, fontweight="bold")
    
    # Run 429: Active Winner
    t_win = win_cut["t"].values
    theta_win = win_cut["theta_twist"].values
    d_omega_win = win_cut["delta_omega"].values
    
    sc2 = ax2.scatter(theta_win, d_omega_win, c=t_win, cmap="viridis", s=10, alpha=0.6)
    ax2.plot(theta_win, d_omega_win, color="white", linewidth=0.5, alpha=0.3)
    ax2.set_xlabel("Relative Shaft Twist Angle $\\theta_{twist}$ (rad)", fontsize=12, fontweight="bold")
    ax2.set_title("Run #429: Stabilized Winner (Active Controls)\n[Converging Spiral to Stable Focus]", fontsize=13, fontweight="bold", color="#00e676")
    ax2.grid(True, linestyle="--", alpha=0.15)
    
    # Annotate convergence
    ax2.annotate("Stable Damped Focus", xy=(theta_win[-1], d_omega_win[-1]),
                xytext=(theta_win[-1] + 1.5, d_omega_win[-1] + 1.0),
                arrowprops=dict(facecolor='#00e676', shrink=0.05, width=1, headwidth=5),
                color="#00e676", fontsize=10, fontweight="bold")
    
    # Add colorbars for time progress
    cbar1 = fig.colorbar(sc1, ax=ax1, orientation="horizontal", pad=0.12, shrink=0.8)
    cbar1.set_label("Time elapsed (s)", fontsize=10)
    cbar2 = fig.colorbar(sc2, ax=ax2, orientation="horizontal", pad=0.12, shrink=0.8)
    cbar2.set_label("Time elapsed (s)", fontsize=10)
    
    plt.suptitle("Mechatronic State-Space Phase Portraits\n"
                 "(Torsional Dynamics Signature: Decoupled vs. Stabilized Control Modes)", 
                 fontsize=15, fontweight="bold", y=0.98)
    
    out_path = os.path.join(RESULTS_DIR, "science_phase_portrait.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved State-Space Phase Portrait to: {out_path}")

# ── 2. Survival Envelope Intersection (Orthogonal Failure Cliffs) ──────────────
def plot_survival_envelope():
    print("── Generating Survival Envelope Intersection ──")
    df = pd.read_csv(METRICS_CSV)
    
    # Clean and filter
    df_clean = df.dropna(subset=["payout_duration", "wind_speed", "fos_buckling_min", "T_cyan_min"])
    
    x = df_clean["payout_duration"].values
    y = df_clean["wind_speed"].values
    z_buckle = df_clean["fos_buckling_min"].values
    z_slack = df_clean["T_cyan_min"].values
    
    # Meshgrid for interpolation
    xi = np.linspace(2.0, 15.0, 150)
    yi = np.linspace(11.0, 20.0, 150)
    XI, YI = np.meshgrid(xi, yi)
    
    # Interpolate both metrics
    ZI_buckle = griddata((x, y), z_buckle, (XI, YI), method='linear')
    ZI_slack = griddata((x, y), z_slack, (XI, YI), method='linear')
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # Shade structural buckling zone (Red)
    # Buckling limit is FoS < 1.5
    ax.contourf(XI, YI, ZI_buckle, levels=[0.0, 1.5], colors=["#ff1744"], alpha=0.35)
    cs_buckle = ax.contour(XI, YI, ZI_buckle, levels=[1.5], colors=["#ff1744"], linewidths=[2.5], linestyles=["--"])
    
    # Shade Sky Anchor slack zone (Blue/Teal)
    # Sky anchor slack limit is tension < 150 N (or 250 N)
    slack_level = 250.0
    ax.contourf(XI, YI, ZI_slack, levels=[0.0, slack_level], colors=["#2979ff"], alpha=0.35)
    cs_slack = ax.contour(XI, YI, ZI_slack, levels=[slack_level], colors=["#2979ff"], linewidths=[2.5], linestyles=["-."])
    
    # Scatter active runs color-coded by survival
    is_survived = (z_buckle >= 1.5) & (z_slack >= slack_level)
    
    ax.scatter(x[is_survived], y[is_survived], c='#00e676', edgecolor='white', s=35, alpha=0.8, label="Survived Runs (Stable & Safe)")
    ax.scatter(x[~is_survived], y[~is_survived], c='#ff1744', edgecolor='black', s=25, alpha=0.4, label="Failed/Disqualified Runs")
    
    # Annotate boundaries
    ax.clabel(cs_buckle, inline=True, fmt="Strut Buckling Limit (FoS = 1.5)", fontsize=10, colors="#ff1744")
    ax.clabel(cs_slack, inline=True, fmt=f"Sky Anchor Slack Limit ({slack_level:.0f} N)", fontsize=10, colors="#2979ff")
    
    # Label regions
    ax.text(3.5, 18.5, "CFRP BUCKLING CLIFF\n(High Wind + Fast Payout)", 
            color="#ff1744", fontsize=11, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="square,pad=0.4", fc="black", alpha=0.8, ec="#ff1744"))
            
    ax.text(12.5, 12.0, "SKY ANCHOR SLACK CLIFF\n(Low Wind + Slow Payout)", 
            color="#2979ff", fontsize=11, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="square,pad=0.4", fc="black", alpha=0.8, ec="#2979ff"))
            
    ax.text(8.5, 16.0, "SAFE OPERATIONAL GATEWAY\n(Survival Corridor)", 
            color="#00e676", fontsize=13, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.5", fc="black", alpha=0.85, ec="#00e676", lw=2))
            
    ax.set_xlabel("Payout Duration (s) — [Faster Winch Payout →]", fontsize=13, fontweight="bold")
    ax.set_ylabel("Wind Speed (m/s) — [Increasing Aerodynamic Load →]", fontsize=13, fontweight="bold")
    ax.set_title("Survival Envelope Intersection Plane: Orthogonal Physical Cliffs\n"
                 "(Visualizing how opposing physical failure bounds compress the safe design gateway)", 
                 fontsize=14, fontweight="bold", pad=15)
    
    ax.set_xlim(2.0, 15.0)
    ax.set_ylim(11.0, 20.0)
    ax.grid(True, linestyle="--", alpha=0.1)
    ax.legend(loc="upper right", framealpha=0.9, edgecolor="gray")
    
    out_path = os.path.join(RESULTS_DIR, "science_survival_envelope.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved Survival Envelope to: {out_path}")

# ── 3. 3D Safety Surface & Buckling Intersecting Plane ────────────────────────
def plot_safety_surface_3d():
    print("── Generating 3D Safety Surface & Intersecting Plane ──")
    df = pd.read_csv(METRICS_CSV)
    
    df_clean = df.dropna(subset=["payout_duration", "wind_speed", "fos_buckling_min"])
    
    x = df_clean["payout_duration"].values
    y = df_clean["wind_speed"].values
    z = df_clean["fos_buckling_min"].values
    
    # Meshgrid for interpolation
    xi = np.linspace(2.0, 15.0, 60)
    yi = np.linspace(11.0, 20.0, 60)
    XI, YI = np.meshgrid(xi, yi)
    
    ZI = griddata((x, y), z, (XI, YI), method='linear')
    
    fig = plt.figure(figsize=(14, 10))
    ax = fig.add_subplot(111, projection='3d')
    
    # Plot the safety surface
    surf = ax.plot_surface(XI, YI, ZI, cmap="viridis", edgecolor='none', alpha=0.8,
                           vmin=1.0, vmax=5.0, label="CFRP Buckling FoS Surface")
    
    # Draw horizontal intersection plane at FoS = 1.5 (structural failure threshold)
    plane_z = np.full_like(XI, 1.5)
    ax.plot_surface(XI, YI, plane_z, color="#ff1744", alpha=0.25, edgecolor='none',
                    label="Failure Threshold (FoS = 1.5)")
    
    # Add a thin bold line where they intersect (FoS = 1.5)
    # We can overlay a contour line projected onto the 3D surface
    ax.contour(XI, YI, ZI, levels=[1.5], colors=["#ff1744"], linewidths=[3.0], linestyles=["-"])
    
    # Scatter simulation runs onto the 3D plot
    ax.scatter(x, y, z, c='white', edgecolor='black', s=20, alpha=0.5, depthshade=True)
    
    ax.set_xlabel("Payout Duration (s)", fontsize=11, fontweight="bold", labelpad=10)
    ax.set_ylabel("Wind Speed (m/s)", fontsize=11, fontweight="bold", labelpad=10)
    ax.set_zlabel("Spacer CFRP Buckling FoS", fontsize=11, fontweight="bold", labelpad=10)
    ax.set_title("3D Safety Surface & Structural Failure Intersection Plane\n"
                 "(CFRP Strut Buckling Factor of Safety Surface Sliced by FoS = 1.5 Safety Plane)", 
                 fontsize=14, fontweight="bold", pad=20)
    
    # Adjust view angle for high-fidelity representation of the intersection
    ax.view_init(elev=20, azim=-125)
    
    # Colorbar
    cbar = fig.colorbar(surf, shrink=0.5, pad=0.1)
    cbar.set_label("CFRP Buckling Factor of Safety (FoS)", fontsize=11, fontweight="bold")
    
    out_path = os.path.join(RESULTS_DIR, "science_control_surface_3d.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved 3D Safety Surface to: {out_path}")

if __name__ == "__main__":
    plot_state_space_portrait()
    plot_survival_envelope()
    plot_safety_surface_3d()
