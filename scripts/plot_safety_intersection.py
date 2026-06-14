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

def plot_safety_intersection():
    df = pd.read_csv(METRICS_CSV)
    
    # Exclude failed rows (NaNs)
    df = df.dropna(subset=["payout_duration", "wind_speed", "fos_buckling_min"])
    
    x = df["payout_duration"].values
    y = df["wind_speed"].values
    z = df["fos_buckling_min"].values
    
    # Create grid for contour interpolation
    xi = np.linspace(2.0, 15.0, 100)
    yi = np.linspace(11.0, 20.0, 100)
    XI, YI = np.meshgrid(xi, yi)
    
    # Interpolate FoS data onto the 2D grid
    ZI = griddata((x, y), z, (XI, YI), method='linear')
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # Contour color filled: Red (low FoS / buckling) to Green (high FoS / safe)
    levels = [0.0, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0]
    colors = ["#ff1744", "#ff9100", "#ffea00", "#ccff90", "#69f0ae", "#00e676"]
    
    cf = ax.contourf(XI, YI, ZI, levels=levels, colors=colors, alpha=0.85)
    cbar = fig.colorbar(cf, ax=ax, ticks=levels)
    cbar.set_label("CFRP Strut Buckling Factor of Safety (FoS)", fontsize=12, fontweight="bold")
    
    # Draw bold red intersection line at exactly FoS = 1.5 (structural limit)
    cs = ax.contour(XI, YI, ZI, levels=[1.5], colors=["white"], linewidths=[3.5], linestyles=["-"])
    ax.clabel(cs, inline=True, fmt="LIMIT: FoS = 1.5", fontsize=11, colors="white")
    
    # Scatter the actual data points
    ax.scatter(x, y, c='white', edgecolor='black', s=25, alpha=0.5, label="Simulation Runs")
    
    # Annotate Zones
    ax.text(8.0, 13.0, "SAFE OPERATING ZONE\n(FoS ≥ 1.5)", 
            color="#00e676", fontsize=14, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.5", fc="black", alpha=0.7, ec="#00e676"))
            
    ax.text(3.5, 18.5, "CFRP BUCKLING ZONE\n(FoS < 1.5)", 
            color="#ff1744", fontsize=14, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.5", fc="black", alpha=0.7, ec="#ff1744"))
            
    ax.set_xlabel("Payout Duration (s) — [Faster Winch Payout →]", fontsize=13, fontweight="bold")
    ax.set_ylabel("Wind Speed (m/s) — [Increasing Aerodynamic Load →]", fontsize=13, fontweight="bold")
    ax.set_title("Structural Safety Boundary Intersection Plane\n"
                 "(Spacer Ring CFRP Strut Buckling FoS Limit Space)", 
                 fontsize=14, fontweight="bold", pad=15)
    
    ax.set_xlim(2.0, 15.0)
    ax.set_ylim(11.0, 20.0)
    ax.grid(True, linestyle="--", alpha=0.15)
    ax.legend(loc="lower right")
    
    out_path = os.path.join(RESULTS_DIR, "science_safety_intersection.png")
    plt.savefig(out_path, dpi=fig_dpi, bbox_inches="tight")
    plt.close()
    print(f"✓ Saved Structural Safety Intersection Plane to: {out_path}")

if __name__ == "__main__":
    plot_safety_intersection()
