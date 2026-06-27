#!/usr/bin/env python3
"""scripts/plot_ramp_traces.py

Generate paper-quality figures comparing OLD (instant k_mppt step) vs
NEW (soft-ramp controller) TRPT dynamic operation.

Expects CSVs in scripts/results/ramp_traces/ produced by record_ramp_traces.jl.

Output: scripts/results/ramp_traces/figures/*.png

Usage:
  python3 scripts/plot_ramp_traces.py
"""

import os, sys
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

# ── Style ────────────────────────────────────────────────────────────────
plt.rcParams.update({
    "figure.dpi": 150,
    "font.size": 10,
    "axes.titlesize": 12,
    "axes.labelsize": 10,
    "legend.fontsize": 9,
    "lines.linewidth": 1.5,
    "figure.figsize": (7, 4),
    "savefig.bbox": "tight",
    "savefig.dpi": 200,
})

RES_DIR = Path(__file__).resolve().parent / "results" / "ramp_traces"
FIG_DIR = RES_DIR / "figures"
FIG_DIR.mkdir(parents=True, exist_ok=True)

COLOUR_INSTANT = "#d62728"   # red — old
COLOUR_RAMP    = "#1f77b4"   # blue — new
COLOUR_FOS_SOFT = "#ff7f0e"  # orange
COLOUR_FOS_HARD = "#d62728"  # red

# ── Loaders ───────────────────────────────────────────────────────────────
def load(name):
    p = RES_DIR / f"{name}.csv"
    if not p.exists():
        print(f"  SKIP {name} — CSV not found")
        return None
    return pd.read_csv(p)

# ═══════════════════════════════════════════════════════════════════════════
# Figure 1: k_mppt(t) and P_gen(t) — old vs new
# ═══════════════════════════════════════════════════════════════════════════
def fig1_k_and_power():
    pairs = [
        ("canonical_10kw_instant", "canonical_10kw_softramp", "Canonical 10 kW"),
        ("v10_tight_50kw_instant",  "v10_tight_50kw_softramp",  "V10 Tight 50 kW"),
    ]
    
    for old_name, new_name, title in pairs:
        old = load(old_name)
        new = load(new_name)
        if old is None or new is None:
            continue
        
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(7, 6), sharex=True)
        
        # k_mppt
        ax1.plot(old["t"], old["k_mppt"], color=COLOUR_INSTANT, label="Instant step")
        ax1.plot(new["t"], new["k_mppt"], color=COLOUR_RAMP, label="Soft-ramp")
        ax1.set_ylabel("k_mppt (N·m·s²/rad²)")
        ax1.legend(loc="lower right")
        ax1.grid(True, alpha=0.3)
        ax1.set_title(f"{title} — MPPT Gain")
        
        # P_gen
        ax2.plot(old["t"], old["P_kw"], color=COLOUR_INSTANT, label="Instant step")
        ax2.plot(new["t"], new["P_kw"], color=COLOUR_RAMP, label="Soft-ramp")
        ax2.axhline(y=old["P_kw"].iloc[-1] * 0.8 if "ramp" in old_name else 10,
                     color="grey", linestyle="--", alpha=0.5, label="~80% rated")
        ax2.set_xlabel("Time (s)")
        ax2.set_ylabel("P_gen (kW)")
        ax2.legend(loc="lower right")
        ax2.grid(True, alpha=0.3)
        ax2.set_title("Generator Power")
        
        fig.tight_layout()
        out = FIG_DIR / f"fig1_kmppt_power_{title.lower().replace(' ','_')}.png"
        fig.savefig(out)
        plt.close(fig)
        print(f"  {out}")

# ═══════════════════════════════════════════════════════════════════════════
# Figure 2: FoS(t) with intervention bands — soft-ramp only
# ═══════════════════════════════════════════════════════════════════════════
def fig2_fos_bands():
    pairs = [
        ("canonical_10kw_softramp", "Canonical 10 kW (soft-ramp)"),
        ("v10_tight_50kw_softramp",  "V10 Tight 50 kW (soft-ramp)"),
    ]
    
    for name, title in pairs:
        df = load(name)
        if df is None:
            continue
        
        fig, ax = plt.subplots(figsize=(7, 4))
        
        ax.plot(df["t"], df["min_fos"], color=COLOUR_RAMP, label="min FoS")
        ax.axhline(y=2.5, color=COLOUR_FOS_SOFT, linestyle="--", alpha=0.7, label="Soft limit (2.5)")
        ax.axhline(y=1.5, color=COLOUR_FOS_HARD, linestyle=":", alpha=0.7, label="Hard floor (1.5)")
        ax.fill_between(df["t"], 1.5, 2.5, alpha=0.08, color=COLOUR_FOS_SOFT)
        ax.set_xlabel("Time (s)")
        ax.set_ylabel("Ring buckling FoS")
        ax.legend(loc="best")
        ax.grid(True, alpha=0.3)
        ax.set_title(f"{title} — Structural Margin")
        
        fig.tight_layout()
        out = FIG_DIR / f"fig2_fos_{title.lower().replace(' ','_').replace('(','').replace(')','')}.png"
        fig.savefig(out)
        plt.close(fig)
        print(f"  {out}")

