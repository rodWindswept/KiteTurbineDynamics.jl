#!/usr/bin/env python3
"""Generate comparison charts: original (k=62) vs tuned (k=550) for V10 Tight."""

import numpy as np
import pandas as pd
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

RES_DIR  = Path(__file__).resolve().parent / "results" / "ramp_traces"
FIG_DIR  = RES_DIR / "figures"
FIG_DIR.mkdir(exist_ok=True)

C_ORIG    = "#d62728"
C_TUNED   = "#1f77b4"
C_FOS_SOFT = "#ff7f0e"
C_FOS_HARD = "#d62728"
C_TWIST    = "#9467bd"
C_MARGIN   = "#2ca02c"
C_IDLE     = "#e0e0e0"
C_RAMPING  = "#ffd700"
C_HOLDING  = "#2ca02c"

def load(name):
    p = RES_DIR / f"{name}.csv"
    if not p.exists():
        return None
    return pd.read_csv(p)

def load_tuned(name):
    p = RES_DIR / "tuned" / f"{name}.csv"
    if not p.exists():
        return None
    return pd.read_csv(p)

def add_derived(df):
    df["omega_hub_rpm"] = df["omega_hub"] * 60 / (2*np.pi)
    df["omega_gnd_rpm"] = df["omega_gnd"] * 60 / (2*np.pi)
    df["delta_omega_rpm"] = (df["omega_hub"] - df["omega_gnd"]) * 60 / (2*np.pi)
    df["tau_gen"] = df["k_mppt"] * df["omega_gnd"]**2
    df["T_max_kN"] = df["T_max_N"] / 1000.0

def panel_label(ax, letter, x=-0.08, y=1.05):
    ax.text(x, y, letter, transform=ax.transAxes, fontsize=13, fontweight="bold", va="top")

