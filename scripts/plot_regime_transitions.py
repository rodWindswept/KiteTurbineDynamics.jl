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

# ── 1. Temporal Event Cascade Analysis (Multi-Run Dot Cascade) ──────────────────
def plot_event_cascade():
    print("── Generating Multi-Run Temporal Event Cascade Timeline ──")
    df = pd.read_csv(METRICS_CSV)
    
    # Exclude failed rows (NaNs) in key metrics
    df_clean = df.dropna(subset=["payout_duration", "wind_speed", "composite_score"])
    
    # Sort runs from worst to best based on composite score
    df_sorted = df_clean.sort_values(by="composite_score").reset_index(drop=True)
    
    if len(df_sorted) == 0:
        print("[WARN] No valid runs in metrics. Skipping Event Cascade.")
        return
        
    # Programmatically select 12 representative runs across the entire spectrum (from worst to best)
    num_select = 12
    select_indices = np.linspace(0, len(df_sorted) - 1, num_select, dtype=int)
    selected_runs = df_sorted.iloc[select_indices].copy()
    
    fig, ax = plt.subplots(figsize=(15, 9))
    
    y_labels = []
    
    # Loop through each selected run to extract event timeline
    for idx, (_, run) in enumerate(selected_runs.iterrows()):
        run_id = int(run["run_id"])
        comp_score = run["composite_score"]
        winch_on = int(run["active_winch"])
        payout_dur = run["payout_duration"]
        wind_speed = run["wind_speed"]
        
        path_ts = os.path.join(RESULTS_DIR, f"timeseries_{run_id:04d}.csv")
        if not os.path.exists(path_ts):
            print(f"[WARN] Timeseries for Run #{run_id} missing. Skipping.")
            continue
            
        df_ts = pd.read_csv(path_ts)
        t = df_ts["t"].values
        omega_hub = df_ts["omega_hub"].values
        omega_gnd = df_ts["omega_gnd"].values
        tau_gen = df_ts["tau_gen"].values
        T_max = df_ts["T_max"].values
        n_slack = df_ts["n_slack"].values
        
        # We will plot on Y-coordinate corresponding to selected order
        y_val = idx + 1
        
        # Build Y-label reflecting configuration parameters
        winch_label = "Active Winch ON" if winch_on else "Decoupled Winch"
        label = f"#{run_id:03d} | {payout_dur:.1f}s Payout | {wind_speed:.1f}m/s | {winch_label}"
        y_labels.append(label)
        
        # Plot horizontal lane line for the run
        ax.hlines(y_val, 0, 30, colors="gray", linestyles="--", alpha=0.15)
        
        # ── Event 1: Tether Slack (Orange) ──
        # Trigger when n_slack > 5 segments go slack
        slack_idxs = np.where(n_slack > 5)[0]
        if len(slack_idxs) > 0:
            t_slack = t[slack_idxs[0]]
            max_n_slack = np.max(n_slack)
            # Dot size proportional to maximum slack segments (representing extent of collapse)
            size_slack = min(350, max(30, max_n_slack * 0.12))
            ax.scatter(t_slack, y_val, s=size_slack, color="#ffa726", edgecolor="white", alpha=0.8, linewidths=0.5)
            
        # ── Event 2: Torsional Whipping / Regimes Cross (Purple) ──
        # Trigger when hub-gnd twist speed exceeds 3.0 rad/s
        twist_speed = np.abs(omega_hub - omega_gnd)
        whip_idxs = np.where(twist_speed > 3.0)[0]
        if len(whip_idxs) > 0:
            t_whip = t[whip_idxs[0]]
            max_whip = np.max(twist_speed)
            # Dot size proportional to max whipping speed (representing whipping severity)
            size_whip = min(350, max(30, max_whip * 8.0))
            ax.scatter(t_whip, y_val, s=size_whip, color="#aa00ff", edgecolor="white", alpha=0.8, linewidths=0.5)
            
        # ── Event 3: Peak Generator Torque Spike (Red) ──
        # Trigger at time of peak generator torque
        peak_torque_idx = np.argmax(np.abs(tau_gen))
        t_torque = t[peak_torque_idx]
        peak_torque_val = np.abs(tau_gen[peak_torque_idx])
        # Dot size proportional to peak torque spike in kN*m
        size_torque = min(400, max(30, peak_torque_val / 40.0))
        ax.scatter(t_torque, y_val, s=size_torque, color="#ff1744", edgecolor="white", alpha=0.8, linewidths=0.5)
        
        # ── Event 4: Brake Clamped & PTO Latching (Green) ──
        # Trigger when omega_gnd < 0.1 rad/s after starting payout
        brake_idxs = np.where(omega_gnd < 0.1)[0]
        brake_idxs = [i for i in brake_idxs if t[i] > 2.0]
        if len(brake_idxs) > 0:
            t_brake = t[brake_idxs[0]]
            # Dot size proportional to overall composite score (higher score = larger, healthier green dot)
            size_brake = min(350, max(40, comp_score * 350.0))
            ax.scatter(t_brake, y_val, s=size_brake, color="#00e676", edgecolor="white", alpha=0.9, linewidths=0.5)
            
    ax.set_ylim(0.5, num_select + 0.5)
    ax.set_xlim(0, 25)
    ax.set_yticks(range(1, num_select + 1))
    ax.set_yticklabels(y_labels, fontsize=10, fontweight="bold")
    
    ax.set_xlabel("Depower Transient Time $t$ (seconds) — [Latching Progression →]", fontsize=12, fontweight="bold", labelpad=10)
    ax.set_title("Temporal Event Cascade: Subsystem Limits & Threshold Crossing Map\n"
                 "(12 Representative Runs Ranked Worst-to-Best | Dot Size Scales with Mechatronic Severity)", 
                 fontsize=14, fontweight="bold", pad=20)
    ax.grid(True, axis="x", linestyle="--", alpha=0.1)
    
    # ── Pure Custom Legend for Colored Dots & Significance (No text labels inside plot area) ──
    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#ffa726', markersize=12, label='Tether Slack Segment (Size $\\propto$ Slack Segments)', markeredgecolor='white'),
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#aa00ff', markersize=12, label='Torsional Whipping Trigger (Size $\\propto$ Whipping Speed)', markeredgecolor='white'),
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#ff1744', markersize=12, label='Peak Generator Torque Spike (Size $\\propto$ Torque Peak)', markeredgecolor='white'),
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#00e676', markersize=12, label='PTO Mechanical Brake Clamped (Size $\\propto$ Composite Score)', markeredgecolor='white'),
    ]
    
    ax.legend(handles=legend_elements, loc="upper right", framealpha=0.9, edgecolor="gray", fontsize=10)
    
    out_path = os.path.join(RESULTS_DIR, "science_event_cascade.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved Advanced Temporal Event Cascade to: {out_path}")

