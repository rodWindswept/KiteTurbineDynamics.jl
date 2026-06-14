#!/usr/bin/env python3
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.signal import welch

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
RESULTS_DIR  = os.path.join(SCRIPT_DIR, "results", "pitch_depower_campaign")
METRICS_CSV  = os.path.join(RESULTS_DIR, "campaign_metrics.csv")

# ── Styles ────────────────────────────────────────────────────────────────────
plt.style.use("dark_background")
fig_dpi = 150

# ── 1. 3D Design Space Scatter ────────────────────────────────────────────────
def plot_3d_design_space():
    df = pd.read_csv(METRICS_CSV)
    
    # Extract coordinates
    x = df["payout_duration"].values
    y = df["wind_speed"].values
    z = df["d_tau_gen_rms"].values  # torque jerk
    color_val = df["T_cyan_min"].values  # sky anchor tension
    size_val = df["twist_max"].values * 10.0  # scale twist angle for size
    
    fig = plt.figure(figsize=(14, 10))
    ax = fig.add_subplot(111, projection='3d')
    
    # Custom colormap: red (slack/dangerous) to green (taut/safe)
    cmap = plt.get_cmap("RdYlGn")
    norm = matplotlib.colors.Normalize(vmin=0, vmax=1000)
    
    sc = ax.scatter(x, y, z, c=color_val, cmap=cmap, norm=norm, 
                    s=size_val, edgecolor='white', alpha=0.8, linewidths=0.5)
    
    ax.set_xlabel("Payout Duration (s)", fontsize=12, labelpad=10, fontweight="bold")
    ax.set_ylabel("Wind Speed (m/s)", fontsize=12, labelpad=10, fontweight="bold")
    ax.set_zlabel("Torque RMS Jerk (N·m/s)", fontsize=12, labelpad=10, fontweight="bold")
    ax.set_title("Real Campaign Data: 3D Design Space Topography\n"
                 "(Marker Size = Max Shaft Twist | Color = Sky Anchor Tension)", 
                 fontsize=14, fontweight="bold", pad=20)
    
    cbar = fig.colorbar(sc, shrink=0.5, pad=0.1)
    cbar.set_label("Min Sky Anchor Tension (N)", fontsize=12, fontweight="bold")
    
    ax.grid(True, linestyle="--", alpha=0.3)
    ax.view_init(elev=25, azim=-45)
    
    out_path = os.path.join(RESULTS_DIR, "science_design_space_3d.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved 3D Design Space scatter to: {out_path}")

# ── 2. Vibration & Resonance Spectral Density (FFT) ─────────────────────────
def plot_vibration_spectra():
    # Load Run 1 (decoupled baseline) and Run 429 (stabilized winner)
    path_base = os.path.join(RESULTS_DIR, "timeseries_0001.csv")
    path_win  = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_base) and os.path.exists(path_win)):
        print("[WARN] Timeseries files for Run 1 or 429 missing. Skipping FFT.")
        return
        
    df_base = pd.read_csv(path_base)
    df_win  = pd.read_csv(path_win)
    
    fs = 100.0  # 100 Hz frame capture rate
    
    # Twist speed differential: omega_hub - omega_gnd during steady depower phase (t >= 10s)
    base_cut = df_base[df_base["t"] >= 10.0]
    win_cut  = df_win[df_win["t"] >= 10.0]
    
    v_base = (base_cut["omega_hub"] - base_cut["omega_gnd"]).values
    v_win  = (win_cut["omega_hub"] - win_cut["omega_gnd"]).values
    
    # Compute Power Spectral Density via Welch method
    f_base, psd_base = welch(v_base, fs, nperseg=min(len(v_base), 256))
    f_win, psd_win   = welch(v_win, fs, nperseg=min(len(v_win), 256))
    
    fig, ax = plt.subplots(figsize=(12, 7))
    
    ax.semilogy(f_base, psd_base, color="#ff1744", linewidth=2.5, label="Run #1: Decoupled Baseline (Slack Shaft)")
    ax.semilogy(f_win, psd_win, color="#00e676", linewidth=2.5, label="Run #429: Active Winch + LPF (Stabilized Shaft)")
    
    # Annotate peak Tulloch resonance frequency
    peak_idx_base = np.argmax(psd_base)
    peak_f_base = f_base[peak_idx_base]
    peak_val_base = psd_base[peak_idx_base]
    ax.annotate(f"Tulloch Resonance: {peak_f_base:.2f} Hz\nPSD: {peak_val_base:.2e} rad²/s²/Hz",
                xy=(peak_f_base, peak_val_base), xytext=(peak_f_base + 1.0, peak_val_base * 5.0),
                arrowprops=dict(facecolor='#ff1744', shrink=0.08, width=1.5, headwidth=6),
                color="#ff1744", fontsize=11, fontweight="bold")
                
    peak_idx_win = np.argmax(psd_win)
    peak_f_win = f_win[peak_idx_win]
    peak_val_win = psd_win[peak_idx_win]
    ax.annotate(f"Residual oscillation: {peak_f_win:.2f} Hz",
                xy=(peak_f_win, peak_val_win), xytext=(peak_f_win + 1.5, peak_val_win / 10.0),
                arrowprops=dict(facecolor='#00e676', shrink=0.08, width=1.5, headwidth=6),
                color="#00e676", fontsize=11, fontweight="bold")
    
    ax.set_xlabel("Vibration Frequency (Hz)", fontsize=13, fontweight="bold")
    ax.set_ylabel("Power Spectral Density (rad²/s²/Hz)", fontsize=13, fontweight="bold")
    ax.set_title("Tulloch Limit-Cycle Resonance & Whipping Suppression\n"
                 "(Fast Fourier Transform of Drivetrain Twist Speed Differential)", 
                 fontsize=14, fontweight="bold", pad=15)
    
    ax.legend(fontsize=12, loc="upper right")
    ax.grid(True, which="both", linestyle="--", alpha=0.2)
    ax.set_xlim(0, 15)  # Focus on low-frequency structural modes
    
    out_path = os.path.join(RESULTS_DIR, "science_tulloch_fft.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved Tulloch resonance spectrum to: {out_path}")

if __name__ == "__main__":
    plot_3d_design_space()
    plot_vibration_spectra()
