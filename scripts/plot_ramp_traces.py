#!/usr/bin/env python3
"""scripts/plot_ramp_traces.py — AWEC 2026 Porto: Soft-Ramp Controller Paper Figures.

Generates 7 publication-quality multi-panel figures from the ramp_traces CSVs.
Spec: docs/porto-2026/charting-spec.md
"""

import numpy as np
import pandas as pd
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from scipy import signal
import warnings
warnings.filterwarnings("ignore")

# ═══════════════════════════════════════════════════════════════════════════
RES_DIR  = Path(__file__).resolve().parent / "results" / "ramp_traces"
FIG_DIR  = RES_DIR / "figures"
FIG_DIR.mkdir(exist_ok=True)

# Colour palette — consistent across all figures
C_INSTANT   = "#d62728"   # red
C_RAMP      = "#1f77b4"   # blue
C_FOS_SOFT  = "#ff7f0e"   # amber
C_FOS_HARD  = "#d62728"   # red
C_MARGIN    = "#2ca02c"   # green
C_WIND      = "#7f7f7f"   # grey
C_IDLE      = "#e0e0e0"   # light grey
C_RAMPING   = "#ffd700"   # gold
C_HOLDING   = "#2ca02c"   # green
C_TWIST     = "#9467bd"   # purple


def load(name: str) -> pd.DataFrame | None:
    p = RES_DIR / f"{name}.csv"
    if not p.exists():
        return None
    return pd.read_csv(p)


def add_derived(df: pd.DataFrame):
    """Add derived channels in-place."""
    df["omega_hub_rpm"] = df["omega_hub"] * 60 / (2 * np.pi)
    df["omega_gnd_rpm"] = df["omega_gnd"] * 60 / (2 * np.pi)
    df["delta_omega_rpm"] = (df["omega_hub"] - df["omega_gnd"]) * 60 / (2 * np.pi)
    df["tau_gen"] = df["k_mppt"] * df["omega_gnd"] ** 2
    df["P_mech"] = df["tau_gen"] * df["omega_gnd"] / 1000.0
    df["T_max_kN"] = df["T_max_N"] / 1000.0
    df["fos_margin"] = df["min_fos"] - 1.5


def smart_legend(axes, loc="upper right", ncol=2):
    """Place legend on the topmost axis of a multi-panel figure."""
    h, l = axes[0].get_legend_handles_labels()
    if h:
        axes[0].legend(h, l, loc=loc, ncol=ncol, fontsize=8, framealpha=0.9)


def panel_label(ax, letter, x=-0.08, y=1.05):
    ax.text(x, y, letter, transform=ax.transAxes, fontsize=13, fontweight="bold", va="top")


def save_close(fig, name):
    out = FIG_DIR / name
    fig.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  {out}")


# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 1 — Canonical 10 kW Full-State Dashboard
# ═══════════════════════════════════════════════════════════════════════════
def fig1_canonical_dashboard():
    old = load("canonical_10kw_instant")
    new = load("canonical_10kw_softramp")
    if old is None or new is None:
        return
    for df in (old, new):
        add_derived(df)

    fig, axes = plt.subplots(6, 1, figsize=(12, 18), sharex=True)
    t_old, t_new = old["t"], new["t"]

    # Panel A: k_mppt + state bands
    ax = axes[0]
    ax.plot(t_old, old["k_mppt"], color=C_INSTANT, linewidth=1.5, label="Open-loop setpoint k=11")
    ax.plot(t_new, new["k_mppt"], color=C_RAMP, linewidth=1.5, label="Soft-ramp (k_min=5)")
    # State background bands
    _add_state_bands(ax, new, t_max=60)
    ax.set_ylabel("k_mppt\n(N·m·s²/rad²)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "A")

    # Panel B: Power
    ax = axes[1]
    ax.plot(t_old, old["P_kw"], color=C_INSTANT, linewidth=1.5)
    ax.plot(t_new, new["P_kw"], color=C_RAMP, linewidth=1.5)
    ax.axhline(y=10.0, color="grey", linestyle="--", alpha=0.5, label="Rated 10 kW")
    ax.axhline(y=8.0, color="grey", linestyle=":", alpha=0.4, label="80% rated")
    ax.set_ylabel("P_gen (kW)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "B")
    # Annotate t_to_rated
    for i in range(len(new)):
        if new["P_kw"].iloc[i] >= 8.0:
            ax.annotate(f"t→80% = {new['t'].iloc[i]:.1f}s",
                        (new["t"].iloc[i], new["P_kw"].iloc[i]),
                        fontsize=8, color=C_RAMP,
                        xytext=(15, 0), textcoords="offset points")
            break

    # Panel C: Speeds
    ax = axes[2]
    ax.plot(t_old, old["omega_hub_rpm"], color=C_INSTANT, linewidth=1.5, label="ω_hub (rotor)")
    ax.plot(t_old, old["omega_gnd_rpm"], color=C_INSTANT, linewidth=0.7, linestyle=":", alpha=0.6, label="ω_gnd (gen)")
    ax.plot(t_new, new["omega_hub_rpm"], color=C_RAMP, linewidth=1.5, label="ω_hub (rotor)")
    ax.plot(t_new, new["omega_gnd_rpm"], color=C_RAMP, linewidth=0.7, linestyle=":", alpha=0.6, label="ω_gnd (gen)")
    ax.axhline(y=5, color="grey", linestyle="--", alpha=0.4, label="IDLE→RAMP (5 rpm)")
    ax.set_ylabel("Speed (rpm)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "C")

    # Panel D: Slip
    ax = axes[3]
    ax.plot(t_old, old["delta_omega_rpm"], color=C_INSTANT, linewidth=1.5)
    ax.plot(t_new, new["delta_omega_rpm"], color=C_RAMP, linewidth=1.5)
    ax.set_ylabel("Δω = ω_hub − ω_gnd\n(rpm)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "D")
    # Mark peak slip
    idx_max = new["delta_omega_rpm"].idxmax()
    ax.annotate(f"peak {new['delta_omega_rpm'].iloc[idx_max]:.1f} rpm",
                (new["t"].iloc[idx_max], new["delta_omega_rpm"].iloc[idx_max]),
                fontsize=8, color=C_RAMP)

    # Panel E: Structural health
    ax = axes[4]
    ax.plot(t_new, new["min_fos"], color=C_RAMP, linewidth=1.5, label="min FoS")
    ax.axhline(y=2.5, color=C_FOS_SOFT, linestyle="--", alpha=0.7, label="Soft limit (2.5)")
    ax.axhline(y=1.5, color=C_FOS_HARD, linestyle=":", alpha=0.7, label="Hard floor (1.5)")
    ax.fill_between(t_new, 1.5, 2.5, alpha=0.06, color=C_FOS_SOFT)
    # Clip to show steady-state range; startup spike goes to ~2000 at t=0
    ax.set_ylim(0, 50)
    ax.set_ylabel("Ring buckling\nFoS")
    ax2 = ax.twinx()
    ax2.plot(t_new, new["T_max_kN"], color=C_TWIST, linewidth=0.8, alpha=0.7, label="T_max (kN)")
    ax2.set_ylabel("T_max (kN)", color=C_TWIST)
    ax2.tick_params(axis="y", labelcolor=C_TWIST)
    ax.grid(True, alpha=0.3)
    panel_label(ax, "E")

    # Panel F: TRPT state
    ax = axes[5]
    ax.plot(t_new, new["twist_deg"], color=C_TWIST, linewidth=1.5, label="Total twist ΣΔα (°)")
    ax.set_ylabel("Twist (°)", color=C_TWIST)
    ax.tick_params(axis="y", labelcolor=C_TWIST)
    ax3 = ax.twinx()
    margin = new["collapse_margin_deg"].replace([np.inf, -np.inf], np.nan)
    ax3.plot(t_new, margin, color=C_MARGIN, linewidth=1.5, label="Collapse margin (°)")
    ax3.axhline(y=5, color=C_FOS_HARD, linestyle="--", alpha=0.7, label="Freeze (5°)")
    ax3.set_ylabel("Collapse margin (°)", color=C_MARGIN)
    ax3.tick_params(axis="y", labelcolor=C_MARGIN)
    ax.grid(True, alpha=0.3)
    ax.set_xlabel("Time (s)")
    panel_label(ax, "F")

    smart_legend(axes)
    fig.suptitle("Canonical 5-line 10 kW — Full-State Controller Comparison",
                 fontsize=14, fontweight="bold", y=0.995)
    fig.text(0.5, 0.008, "v_rated=11 m/s (wind shear ℓ=⅐), T_sim=60 s, dt=4×10⁻⁵ s, frames every 500 steps",
             ha="center", fontsize=8, color="grey")
    save_close(fig, "fig1_canonical_dashboard.png")


def _add_state_bands(ax, df, t_max):
    """Add background colour bands for controller state transitions."""
    if "state" not in df.columns:
        return
    states = df["state"].values
    t = df["t"].values
    i = 0
    y0, y1 = ax.get_ylim() if ax.get_ylim()[0] != 0 else (0, 1)
    ax.set_ylim(y0, y1)
    while i < len(states):
        s = states[i]
        j = i
        while j < len(states) and states[j] == s:
            j += 1
        t0 = t[i]
        t1 = t[min(j, len(t) - 1)]
        color = {"IDLE": C_IDLE, "RAMPING": C_RAMPING, "HOLDING": C_HOLDING, "fixed": "none"}.get(s, "none")
        if color != "none":
            ax.axvspan(t0, t1, alpha=0.12, color=color, linewidth=0)
        i = j


# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 2 — V10 Tight 50 kW Full-State Dashboard
# ═══════════════════════════════════════════════════════════════════════════
def fig2_v10_dashboard():
    old = load("v10_tight_50kw_instant")
    new = load("v10_tight_50kw_softramp")
    if old is None or new is None:
        return
    for df in (old, new):
        add_derived(df)

    fig, axes = plt.subplots(6, 1, figsize=(12, 18), sharex=True)
    t_old, t_new = old["t"], new["t"]

    # Panel A: k_mppt
    ax = axes[0]
    ax.plot(t_old, old["k_mppt"], color=C_INSTANT, linewidth=1.5, label="Open-loop setpoint k=62")
    ax.plot(t_new, new["k_mppt"], color=C_RAMP, linewidth=1.5, label="Soft-ramp (k_min=20)")
    _add_state_bands(ax, new, t_max=90)
    ax.set_ylabel("k_mppt\n(N·m·s²/rad²)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "A")

    # Panel B: Power
    ax = axes[1]
    ax.plot(t_old, old["P_kw"], color=C_INSTANT, linewidth=1.5)
    ax.plot(t_new, new["P_kw"], color=C_RAMP, linewidth=1.5)
    ax.axhline(y=50.0, color="grey", linestyle="--", alpha=0.5, label="Rated 50 kW")
    ax.axhline(y=40.0, color="grey", linestyle=":", alpha=0.4, label="80% rated")
    ax.set_ylabel("P_gen (kW)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "B")
    # Annotations
    ax.annotate("132 kW\n(2.6× rated)", xy=(85, 132), fontsize=9, color=C_INSTANT,
                ha="right", bbox=dict(boxstyle="round,pad=0.3", fc="white", alpha=0.8))
    ax.annotate("171 kW\n(3.4× rated)", xy=(85, 171), fontsize=9, color=C_RAMP,
                ha="left", bbox=dict(boxstyle="round,pad=0.3", fc="white", alpha=0.8))

    # Panel C: Speeds
    ax = axes[2]
    ax.plot(t_old, old["omega_hub_rpm"], color=C_INSTANT, linewidth=1.5, label="ω_hub (rotor)")
    ax.plot(t_old, old["omega_gnd_rpm"], color=C_INSTANT, linewidth=0.7, linestyle=":", alpha=0.6, label="ω_gnd (gen)")
    ax.plot(t_new, new["omega_hub_rpm"], color=C_RAMP, linewidth=1.5, label="ω_hub (rotor)")
    ax.plot(t_new, new["omega_gnd_rpm"], color=C_RAMP, linewidth=0.7, linestyle=":", alpha=0.6, label="ω_gnd (gen)")
    ax.axhline(y=5, color="grey", linestyle="--", alpha=0.4)
    ax.set_ylabel("Speed (rpm)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "C")

    # Panel D: Slip
    ax = axes[3]
    ax.plot(t_old, old["delta_omega_rpm"], color=C_INSTANT, linewidth=1.5)
    ax.plot(t_new, new["delta_omega_rpm"], color=C_RAMP, linewidth=1.5)
    ax.set_ylabel("Δω (rpm)")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "D")

    # Panel E: Structural health — CRITICAL
    ax = axes[4]
    ax.plot(t_new, new["min_fos"], color=C_RAMP, linewidth=1.5, label="min FoS")
    ax.axhline(y=2.5, color=C_FOS_SOFT, linestyle="--", alpha=0.7)
    ax.axhline(y=1.5, color=C_FOS_HARD, linestyle=":", alpha=0.7)
    ax.axhline(y=1.0, color="black", linestyle="-", alpha=0.3, linewidth=0.5)
    ax.fill_between(t_new, 0, 1.0, alpha=0.12, color="red")
    ax.fill_between(t_new, 1.0, 1.5, alpha=0.06, color=C_FOS_SOFT)
    ax.fill_between(t_new, 1.5, 2.5, alpha=0.04, color=C_FOS_SOFT)
    ax.text(45, 0.7, "STRUCTURAL FAILURE\n(FoS < 1.0)", fontsize=10, color="red",
            ha="center", fontweight="bold", alpha=0.9)
    ax.set_ylabel("Ring buckling\nFoS")
    ax2 = ax.twinx()
    ax2.plot(t_new, new["T_max_kN"], color=C_TWIST, linewidth=0.8, alpha=0.7)
    ax2.set_ylabel("T_max (kN)", color=C_TWIST)
    ax2.tick_params(axis="y", labelcolor=C_TWIST)
    ax.grid(True, alpha=0.3)
    panel_label(ax, "E")

    # Panel F: TRPT state
    ax = axes[5]
    ax.plot(t_new, new["twist_deg"], color=C_TWIST, linewidth=1.5)
    ax.set_ylabel("Twist (°)", color=C_TWIST)
    ax.tick_params(axis="y", labelcolor=C_TWIST)
    ax3 = ax.twinx()
    margin = new["collapse_margin_deg"].replace([np.inf, -np.inf], np.nan)
    ax3.plot(t_new, margin, color=C_MARGIN, linewidth=1.5)
    ax3.axhline(y=5, color=C_FOS_HARD, linestyle="--", alpha=0.7)
    ax3.set_ylabel("Collapse margin (°)", color=C_MARGIN)
    ax3.tick_params(axis="y", labelcolor=C_MARGIN)
    ax3.text(45, 48, "Tulloch cliff not reached —\nring buckling fails first",
             fontsize=8, color=C_MARGIN, ha="center")
    ax.grid(True, alpha=0.3)
    ax.set_xlabel("Time (s)")
    panel_label(ax, "F")

    smart_legend(axes)
    fig.suptitle("V10 Tight 50 kW — Full-State Controller Comparison",
                 fontsize=14, fontweight="bold", y=0.995)
    fig.text(0.5, 0.008, "49.2 kg, 3 expansion rotors, n_lines=3, rings=22.  v_rated=11 m/s, T_sim=90 s",
             ha="center", fontsize=8, color="grey")
    save_close(fig, "fig2_v10_dashboard.png")


# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 3 — Wind Ramp Triptych
# ═══════════════════════════════════════════════════════════════════════════
def fig3_wind_ramp_triptych():
    old = load("wind_ramp_instant")
    new = load("wind_ramp_softramp")
    if old is None or new is None:
        return
    for df in (old, new):
        add_derived(df)

    t_ramp = 150.0
    v_wind = 7.0 + np.clip(old["t"] / t_ramp, 0, 1) * 7.0

    fig = plt.figure(figsize=(18, 7))

    # Panel A: Operating trajectory in (ω, P) space
    ax = fig.add_subplot(1, 3, 1)
    n_pts = len(old)
    sc1 = ax.scatter(old["omega_hub_rpm"].iloc[::5], old["P_kw"].iloc[::5],
                      c=old["t"].iloc[::5], cmap="Reds", s=3, alpha=0.6, label="Open-loop setpoint k=11")
    sc2 = ax.scatter(new["omega_hub_rpm"].iloc[::5], new["P_kw"].iloc[::5],
                      c=new["t"].iloc[::5], cmap="Blues", s=3, alpha=0.6, label="Soft-ramp (k=30)")
    # Wind isolines: P ≈ ½ρv³πR²Cp for Cp≈0.22 at several v
    for v, ls in [(7, ":"), (9, "--"), (11, "-"), (14, "-.")]:
        omega_range = np.linspace(20, 140, 100)
        P_ideal = 0.5 * 1.225 * v**3 * np.pi * 25 * 0.22 / 1000  # rough
        ax.axhline(y=P_ideal, color="grey", linestyle=ls, alpha=0.3, linewidth=0.5)
        ax.text(135, P_ideal, f"{v} m/s", fontsize=7, color="grey", alpha=0.6, va="center")
    ax.set_xlabel("ω_hub (rpm)")
    ax.set_ylabel("P_gen (kW)")
    ax.legend(fontsize=7, loc="upper left")
    ax.grid(True, alpha=0.3)
    ax.set_title("Operating Trajectory", fontsize=11, fontweight="bold")
    panel_label(ax, "A", x=-0.12)

    # Panel B: Structural margin vs wind
    ax = fig.add_subplot(1, 3, 2)
    ax.plot(v_wind, old["min_fos"], color=C_INSTANT, linewidth=1.5, label="Open-loop setpoint k=11")
    ax.plot(v_wind, new["min_fos"], color=C_RAMP, linewidth=1.5, label="Soft-ramp (k=30)")
    ax.axhline(y=2.5, color=C_FOS_SOFT, linestyle="--", alpha=0.7)
    ax.axhline(y=1.5, color=C_FOS_HARD, linestyle=":", alpha=0.7)
    ax.fill_between([7, 14], 1.5, 2.5, alpha=0.06, color=C_FOS_SOFT)
    ax.fill_between([7, 14], 0, 1.5, alpha=0.04, color=C_FOS_HARD)
    ax.set_xlabel("Wind speed (m/s)")
    ax.set_ylabel("Ring buckling FoS")
    ax.legend(fontsize=7, loc="lower left")
    ax.grid(True, alpha=0.3)
    ax.set_title("Structural Margin vs Wind", fontsize=11, fontweight="bold")
    ax.text(12, 1.8, "Soft-ramp preserves FoS\nuntil v≈11 m/s", fontsize=7, color=C_RAMP)
    panel_label(ax, "B", x=-0.12)

    # Panel C: Torsional loading
    ax = fig.add_subplot(1, 3, 3)
    ax.plot(v_wind, old["twist_deg"], color=C_INSTANT, linewidth=1.5, label="Twist (°)")
    ax.plot(v_wind, new["twist_deg"], color=C_RAMP, linewidth=1.5)
    ax.set_xlabel("Wind speed (m/s)")
    ax.set_ylabel("Total twist ΣΔα (°)", color=C_TWIST)
    ax.tick_params(axis="y", labelcolor=C_TWIST)
    ax2 = ax.twinx()
    ax2.plot(v_wind, old["T_max_kN"], color=C_INSTANT, linewidth=1, linestyle="--", alpha=0.6, label="T_max (kN)")
    ax2.plot(v_wind, new["T_max_kN"], color=C_RAMP, linewidth=1, linestyle="--", alpha=0.6)
    ax2.set_ylabel("T_max (kN)", color=C_MARGIN)
    ax2.tick_params(axis="y", labelcolor=C_MARGIN)
    ax.grid(True, alpha=0.3)
    ax.set_title("TRPT Torsional Loading", fontsize=11, fontweight="bold")
    ax.text(12, 300, "Fixed: higher ω →\nmore twist → more load", fontsize=7, color=C_INSTANT)
    ax.text(8, 450, "Soft-ramp: lower ω →\nless twist → relief", fontsize=7, color=C_RAMP)
    panel_label(ax, "C", x=-0.12)

    fig.suptitle("Wind Ramp 7→14 m/s — Canonical 5-line 10 kW", fontsize=14, fontweight="bold", y=1.01)
    fig.text(0.5, 0.01, "T_ramp=150 s, k_mppt: instant=11, soft-ramp starts at 5→ramps to k_max=30→HOLDING",
             ha="center", fontsize=8, color="grey")
    save_close(fig, "fig3_wind_ramp_triptych.png")


# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 4 — Structural Envelope: FoS vs k_mppt Operating Map
# ═══════════════════════════════════════════════════════════════════════════
def fig4_structural_envelope():
    scenarios = [
        ("canonical_10kw_instant", "Canonical — instant", "o"),
        ("canonical_10kw_softramp", "Canonical — soft-ramp", "s"),
        ("v10_tight_50kw_instant", "V10 Tight — instant", "D"),
        ("v10_tight_50kw_softramp", "V10 Tight — soft-ramp", "p"),
    ]

    fig, axes = plt.subplots(2, 2, figsize=(14, 12))

    # Panel A: P/P_rated vs k_mppt, coloured by FoS
    ax = axes[0, 0]
    sc = None
    for name, label, marker in scenarios:
        df = load(name)
        if df is None:
            continue
        add_derived(df)
        P_rated = 10.0 if "canonical" in name else 50.0
        norm_p = df["P_kw"] / P_rated
        # Downsample for clarity
        step = max(1, len(df) // 500)
        sc = ax.scatter(df["k_mppt"].iloc[::step], norm_p.iloc[::step],
                         c=df["min_fos"].iloc[::step], cmap="RdYlGn", s=12,
                         vmin=0.5, vmax=5.0, marker=marker, alpha=0.7, label=label,
                         edgecolors="none")
    if sc is not None:
        cbar = plt.colorbar(sc, ax=ax, shrink=0.8)
        cbar.set_label("min FoS", fontsize=9)
    ax.axhline(y=1.0, color="grey", linestyle="--", alpha=0.5, label="P = P_rated")
    ax.axhspan(0.9, 1.1, alpha=0.05, color="green")
    ax.text(100, 1.02, "Rated ±10%", fontsize=8, color="green", alpha=0.7)
    ax.set_xlabel("k_mppt (N·m·s²/rad²)")
    ax.set_ylabel("P_gen / P_rated")
    ax.legend(fontsize=7, loc="upper right")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "A")

    # Panel B: FoS vs k_mppt
    ax = axes[0, 1]
    for name, label, marker in scenarios:
        df = load(name)
        if df is None:
            continue
        add_derived(df)
        step = max(1, len(df) // 500)
        ax.scatter(df["k_mppt"].iloc[::step], df["min_fos"].iloc[::step],
                    c=df["omega_hub_rpm"].iloc[::step], cmap="viridis", s=10,
                    vmin=0, vmax=180, marker=marker, alpha=0.6, label=label,
                    edgecolors="none")
    ax.axhline(y=1.5, color=C_FOS_HARD, linestyle=":", alpha=0.7, label="FoS floor")
    ax.axhline(y=2.5, color=C_FOS_SOFT, linestyle="--", alpha=0.7, label="FoS soft")
    ax.fill_between([0, 200], 0, 1.5, alpha=0.04, color="red")
    ax.fill_between([0, 200], 1.5, 2.5, alpha=0.04, color=C_FOS_SOFT)
    ax.set_xlabel("k_mppt (N·m·s²/rad²)")
    ax.set_ylabel("min FoS")
    ax.legend(fontsize=7, loc="upper right")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "B")

    # Panel C: ω vs k_mppt
    ax = axes[1, 0]
    for name, label, marker in scenarios:
        df = load(name)
        if df is None:
            continue
        add_derived(df)
        step = max(1, len(df) // 500)
        ax.scatter(df["k_mppt"].iloc[::step], df["omega_hub_rpm"].iloc[::step],
                    c=df["P_kw"].iloc[::step], cmap="plasma", s=10,
                    vmin=0, vmax=180, marker=marker, alpha=0.6, label=label,
                    edgecolors="none")
    ax.set_xlabel("k_mppt (N·m·s²/rad²)")
    ax.set_ylabel("ω_hub (rpm)")
    ax.legend(fontsize=7, loc="upper right")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "C")

    # Panel D: Phase portrait — ω vs P, all scenarios
    ax = axes[1, 1]
    for name, label, marker in scenarios:
        df = load(name)
        if df is None:
            continue
        add_derived(df)
        step = max(1, len(df) // 300)
        ax.scatter(df["omega_hub_rpm"].iloc[::step], df["P_kw"].iloc[::step],
                    c=df["t"].iloc[::step], cmap="plasma" if "canonical" in name else "viridis",
                    s=8, marker=marker, alpha=0.5, label=label, edgecolors="none")
    ax.set_xlabel("ω_hub (rpm)")
    ax.set_ylabel("P_gen (kW)")
    ax.legend(fontsize=7, loc="upper left")
    ax.grid(True, alpha=0.3)
    panel_label(ax, "D")

    fig.suptitle("Structural Operating Envelope — All Scenarios", fontsize=14, fontweight="bold")
    save_close(fig, "fig4_structural_envelope.png")


# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 5 — Frequency Domain
# ═══════════════════════════════════════════════════════════════════════════
def fig5_frequency_domain():
    pairs = [
        ("canonical_10kw_softramp", "Canonical 10 kW"),
        ("v10_tight_50kw_softramp", "V10 Tight 50 kW"),
    ]

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    for idx, (name, title) in enumerate(pairs):
        df = load(name)
        if df is None:
            continue
        # T_max PSD
        ax = axes[0, idx]
        _plot_psd(ax, df["T_max_N"].dropna().values, 0.02, C_RAMP,
                   f"{title} — T_max PSD")
        ax.set_xlabel("Frequency (Hz)")
        ax.set_ylabel("PSD (N²/Hz)")
        ax.grid(True, alpha=0.3)
        panel_label(ax, ["A", "B"][idx])

        # Twist PSD
        ax = axes[1, idx]
        _plot_psd(ax, df["twist_deg"].dropna().values, 0.02, C_TWIST,
                   f"{title} — Twist ΣΔα PSD")
        ax.set_xlabel("Frequency (Hz)")
        ax.set_ylabel("PSD (°²/Hz)")
        ax.grid(True, alpha=0.3)
        panel_label(ax, ["C", "D"][idx])

    fig.suptitle("Torsional Frequency Content — Soft-Ramp Scenarios", fontsize=14, fontweight="bold")
    save_close(fig, "fig5_frequency_domain.png")


def _plot_psd(ax, data, fs, color, title):
    """Welch PSD on an axis, with sensible defaults."""
    if len(data) < 256:
        ax.text(0.5, 0.5, "Insufficient data", ha="center", transform=ax.transAxes)
        return
    nperseg = min(1024, len(data) // 4)
    f, Pxx = signal.welch(data, fs=1.0/fs, nperseg=nperseg, detrend="linear")
    # Only show frequencies where there's signal (above 0.01 Hz up to Nyquist/2)
    mask = (f > 0.01) & (f < 25)
    ax.loglog(f[mask], Pxx[mask], color=color, linewidth=1.2)
    ax.set_title(title, fontsize=10)
    # Mark dominant peaks
    if len(Pxx[mask]) > 10:
        peak_idx = np.argmax(Pxx[mask][10:]) + 10  # skip DC
        if peak_idx < len(f[mask]):
            ax.annotate(f"{f[mask][peak_idx]:.2f} Hz",
                        (f[mask][peak_idx], Pxx[mask][peak_idx]),
                        fontsize=8, color=color)


# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 6 — Controller Diagnostic: State Machine Trace
# ═══════════════════════════════════════════════════════════════════════════
def fig6_controller_diagnostic():
    scenarios = [
        ("canonical_10kw_softramp", "Canonical 10 kW — Soft-ramp"),
        ("v10_tight_50kw_softramp", "V10 Tight 50 kW — Soft-ramp"),
        ("wind_ramp_softramp", "Wind Ramp — Soft-ramp"),
    ]

    fig, axes = plt.subplots(3, 1, figsize=(14, 12), sharex=False)

    for idx, (name, title) in enumerate(scenarios):
        df = load(name)
        if df is None or "state" not in df.columns:
            continue
        add_derived(df)
        ax = axes[idx]

        # State bands
        states = df["state"].values
        t = df["t"].values
        i = 0
        while i < len(states):
            s = states[i]
            j = i
            while j < len(states) and states[j] == s:
                j += 1
            t0 = t[i]
            t1 = t[min(j, len(t) - 1)]
            color = {"IDLE": C_IDLE, "RAMPING": C_RAMPING, "HOLDING": C_HOLDING, "fixed": "none"}.get(s)
            if color and color != "none":
                ax.axvspan(t0, t1, alpha=0.2, color=color, linewidth=0)
            # Label first occurrence of each state
            if i == 0 or states[i - 1] != s:
                y_pos = ax.get_ylim()[1] * 0.85 if ax.get_ylim()[1] > 0 else 100
                ax.text((t0 + t1) / 2, y_pos, s, fontsize=9,
                        ha="center", va="top", fontweight="bold", color=color if color != C_IDLE else "grey")

            i = j

        # k_mppt trace
        ax.plot(t, df["k_mppt"], color=C_RAMP, linewidth=1.8, label="k_mppt")
        ax.set_ylabel("k_mppt (N·m·s²/rad²)", color=C_RAMP)
        ax.tick_params(axis="y", labelcolor=C_RAMP)

        # P_gen trace on twin axis
        ax2 = ax.twinx()
        P_rated = 10.0 if "canonical" in name else 50.0
        ax2.plot(t, df["P_kw"], color=C_INSTANT, linewidth=1.2, alpha=0.7, label="P_gen")
        ax2.axhline(y=P_rated, color="grey", linestyle="--", alpha=0.4)
        ax2.set_ylabel("P_gen (kW)", color=C_INSTANT)
        ax2.tick_params(axis="y", labelcolor=C_INSTANT)

        ax.set_xlabel("Time (s)")
        ax.set_title(title, fontsize=11, fontweight="bold")
        ax.grid(True, alpha=0.3)
        panel_label(ax, ["A", "B", "C"][idx])

    # Custom legend
    legend_elements = [
        Patch(facecolor=C_IDLE, alpha=0.3, label="IDLE"),
        Patch(facecolor=C_RAMPING, alpha=0.3, label="RAMPING"),
        Patch(facecolor=C_HOLDING, alpha=0.3, label="HOLDING"),
    ]
    axes[0].legend(handles=legend_elements, loc="upper right", fontsize=8, ncol=3)

    fig.suptitle("Controller State Machine — Diagnostic Trace", fontsize=14, fontweight="bold")
    save_close(fig, "fig6_controller_diagnostic.png")


# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 7 — Cross-System Comparison Bar Chart
# ═══════════════════════════════════════════════════════════════════════════
def fig7_cross_system_bars():
    scenarios = [
        ("canonical_10kw_instant", "Canonical\ninstant"),
        ("canonical_10kw_softramp", "Canonical\nsoft-ramp"),
        ("v10_tight_50kw_instant", "V10 Tight\ninstant"),
        ("v10_tight_50kw_softramp", "V10 Tight\nsoft-ramp"),
        ("wind_ramp_instant", "Wind ramp\ninstant"),
        ("wind_ramp_softramp", "Wind ramp\nsoft-ramp"),
    ]

    # Collect metrics
    labels = []
    p_ratio, fos_ratio, omega_ratio, t_rated_vals = [], [], [], []

    for name, label in scenarios:
        df = load(name)
        if df is None:
            continue
        add_derived(df)
        labels.append(label)
        P_rated = 10.0 if "canonical" in name else (50.0 if "v10" in name else 10.0)
        p_ratio.append(df["P_kw"].iloc[-1] / P_rated)
        fos_ratio.append(df["min_fos"].min() / 1.5)
        # ω_rated: rough estimate = cbrt(P_rated / k_mppt_end)
        omega_rated_est = np.cbrt(P_rated * 1000 / max(df["k_mppt"].iloc[-1], 1.0)) * 60 / (2 * np.pi)
        omega_ratio.append(df["omega_hub_rpm"].iloc[-1] / max(omega_rated_est, 1.0))
        # t_to_rated
        t80 = np.nan
        for i in range(len(df)):
            if df["P_kw"].iloc[i] >= 0.8 * P_rated:
                t80 = df["t"].iloc[i]
                break
        t_rated_vals.append(t80 if not np.isnan(t80) else 0)

    x = np.arange(len(labels))
    width = 0.2

    fig, axes = plt.subplots(2, 2, figsize=(14, 9))

    def _colour_bars(ax, values, threshold=1.0, higher_is_safe=True):
        bars = []
        for i, v in enumerate(values):
            if higher_is_safe:
                c = C_HOLDING if v >= threshold else (C_FOS_SOFT if v >= 0.7 * threshold else C_FOS_HARD)
            else:
                c = C_HOLDING if v <= threshold else (C_FOS_SOFT if v <= 1.5 * threshold else C_FOS_HARD)
            bars.append(c)
        return bars

    # Panel A: P/P_rated (target = 1.0, higher is worse above 1.5)
    ax = axes[0, 0]
    colors = []
    for v in p_ratio:
        if 0.8 <= v <= 1.2:
            colors.append(C_HOLDING)
        elif 0.5 <= v <= 2.0:
            colors.append(C_FOS_SOFT)
        else:
            colors.append(C_FOS_HARD)
    ax.bar(x, p_ratio, width, color=colors, edgecolor="white")
    ax.axhline(y=1.0, color="grey", linestyle="--", alpha=0.5)
    ax.axhspan(0.9, 1.1, alpha=0.05, color="green")
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=9)
    ax.set_ylabel("P_final / P_rated")
    ax.set_title("Power Ratio (target ≈ 1.0)", fontsize=11)
    ax.grid(True, alpha=0.3, axis="y")
    # Value labels
    for i, v in enumerate(p_ratio):
        ax.text(i, v + 0.05, f"{v:.1f}×", ha="center", fontsize=8, fontweight="bold")
    panel_label(ax, "A")

    # Panel B: FoS / 1.5 (target ≥ 1.0)
    ax = axes[0, 1]
    colors = [C_HOLDING if v >= 1.0 else (C_FOS_SOFT if v >= 0.5 else C_FOS_HARD) for v in fos_ratio]
    ax.bar(x, fos_ratio, width, color=colors, edgecolor="white")
    ax.axhline(y=1.0, color="grey", linestyle="--", alpha=0.5)
    ax.fill_between([-0.5, len(labels) - 0.5], 0, 1.0, alpha=0.04, color="red")
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=9)
    ax.set_ylabel("min FoS / 1.5")
    ax.set_title("Structural Safety (target ≥ 1.0)", fontsize=11)
    ax.grid(True, alpha=0.3, axis="y")
    for i, v in enumerate(fos_ratio):
        ax.text(i, v + 0.1, f"{v:.1f}×", ha="center", fontsize=8,
                fontweight="bold", color="red" if v < 1.0 else "black")
    panel_label(ax, "B")

    # Panel C: Time to 80% rated
    ax = axes[1, 0]
    colors = [C_HOLDING if v < 20 else (C_FOS_SOFT if v < 60 else C_FOS_HARD) for v in t_rated_vals]
    ax.bar(x, t_rated_vals, width, color=colors, edgecolor="white")
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=9)
    ax.set_ylabel("Time (s)")
    ax.set_title("Time to 80% Rated Power", fontsize=11)
    ax.grid(True, alpha=0.3, axis="y")
    for i, v in enumerate(t_rated_vals):
        ax.text(i, v + 1, f"{v:.1f}s", ha="center", fontsize=8)
    panel_label(ax, "C")

    # Panel D: Margin summary — min collapse margin
    ax = axes[1, 1]
    margin_vals = []
    for name, _ in scenarios:
        df = load(name)
        if df is not None and "collapse_margin_deg" in df.columns:
            m = df["collapse_margin_deg"].replace([np.inf, -np.inf], np.nan)
            margin_vals.append(m.min() if not m.isna().all() else np.nan)
        else:
            margin_vals.append(np.nan)
    colors = [C_HOLDING if not np.isnan(v) and v >= 5 else (C_FOS_SOFT if not np.isnan(v) and v >= 2 else C_FOS_HARD) for v in margin_vals]
    ax.bar(x, margin_vals, width, color=colors, edgecolor="white")
    ax.axhline(y=5, color=C_FOS_HARD, linestyle="--", alpha=0.5, label="Freeze threshold (5°)")
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=9)
    ax.set_ylabel("Collapse margin (°)")
    ax.set_title("Min Tulloch Collapse Margin", fontsize=11)
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3, axis="y")
    for i, v in enumerate(margin_vals):
        if not np.isnan(v) and not np.isinf(v):
            ax.text(i, v + 1, f"{v:.0f}°", ha="center", fontsize=8,
                    fontweight="bold", color="red" if v < 5 else "black")
        else:
            ax.text(i, 2, "N/A", ha="center", fontsize=7, color="grey", fontstyle="italic")
    panel_label(ax, "D")

    fig.suptitle("Cross-System Comparison — Key Performance Metrics",
                 fontsize=14, fontweight="bold")
    save_close(fig, "fig7_cross_system_bars.png")


# ═══════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print("Generating AWEC 2026 ramp-trace figures…\n")
    fig1_canonical_dashboard()
    fig2_v10_dashboard()
    fig3_wind_ramp_triptych()
    fig4_structural_envelope()
    fig5_frequency_domain()
    fig6_controller_diagnostic()
    fig7_cross_system_bars()
    print(f"\nDone. Figures in: {FIG_DIR}")