def save_close(fig, name):
    out = FIG_DIR / name
    fig.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  {out}")

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 8 — V10 Tight: Original vs Tuned Comparison
# ═══════════════════════════════════════════════════════════════════════════
def fig8_comparison():
    orig_inst = load("v10_tight_50kw_instant")
    orig_ramp = load("v10_tight_50kw_softramp")
    tuned_inst = load_tuned("v10_tight_tuned_instant")
    tuned_ramp = load_tuned("v10_tight_tuned_softramp")

    if any(x is None for x in [orig_inst, orig_ramp, tuned_inst, tuned_ramp]):
        print("  SKIP fig8 — missing CSVs")
        return

    for df in [orig_inst, orig_ramp, tuned_inst, tuned_ramp]:
        add_derived(df)

    fig, axes = plt.subplots(6, 1, figsize=(12, 18), sharex=True)

    # Panel A: k_mppt
    ax = axes[0]
    ax.plot(orig_inst["t"], orig_inst["k_mppt"], color=C_ORIG, linewidth=1.5, label="Original (k=62)")
    ax.plot(tuned_inst["t"], tuned_inst["k_mppt"], color=C_TUNED, linewidth=1.5, label="Tuned (k=550)")
    ax.plot(tuned_ramp["t"], tuned_ramp["k_mppt"], color=C_TUNED, linewidth=1.2, linestyle="--", alpha=0.7, label="Tuned + controller")
    ax.set_ylabel("k_mppt\n(N·m·s²/rad²)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "A")

    # Panel B: Power
    ax = axes[1]
    ax.plot(orig_inst["t"], orig_inst["P_kw"], color=C_ORIG, linewidth=1.5)
    ax.plot(tuned_inst["t"], tuned_inst["P_kw"], color=C_TUNED, linewidth=1.5)
    ax.plot(tuned_ramp["t"], tuned_ramp["P_kw"], color=C_TUNED, linewidth=1.2, linestyle="--", alpha=0.7)
    ax.axhline(y=50.0, color="grey", linestyle="--", alpha=0.5, label="Rated 50 kW")
    ax.set_ylabel("P_gen (kW)")
    ax.grid(True, alpha=0.3)
    # Annotations
    ax.annotate("132 kW (2.6×)", xy=(85, 132), fontsize=9, color=C_ORIG, ha="right",
                bbox=dict(boxstyle="round,pad=0.3", fc="white", alpha=0.8))
    ax.annotate("49→21 kW\ndecaying", xy=(55, 21), fontsize=9, color=C_TUNED,
                ha="left", bbox=dict(boxstyle="round,pad=0.3", fc="white", alpha=0.8))
    panel_label(ax, "B")

    # Panel C: Speeds
    ax = axes[2]
    ax.plot(orig_inst["t"], orig_inst["omega_hub_rpm"], color=C_ORIG, linewidth=1.5, label="ω rotor (orig)")
    ax.plot(orig_inst["t"], orig_inst["omega_gnd_rpm"], color=C_ORIG, linewidth=0.7, linestyle=":", alpha=0.6, label="ω gen (orig)")
    ax.plot(tuned_inst["t"], tuned_inst["omega_hub_rpm"], color=C_TUNED, linewidth=1.5, label="ω rotor (tuned)")
    ax.plot(tuned_inst["t"], tuned_inst["omega_gnd_rpm"], color=C_TUNED, linewidth=0.7, linestyle=":", alpha=0.6, label="ω gen (tuned)")
    ax.set_ylabel("Speed (rpm)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "C")

    # Panel D: FoS — THE KEY PANEL
    ax = axes[3]
    ax.plot(orig_inst["t"], orig_inst["min_fos"], color=C_ORIG, linewidth=1.5, alpha=0.6, label="Original (k=62)")
    ax.plot(tuned_inst["t"], tuned_inst["min_fos"], color=C_TUNED, linewidth=1.8, label="Tuned (k=550)")
    ax.axhline(y=2.5, color=C_FOS_SOFT, linestyle="--", alpha=0.7, label="Soft limit (2.5)")
    ax.axhline(y=1.5, color=C_FOS_HARD, linestyle=":", alpha=0.7, label="Hard floor (1.5)")
    ax.axhline(y=1.0, color="black", linestyle="-", alpha=0.3, linewidth=0.5)
    ax.fill_between(tuned_inst["t"], 0, 1.0, alpha=0.12, color="red")
    ax.fill_between(tuned_inst["t"], 1.0, 1.5, alpha=0.06, color=C_FOS_SOFT)
    ax.set_ylabel("Ring buckling\nFoS")
    # Annotations
    ax.annotate("Original: instant\ncollapse at t<5s", xy=(3, 0.6), fontsize=8, color=C_ORIG, ha="left")
    ax.annotate("Tuned: progressive\nbuckling over 60s", xy=(30, 0.35), fontsize=8, color=C_TUNED, ha="left")
    ax.text(45, 0.5, "BOTH FAIL\n(FoS < 1.0)", fontsize=12, color="red", ha="center", fontweight="bold")
    ax.set_ylim(0, 5)
    ax.grid(True, alpha=0.3)
    panel_label(ax, "D")

    # Panel E: T_max
    ax = axes[4]
    ax.plot(orig_inst["t"], orig_inst["T_max_kN"], color=C_ORIG, linewidth=1.5, alpha=0.6)
    ax.plot(tuned_inst["t"], tuned_inst["T_max_kN"], color=C_TUNED, linewidth=1.8)
    ax.set_ylabel("T_max (kN)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "E")

    # Panel F: Twist
    ax = axes[5]
    ax.plot(orig_inst["t"], orig_inst["twist_deg"], color=C_ORIG, linewidth=1.5, alpha=0.6, label="Original (k=62)")
    ax.plot(tuned_inst["t"], tuned_inst["twist_deg"], color=C_TUNED, linewidth=1.8, label="Tuned (k=550)")
    ax.set_ylabel("Total twist\nΣΔα (°)")
    ax.set_xlabel("Time (s)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "F")

    axes[0].legend(loc="upper right", fontsize=8, ncol=2)
    fig.suptitle("V10 Tight — Original (k=62) vs Tuned (k=550)", fontsize=14, fontweight="bold", y=0.995)
    fig.text(0.5, 0.008, "Original: overspeeds to 132 kW, FoS collapses instantly.  Tuned: hits 50 kW briefly then buckles progressively — power decays to 21 kW.",
             ha="center", fontsize=8, color="grey")
    save_close(fig, "fig8_tuned_comparison.png")

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 9 — Hunt sweep: P_gen and FoS vs k_mppt
# ═══════════════════════════════════════════════════════════════════════════
def fig9_hunt_sweep():
    """Plot the hunt sweep results as an annotated P/FoS vs k curve."""
    hunt_data = [
        (50, 7.77, 59.7, 2.05), (100, 11.50, 57.1, 1.97),
        (150, 13.48, 54.9, 1.96), (200, 14.72, 53.3, 1.90),
        (250, 15.74, 51.9, 1.78), (300, 16.37, 50.2, 1.60),
        (350, 16.37, 48.3, 1.54), (400, 19.24, 47.5, 1.64),
        (450, 23.94, 47.8, 1.66), (500, 31.28, 48.8, 1.17),
        (550, 49.21, 52.3, 0.75), (600, 51.29, 51.1, 0.69),
    ]
    ks = [d[0] for d in hunt_data]
    ps = [d[1] for d in hunt_data]
    ws = [d[2] for d in hunt_data]
    fos = [d[3] for d in hunt_data]

    fig, axes = plt.subplots(2, 1, figsize=(10, 8), sharex=True)

    # Panel A: Power and ω vs k
    ax = axes[0]
    ax.plot(ks, ps, "o-", color=C_TUNED, linewidth=2, markersize=8, label="P_gen (kW)")
    ax.axhline(y=50, color="grey", linestyle="--", alpha=0.5, label="Rated 50 kW")
    ax2 = ax.twinx()
    ax2.plot(ks, ws, "s-", color=C_TWIST, linewidth=1.5, markersize=6, alpha=0.7, label="ω (rpm)")
    ax2.set_ylabel("ω_hub (rpm)", color=C_TWIST)
    ax2.tick_params(axis="y", labelcolor=C_TWIST)
    ax.set_ylabel("P_gen (kW)", color=C_TUNED)
    ax.tick_params(axis="y", labelcolor=C_TUNED)
    # Annotate the target crossing
    ax.annotate("k≈550 → 49.2 kW", xy=(550, 49.2), fontsize=10, color=C_TUNED, fontweight="bold",
                xytext=(420, 55), arrowprops=dict(arrowstyle="->", color=C_TUNED))
    ax.grid(True, alpha=0.3)
    ax.legend(loc="upper left", fontsize=8)
    ax2.legend(loc="upper right", fontsize=8)
    panel_label(ax, "A")

    # Panel B: FoS vs k — the constraint
    ax = axes[1]
    colors = [C_TUNED if v >= 1.5 else C_FOS_HARD for v in fos]
    ax.bar(ks, fos, width=25, color=colors, edgecolor="white", alpha=0.8)
    ax.axhline(y=1.5, color=C_FOS_SOFT, linestyle="--", linewidth=1.5, alpha=0.8, label="FoS floor (1.5)")
    ax.axhline(y=1.0, color="black", linestyle="-", alpha=0.3)
    ax.fill_between([0, 650], 0, 1.0, alpha=0.08, color="red")
    ax.fill_between([0, 650], 1.0, 1.5, alpha=0.04, color=C_FOS_SOFT)
    ax.set_xlabel("k_mppt (N·m·s²/rad²)")
    ax.set_ylabel("min FoS")
    ax.set_ylim(0, 3)
    ax.grid(True, alpha=0.3, axis="y")
    ax.legend(fontsize=8)
    # Annotate the safe/unsafe regions
    ax.annotate("SAFE\n(FoS ≥ 1.5)", xy=(100, 2.2), fontsize=11, ha="center", color=C_TUNED, fontweight="bold")
    ax.annotate("UNSAFE\n(FoS < 1.5)", xy=(500, 1.1), fontsize=11, ha="center", color="red", fontweight="bold")
    ax.annotate("Power target\nat k=550\nFoS=0.75 [FAIL]", xy=(550, 0.75), fontsize=9, color="red", ha="center",
                xytext=(550, 0.3), arrowprops=dict(arrowstyle="->", color="red"))
    panel_label(ax, "B")

    fig.suptitle("V10 Tight k_mppt Hunt — Power and Structural Safety", fontsize=14, fontweight="bold")
    fig.text(0.5, 0.01, "12-point sweep, 3s each.  FoS crosses below 1.5 at k≈350 — well before 50 kW target at k≈550.",
             ha="center", fontsize=8, color="grey")
    save_close(fig, "fig9_hunt_sweep.png")


if __name__ == "__main__":
    print("Generating V10 Tight comparison figures…\n")
    fig8_comparison()
    fig9_hunt_sweep()
    print("\nDone.")