# ═══════════════════════════════════════════════════════════════════════════
# Figure 3: Collapse margin(t) — novel constraint
# ═══════════════════════════════════════════════════════════════════════════
def fig3_collapse_margin():
    pairs = [
        ("canonical_10kw_softramp", "Canonical 10 kW (soft-ramp)"),
        ("v10_tight_50kw_softramp",  "V10 Tight 50 kW (soft-ramp)"),
    ]
    
    for name, title in pairs:
        df = load(name)
        if df is None:
            continue
        if "collapse_margin_deg" not in df.columns:
            continue
        # Filter out Inf (no controller active)
        margin = df["collapse_margin_deg"].replace([np.inf, -np.inf], np.nan)
        if margin.isna().all():
            continue
        
        fig, ax = plt.subplots(figsize=(7, 4))
        ax.plot(df["t"], margin, color="#2ca02c", label="min(δα* − |Δα|)")
        ax.axhline(y=5, color=COLOUR_FOS_HARD, linestyle="--", alpha=0.7, label="Freeze threshold (5°)")
        ax.set_xlabel("Time (s)")
        ax.set_ylabel("Collapse margin (°)")
        ax.legend(loc="best")
        ax.grid(True, alpha=0.3)
        ax.set_title(f"{title} — Distance to Tulloch Cliff")
        
        fig.tight_layout()
        out = FIG_DIR / f"fig3_margin_{title.lower().replace(' ','_').replace('(','').replace(')','')}.png"
        fig.savefig(out)
        plt.close(fig)
        print(f"  {out}")

# ═══════════════════════════════════════════════════════════════════════════
# Figure 4: Phase portrait — P_gen vs Δω
# ═══════════════════════════════════════════════════════════════════════════
def fig4_phase_portrait():
    pairs = [
        ("canonical_10kw_instant", "canonical_10kw_softramp", "Canonical 10 kW"),
        ("v10_tight_50kw_instant",  "v10_tight_50kw_softramp",  "V10 Tight 50 kW"),
    ]
    
    for old_name, new_name, title in pairs:
        old = load(old_name)
        new = load(new_name)
        if old is None or new is None:
            continue
        
        fig, ax = plt.subplots(figsize=(6, 6))
        
        # Downsample for clarity (every 10th point)
        ax.scatter(old["delta_omega"].iloc[::10], old["P_kw"].iloc[::10],
                   c=old["t"].iloc[::10], cmap="Reds", s=2, alpha=0.5, label="Instant step")
        ax.scatter(new["delta_omega"].iloc[::10], new["P_kw"].iloc[::10],
                   c=new["t"].iloc[::10], cmap="Blues", s=2, alpha=0.5, label="Soft-ramp")
        ax.set_xlabel("Δω = ω_hub − ω_gnd (rad/s)")
        ax.set_ylabel("P_gen (kW)")
        ax.legend(loc="best")
        ax.grid(True, alpha=0.3)
        ax.set_title(f"{title} — Phase Portrait")
        # Mark start and end
        ax.annotate("start", (old["delta_omega"].iloc[0], old["P_kw"].iloc[0]),
                     fontsize=8, color="grey")
        ax.annotate("end", (new["delta_omega"].iloc[-1], new["P_kw"].iloc[-1]),
                     fontsize=8, color=COLOUR_RAMP)
        
        fig.tight_layout()
        out = FIG_DIR / f"fig4_phase_{title.lower().replace(' ','_')}.png"
        fig.savefig(out)
        plt.close(fig)
        print(f"  {out}")

