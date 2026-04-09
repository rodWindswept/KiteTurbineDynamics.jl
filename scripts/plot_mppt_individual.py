"""
MPPT Twist Sweep v2 — Individual Chart Generator
==================================================
Produces one PNG per analytical panel (9 steady-state + 3 ramp = 12 charts).
Used by the comprehensive report for per-chart captions and implications.

Usage:
  python3 scripts/plot_mppt_individual.py

Outputs (in results/mppt_twist_sweep/individual/):
  01_power_vs_wind.png
  02_twist_vs_wind.png
  03_tether_load_vs_wind.png
  04_delta_omega_vs_wind.png
  05_torque_tension_ratio.png
  06_twist_ripple.png
  07_twist_timeseries_v11.png
  08_power_timeseries_v11.png
  09_omega_timeseries_v11.png
  10_ramp_omega.png
  11_ramp_power.png
  12_ramp_twist.png
"""

import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

OUT     = Path(__file__).parent / "results" / "mppt_twist_sweep"
IND_OUT = OUT / "individual"
IND_OUT.mkdir(parents=True, exist_ok=True)

SUM_V2  = OUT / "twist_sweep_v2_summary.csv"
TS_V2   = OUT / "twist_sweep_v2.csv"
RAMP_V2 = OUT / "twist_ramp_v2.csv"

for f in [SUM_V2, TS_V2]:
    if not f.exists():
        sys.exit(f"Missing: {f}\nRun mppt_twist_sweep_v2.jl first.")

smry = pd.read_csv(SUM_V2)
ts   = pd.read_csv(TS_V2)
ramp = pd.read_csv(RAMP_V2) if RAMP_V2.exists() else None

# ── Palette ─────────────────────────────────────────────────────────────────
BG    = "#0e1117"
PANEL = "#161b22"
SPINE = "#333333"

K_MULTS = sorted(smry["k_mult"].unique())
V_WINDS = sorted(smry["v_wind"].unique())
K_NOM   = 1.0

COLORS = {
    0.5:  "#5b8dd9",
    0.75: "#66c296",
    1.0:  "#e8a020",
    1.25: "#e05c2e",
    1.5:  "#c97ad8",
    2.5:  "#e06060",
    4.0:  "#888888",
}

def make_fig(w=8, h=5):
    fig, ax = plt.subplots(figsize=(w, h))
    fig.patch.set_facecolor(BG)
    ax.set_facecolor(PANEL)
    ax.tick_params(colors="white", labelsize=10)
    for sp in ax.spines.values():
        sp.set_color(SPINE)
    return fig, ax

def styled(ax, title="", xlabel="", ylabel=""):
    if title:  ax.set_title(title,  color="white",  fontsize=12, pad=6)
    if xlabel: ax.set_xlabel(xlabel, color="#aaaaaa", fontsize=10)
    if ylabel: ax.set_ylabel(ylabel, color="#aaaaaa", fontsize=10)

def legend(ax):
    ax.legend(fontsize=8, framealpha=0.35, labelcolor="white",
              facecolor=PANEL, edgecolor=SPINE)

def save(fig, name):
    path = IND_OUT / name
    fig.tight_layout()
    fig.savefig(path, dpi=150, bbox_inches="tight", facecolor=BG)
    plt.close(fig)
    print(f"  {path.name}")

# ── 01  Mean power vs wind speed ─────────────────────────────────────────────
fig, ax = make_fig()
styled(ax, "Mean Electrical Power vs Wind Speed",
       "Wind speed (m/s)", "Mean power (kW)")
for km in K_MULTS:
    sub = smry[smry["k_mult"] == km].sort_values("v_wind")
    c   = COLORS.get(km, "#888888")
    lw  = 2.2 if abs(km - K_NOM) < 0.01 else 1.2
    ax.plot(sub["v_wind"], sub["P_kw_mean"],
            color=c, lw=lw, marker="o", ms=5, label=f"k×{km:.2g}")
ax.axhline(10.0, color="#555", lw=1.0, ls="--", label="Rated 10 kW")
ax.axhline(0.0,  color="#444", lw=0.6, ls=":")
legend(ax)
save(fig, "01_power_vs_wind.png")

# ── 02  Total twist vs wind speed ────────────────────────────────────────────
fig, ax = make_fig()
styled(ax, "Total TRPT Shaft Twist vs Wind Speed",
       "Wind speed (m/s)", "Total twist (°)")
for km in K_MULTS:
    sub = smry[smry["k_mult"] == km].sort_values("v_wind")
    c   = COLORS.get(km, "#888888")
    lw  = 2.2 if abs(km - K_NOM) < 0.01 else 1.2
    ax.plot(sub["v_wind"], sub["twist_mean"],
            color=c, lw=lw, marker="o", ms=5, label=f"k×{km:.2g}")
ax.axhline(360.0, color="#e05c2e", lw=0.8, ls="--", alpha=0.6, label="360° (1 full turn)")
legend(ax)
save(fig, "02_twist_vs_wind.png")

# ── 03  Peak tether load vs wind ─────────────────────────────────────────────
fig, ax = make_fig()
styled(ax, "Peak Tether Tension vs Wind Speed",
       "Wind speed (m/s)", "T_max (N)")
for km in K_MULTS:
    sub = smry[smry["k_mult"] == km].sort_values("v_wind")
    c   = COLORS.get(km, "#888888")
    lw  = 2.2 if abs(km - K_NOM) < 0.01 else 1.2
    ax.plot(sub["v_wind"], sub["T_max_mean"],
            color=c, lw=lw, marker="o", ms=5, label=f"k×{km:.2g}")