# ── 2. Parametric Regime Bifurcation (Bifurcation & Thresholds Plot) ───────────
def plot_regime_bifurcation():
    print("── Generating Parametric Regime Bifurcation & Transition Map ──")
    df = pd.read_csv(METRICS_CSV)
    
    # We isolate storm wind speed (20.0 m/s) to show parameter limits clearly
    df_storm = df[df["wind_speed"] == 20.0].copy()
    
    if len(df_storm) == 0:
        print("[WARN] No storm data (20.0 m/s) found in metrics. Falling back to rated wind (11.0 m/s).")
        df_storm = df[df["wind_speed"] == 11.0].copy()
        wind_val = 11.0
    else:
        wind_val = 20.0
        
    df_storm = df_storm.dropna(subset=["payout_duration", "fos_buckling_min", "d_omega_rms"])
    df_storm = df_storm.sort_values(by="payout_duration")
    
    gp = df_storm.groupby(["payout_duration", "active_winch"]).agg(
        fos_min=("fos_buckling_min", "min"),
        twist_max=("twist_max", "max"),
        jerk_mean=("d_tau_gen_rms", "mean")
    ).reset_index()
    
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10), sharex=True)
    
    gp_winch_off = gp[gp["active_winch"] == 0]
    gp_winch_on  = gp[gp["active_winch"] == 1]
    
    # ── AX1: Structural Buckling FoS Threshold ──
    ax1.plot(gp_winch_off["payout_duration"], gp_winch_off["fos_min"], 
             color="#ff1744", marker="o", linewidth=2.5, label="Decoupled winching (Winch OFF)")
    ax1.plot(gp_winch_on["payout_duration"], gp_winch_on["fos_min"], 
             color="#00e676", marker="s", linewidth=2.5, label="Active winching (Winch ON)")
    
    ax1.axhline(1.5, color="white", linestyle="--", linewidth=2.0)
    ax1.text(14.5, 1.6, "Buckling Limit: FoS = 1.5", color="white", fontsize=9, fontweight="bold", ha="right")
    
    ax1.axvspan(2.0, 6.0, color="#ff1744", alpha=0.15)
    ax1.text(4.0, 4.0, "CFRP BUCKLING\nREGIME\n(Failure)", 
             color="#ff1744", fontsize=11, fontweight="bold", ha="center")
    
    ax1.set_ylabel("CFRP Strut Buckling FoS", fontsize=11, fontweight="bold")
    ax1.set_title(f"Parametric Regime Transition & Bifurcation Map (Storm Wind: {wind_val} m/s)\n"
                 "(How winch controls shift the physical boundaries of structural and dynamic safety)", 
                 fontsize=13, fontweight="bold", pad=15)
    ax1.grid(True, linestyle="--", alpha=0.15)
    ax1.legend(loc="upper right")
    ax1.set_ylim(0.0, 6.0)
    
    # ── AX2: Shaft Torsional Twist Angle Threshold ──
    ax2.plot(gp_winch_off["payout_duration"], gp_winch_off["twist_max"], 
             color="#ff1744", marker="o", linewidth=2.5, label="Decoupled winching (Winch OFF)")
    ax2.plot(gp_winch_on["payout_duration"], gp_winch_on["twist_max"], 
             color="#00e676", marker="s", linewidth=2.5, label="Active winching (Winch ON)")
    
    ax2.axhline(np.pi/2, color="white", linestyle="--", linewidth=2.0)
    ax2.text(14.5, np.pi/2 + 0.1, "Torsional Collapse: twist = $\\pi/2$ rad", color="white", fontsize=9, fontweight="bold", ha="right")
    
    ax2.axvspan(10.0, 15.0, color="#2979ff", alpha=0.15)
    ax2.text(12.5, 0.4, "TETHER SLACK\nWHIPPING REGIME\n(Tulloch Resonance)", 
             color="#2979ff", fontsize=11, fontweight="bold", ha="center")
    
    ax2.axvspan(6.0, 10.0, color="#00e676", alpha=0.15)
    ax2.text(8.0, 0.8, "SAFE ENVELOPE\nGATEWAY\n(Option A & B)", 
             color="#00e676", fontsize=11, fontweight="bold", ha="center")
    
    ax2.set_xlabel("Backline Payout Duration (seconds) — [Faster Winch Payout →]", fontsize=12, fontweight="bold")
    ax2.set_ylabel("Max Drivetrain Twist Angle (rad)", fontsize=11, fontweight="bold")
    ax2.grid(True, linestyle="--", alpha=0.15)
    ax2.set_ylim(0.0, np.pi)
    
    plt.tight_layout()
    
    out_path = os.path.join(RESULTS_DIR, "science_regime_bifurcation.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved Parametric Regime Bifurcation to: {out_path}")

if __name__ == "__main__":
    plot_event_cascade()
    plot_regime_bifurcation()