# ═══════════════════════════════════════════════════════════════════════════
# Figure 5: Wind ramp comparison
# ═══════════════════════════════════════════════════════════════════════════
def fig5_wind_ramp():
    old = load("wind_ramp_instant")
    new = load("wind_ramp_softramp")
    if old is None or new is None:
        print("  SKIP wind ramp — CSVs not found")
        return
    
    fig, axes = plt.subplots(3, 1, figsize=(7, 8), sharex=True)
    
    # Wind speed (reconstructed from time axis)
    t_ramp = 150.0
    v_wind = 7.0 + np.clip(old["t"] / t_ramp, 0, 1) * 7.0
    
    # k_mppt
    axes[0].plot(old["t"], old["k_mppt"], color=COLOUR_INSTANT, label="Instant k=11")
    axes[0].plot(new["t"], new["k_mppt"], color=COLOUR_RAMP, label="Soft-ramp")
    ax_twin = axes[0].twinx()
    ax_twin.plot(old["t"], v_wind, color="grey", linestyle=":", alpha=0.5, label="Wind (m/s)")
    ax_twin.set_ylabel("Wind (m/s)", color="grey")
    axes[0].set_ylabel("k_mppt")
    axes[0].legend(loc="upper left")
    axes[0].grid(True, alpha=0.3)
    axes[0].set_title("Wind Ramp 7→14 m/s — MPPT Gain")
    
    # P_gen
    axes[1].plot(old["t"], old["P_kw"], color=COLOUR_INSTANT, label="Instant step")
    axes[1].plot(new["t"], new["P_kw"], color=COLOUR_RAMP, label="Soft-ramp")
    axes[1].set_ylabel("P_gen (kW)")
    axes[1].legend(loc="upper left")
    axes[1].grid(True, alpha=0.3)
    axes[1].set_title("Generator Power")
    
    # ω_hub
    axes[2].plot(old["t"], old["omega_hub"] * 60 / (2*np.pi), color=COLOUR_INSTANT, label="Instant step")
    axes[2].plot(new["t"], new["omega_hub"] * 60 / (2*np.pi), color=COLOUR_RAMP, label="Soft-ramp")
    axes[2].set_xlabel("Time (s)")
    axes[2].set_ylabel("ω_hub (rpm)")
    axes[2].legend(loc="upper left")
    axes[2].grid(True, alpha=0.3)
    axes[2].set_title("Hub Speed")
    
    fig.tight_layout()
    out = FIG_DIR / "fig5_wind_ramp.png"
    fig.savefig(out)
    plt.close(fig)
    print(f"  {out}")

# ═══════════════════════════════════════════════════════════════════════════
# Figure 6: Summary table
# ═══════════════════════════════════════════════════════════════════════════
def fig6_summary_table():
    """Print a LaTeX-able summary table of key metrics."""
    scenarios = [
        ("canonical_10kw_instant",  "Canonical 10 kW — instant"),
        ("canonical_10kw_softramp",  "Canonical 10 kW — soft-ramp"),
        ("v10_tight_50kw_instant",   "V10 Tight 50 kW — instant"),
        ("v10_tight_50kw_softramp",  "V10 Tight 50 kW — soft-ramp"),
        ("wind_ramp_instant",        "Wind ramp — instant"),
        ("wind_ramp_softramp",       "Wind ramp — soft-ramp"),
    ]
    
    print("\n── Summary Table ──")
    print(f"{'Scenario':<35} {'t_to_rated(s)':>14} {'P_final(kW)':>12} {'ω_final(rpm)':>13} {'min_FoS':>8} {'min_margin(°)':>14}")
    print("-" * 100)
    
    for name, label in scenarios:
        df = load(name)
        if df is None or len(df) == 0:
            continue
        
        P_final = df["P_kw"].iloc[-1]
        ω_final = df["omega_hub"].iloc[-1] * 60 / (2 * np.pi)
        min_fos = df["min_fos"].min() if "min_fos" in df.columns else np.nan
        
        # Time to reach 80% of final power
        P_target = 0.8 * P_final
        t_rated = np.nan
        for i in range(len(df)):
            if df["P_kw"].iloc[i] >= P_target:
                t_rated = df["t"].iloc[i]
                break
        
        # Min collapse margin
        min_margin = np.nan
        if "collapse_margin_deg" in df.columns:
            m = df["collapse_margin_deg"].replace([np.inf, -np.inf], np.nan)
            if not m.isna().all():
                min_margin = m.min()
        
        print(f"{label:<35} {t_rated:>14.1f} {P_final:>12.2f} {ω_final:>13.1f} {min_fos:>8.2f} {min_margin:>14.1f}")
    
    print()

# ═══════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print("Generating ramp trace figures…")
    print()
    fig1_k_and_power()
    fig2_fos_bands()
    fig3_collapse_margin()
    fig4_phase_portrait()
    fig5_wind_ramp()
    fig6_summary_table()
    print()
    print(f"Done. Figures in: {FIG_DIR}")