legend(ax)
save(fig, "03_tether_load_vs_wind.png")

# ── 04  Speed differential Δω ────────────────────────────────────────────────
fig, ax = make_fig()
styled(ax, "Hub–Ground Angular Speed Differential (Δω)",
       "Wind speed (m/s)", "Δω = ω_hub − ω_gnd (rad/s)")
for km in K_MULTS:
    sub = smry[smry["k_mult"] == km].sort_values("v_wind")
    c   = COLORS.get(km, "#888888")
    lw  = 2.2 if abs(km - K_NOM) < 0.01 else 1.2
    ax.plot(sub["v_wind"], sub["delta_omega_mean"],
            color=c, lw=lw, marker="o", ms=5, label=f"k×{km:.2g}")
ax.axhline(0.0, color="#555", lw=0.8, ls="--")
legend(ax)
save(fig, "04_delta_omega_vs_wind.png")

# ── 05  Torque / tether tension ratio ────────────────────────────────────────
fig, ax = make_fig()
styled(ax, "Torque-to-Tension Ratio (τ/T)",
       "Wind speed (m/s)", "τ / T_mean (dimensionless)")
for km in K_MULTS:
    sub = smry[smry["k_mult"] == km].sort_values("v_wind")
    c   = COLORS.get(km, "#888888")
    lw  = 2.2 if abs(km - K_NOM) < 0.01 else 1.2
    ax.plot(sub["v_wind"], sub["tau_over_T"],
            color=c, lw=lw, marker="o", ms=5, label=f"k×{km:.2g}")
legend(ax)
save(fig, "05_torque_tension_ratio.png")

# ── 06  Twist ripple (std) ───────────────────────────────────────────────────
fig, ax = make_fig()
styled(ax, "Shaft Twist Standard Deviation (Ripple)",
       "Wind speed (m/s)", "Twist σ (°)")
for km in K_MULTS:
    sub = smry[smry["k_mult"] == km].sort_values("v_wind")
    c   = COLORS.get(km, "#888888")
    lw  = 2.2 if abs(km - K_NOM) < 0.01 else 1.2
    ax.plot(sub["v_wind"], sub["twist_std"],
            color=c, lw=lw, marker="o", ms=5, label=f"k×{km:.2g}")
legend(ax)
save(fig, "06_twist_ripple.png")

# ── 07–09  Time series at v=11 ───────────────────────────────────────────────
V_SHOW = 11.0 if 11.0 in V_WINDS else V_WINDS[len(V_WINDS)//2]

for col, ylabel, title, fname in [
    ("twist_deg",  "Total twist (°)",    f"Shaft Twist Time Series — v = {V_SHOW:.0f} m/s",
     "07_twist_timeseries_v11.png"),
    ("P_kw",       "Power (kW)",          f"Electrical Power Time Series — v = {V_SHOW:.0f} m/s",
     "08_power_timeseries_v11.png"),
    ("omega_gnd",  "ω_gnd (rad/s)",       f"Ground Ring Speed Time Series — v = {V_SHOW:.0f} m/s",
     "09_omega_timeseries_v11.png"),
]:
    fig, ax = make_fig()
    styled(ax, title, "Time (s)", ylabel)
    for km in K_MULTS:
        sub = ts[(ts["k_mult"] == km) & (ts["v_wind"] == V_SHOW)]
        if sub.empty:
            continue
        c     = COLORS.get(km, "#888888")
        lw    = 1.8 if abs(km - K_NOM) < 0.01 else 0.9
        alpha = 0.95 if abs(km - K_NOM) < 0.01 else 0.65
        ax.plot(sub["t"], sub[col], color=c, lw=lw, alpha=alpha, label=f"k×{km:.2g}")
    if col == "P_kw":
        ax.axhline(10.0, color="#555", lw=0.8, ls="--", label="Rated 10 kW")
    legend(ax)
    save(fig, fname)

# ── 10–12  Wind ramp ─────────────────────────────────────────────────────────
if ramp is not None and not ramp.empty:
    for ycol, ylabel2, title2, fname2 in [
        (["omega_hub","omega_gnd"], "ω (rad/s)",   "Wind Ramp — Hub & Ground Angular Speed",
         "10_ramp_omega.png"),
        (["P_kw"],                  "Power (kW)",  "Wind Ramp — Electrical Power",
         "11_ramp_power.png"),
        (["twist_deg"],             "Twist (°)",   "Wind Ramp — TRPT Shaft Twist",
         "12_ramp_twist.png"),
    ]:
        fig, ax = make_fig()
        styled(ax, title2, "Simulation time (s)", ylabel2)
        colors2 = ["#e8a020", "#66c296", "#5b8dd9"]
        for ci, col2 in enumerate(ycol):
            ax.plot(ramp["t"], ramp[col2], color=colors2[ci], lw=1.5, label=col2)
        if "P_kw" in ycol:
            ax.axhline(10.0, color="#555", lw=0.8, ls="--", label="Rated 10 kW")
        ax.axvline(5.0, color="#555", lw=0.6, ls=":", alpha=0.7, label="Spin-up end")

        # Annotate wind speed range
        v_lo = ramp["v_wind"].iloc[0]
        v_hi = ramp["v_wind"].iloc[-1]
        ax.text(0.97, 0.96, f"v_wind: {v_lo:.0f} → {v_hi:.0f} m/s",
                transform=ax.transAxes, color="#aaa", fontsize=9,
                ha="right", va="top")
        legend(ax)
        save(fig, fname2)
else:
    print("  Ramp CSV not found — skipping charts 10–12.")

print(f"\nAll individual charts saved to: {IND_OUT}")
