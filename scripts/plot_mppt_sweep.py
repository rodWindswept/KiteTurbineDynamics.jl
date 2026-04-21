"""
MPPT Twist Sweep v2 — Analysis Plots
=====================================
Reads the CSV outputs from mppt_twist_sweep_v2.jl (and optionally
mppt_ramp_only.jl / the inline ramp) and produces a multi-panel figure
plus a markdown report.

Outputs (relative to this script's directory):
  results/mppt_twist_sweep/twist_sweep_v2_analysis.png
  results/mppt_twist_sweep/twist_sweep_v2_report.md

Usage:
  python3 scripts/plot_mppt_sweep.py
"""

import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from pathlib import Path

OUT = Path(__file__).parent / "results" / "mppt_twist_sweep"
SUM_V2  = OUT / "twist_sweep_v2_summary.csv"
TS_V2   = OUT / "twist_sweep_v2.csv"
RAMP_V2 = OUT / "twist_ramp_v2.csv"

for f in [SUM_V2, TS_V2]:
    if not f.exists():
        sys.exit(f"Missing: {f}\nRun mppt_twist_sweep_v2.jl first.")

smry = pd.read_csv(SUM_V2)
ts   = pd.read_csv(TS_V2)
ramp = pd.read_csv(RAMP_V2) if RAMP_V2.exists() else None

# ── Palette ────────────────────────────────────────────────────────────────────
BG    = "#0e1117"
PANEL = "#161b22"
SPINE = "#333333"

K_MULTS  = sorted(smry["k_mult"].unique())
V_WINDS  = sorted(smry["v_wind"].unique())
K_NOM    = 1.0    # nominal k_mult for "best" reference

COLORS = {
    0.5:  "#5b8dd9",
    0.75: "#66c296",
    1.0:  "#e8a020",
    1.25: "#e05c2e",
    1.5:  "#c97ad8",
}

def styled(ax, title="", xlabel="", ylabel=""):
    ax.set_facecolor(PANEL)
    ax.tick_params(colors="white", labelsize=8)
    for sp in ax.spines.values():
        sp.set_color(SPINE)
    if title:  ax.set_title(title,  color="white",  fontsize=9,  pad=4)
    if xlabel: ax.set_xlabel(xlabel, color="#aaaaaa", fontsize=8)
    if ylabel: ax.set_ylabel(ylabel, color="#aaaaaa", fontsize=8)
    return ax

# ── Figure layout ──────────────────────────────────────────────────────────────
fig = plt.figure(figsize=(18, 16))
fig.patch.set_facecolor(BG)
gs  = gridspec.GridSpec(4, 3, figure=fig,
                        hspace=0.46, wspace=0.36,
                        left=0.07, right=0.97, top=0.93, bottom=0.05)

# ── Row 0: Power vs wind speed | Twist vs wind speed | T_max vs wind speed ────
ax_P   = fig.add_subplot(gs[0, 0])
ax_tw  = fig.add_subplot(gs[0, 1])
ax_Tm  = fig.add_subplot(gs[0, 2])

styled(ax_P,  title="Mean power vs wind speed",   xlabel="v_wind (m/s)", ylabel="P (kW)")
styled(ax_tw, title="Total twist vs wind speed",  xlabel="v_wind (m/s)", ylabel="Twist (°)")
styled(ax_Tm, title="Peak tether load vs wind",   xlabel="v_wind (m/s)", ylabel="T_max (N)")

for km in K_MULTS:
    sub = smry[smry["k_mult"] == km].sort_values("v_wind")
    c   = COLORS.get(km, "#888888")
    lw  = 2.0 if abs(km - K_NOM) < 0.01 else 1.2
    lbl = f"k×{km:.2g}"
    ax_P.plot( sub["v_wind"], sub["P_kw_mean"],   color=c, lw=lw, marker="o", ms=4, label=lbl)
    ax_tw.plot(sub["v_wind"], sub["twist_mean"],  color=c, lw=lw, marker="o", ms=4, label=lbl)
    ax_Tm.plot(sub["v_wind"], sub["T_max_mean"],  color=c, lw=lw, marker="o", ms=4, label=lbl)

for ax in [ax_P, ax_tw, ax_Tm]:
    ax.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor=PANEL)
ax_P.axhline(10.0, color="#555", lw=0.8, ls="--", label="rated 10 kW")

# ── Row 1: delta_omega | tau/T ratio | twist std ───────────────────────────────
ax_dw  = fig.add_subplot(gs[1, 0])
ax_tt  = fig.add_subplot(gs[1, 1])
ax_tws = fig.add_subplot(gs[1, 2])

styled(ax_dw,  title="Speed differential (Δω = ω_hub − ω_gnd)",
       xlabel="v_wind (m/s)", ylabel="Δω (rad/s)")
styled(ax_tt,  title="Torque / T_tether ratio",
       xlabel="v_wind (m/s)", ylabel="τ/T_mean")
styled(ax_tws, title="Twist std (ripple)",
       xlabel="v_wind (m/s)", ylabel="Twist σ (°)")

for km in K_MULTS:
    sub = smry[smry["k_mult"] == km].sort_values("v_wind")
    c   = COLORS.get(km, "#888888")
    lw  = 2.0 if abs(km - K_NOM) < 0.01 else 1.2
    lbl = f"k×{km:.2g}"
    ax_dw.plot( sub["v_wind"], sub["delta_omega_mean"], color=c, lw=lw, marker="o", ms=4, label=lbl)
    ax_tt.plot( sub["v_wind"], sub["tau_over_T"],       color=c, lw=lw, marker="o", ms=4, label=lbl)
    ax_tws.plot(sub["v_wind"], sub["twist_std"],        color=c, lw=lw, marker="o", ms=4, label=lbl)

for ax in [ax_dw, ax_tt, ax_tws]:
    ax.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor=PANEL)
ax_dw.axhline(0.0, color="#555", lw=0.8, ls="--")

# ── Row 2: Twist time series at v=11 | Power time series at v=11 | omega_gnd ──
V_SHOW = 11.0 if 11.0 in V_WINDS else V_WINDS[len(V_WINDS)//2]
ax_tst = fig.add_subplot(gs[2, 0])
ax_pts = fig.add_subplot(gs[2, 1])
ax_wts = fig.add_subplot(gs[2, 2])

styled(ax_tst, title=f"Twist time series — v = {V_SHOW:.0f} m/s",
       xlabel="t (s)", ylabel="Twist (°)")
styled(ax_pts, title=f"Power time series — v = {V_SHOW:.0f} m/s",
       xlabel="t (s)", ylabel="P (kW)")
styled(ax_wts, title=f"ω_gnd time series — v = {V_SHOW:.0f} m/s",
       xlabel="t (s)", ylabel="ω_gnd (rad/s)")

for km in K_MULTS:
    sub = ts[(ts["k_mult"] == km) & (ts["v_wind"] == V_SHOW)]
    if sub.empty:
        continue
    c   = COLORS.get(km, "#888888")
    lw  = 1.5 if abs(km - K_NOM) < 0.01 else 0.8
    alpha = 0.9 if abs(km - K_NOM) < 0.01 else 0.6
    lbl = f"k×{km:.2g}"
    ax_tst.plot(sub["t"], sub["twist_deg"],  color=c, lw=lw, alpha=alpha, label=lbl)
    ax_pts.plot(sub["t"], sub["P_kw"],       color=c, lw=lw, alpha=alpha, label=lbl)
    ax_wts.plot(sub["t"], sub["omega_gnd"],  color=c, lw=lw, alpha=alpha, label=lbl)

for ax in [ax_tst, ax_pts, ax_wts]:
    ax.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor=PANEL)
ax_pts.axhline(10.0, color="#555", lw=0.6, ls="--")

# ── Row 3: Wind ramp (if available) or summary heatmap ───────────────────────
ax_rp  = fig.add_subplot(gs[3, 0])
ax_rP  = fig.add_subplot(gs[3, 1])
ax_rTw = fig.add_subplot(gs[3, 2])

if ramp is not None and not ramp.empty:
    styled(ax_rp,  title="Wind ramp — ω_hub & ω_gnd",
           xlabel="t (s)", ylabel="ω (rad/s)")
    styled(ax_rP,  title="Wind ramp — power",
           xlabel="t (s)", ylabel="P (kW)")
    styled(ax_rTw, title="Wind ramp — twist",
           xlabel="t (s)", ylabel="Twist (°)")

    ax_rp.plot(ramp["t"], ramp["omega_hub"], color="#e8a020", lw=1.2, label="ω_hub")
    ax_rp.plot(ramp["t"], ramp["omega_gnd"], color="#66c296", lw=1.2, label="ω_gnd")
    ax_rp.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor=PANEL)

    ax_rP.plot(ramp["t"], ramp["P_kw"], color="#e8a020", lw=1.2)
    ax_rP.axhline(10.0, color="#555", lw=0.6, ls="--")

    ax_rTw.plot(ramp["t"], ramp["twist_deg"], color="#5b8dd9", lw=1.2)

    # Mark ramp start/end wind speed
    for ax in [ax_rp, ax_rP, ax_rTw]:
        ax.axvline(5.0, color="#555", lw=0.6, ls=":", alpha=0.7)   # after spinup

    # Add secondary x axis annotation for wind speed
    v_lo = ramp["v_wind"].iloc[0]
    v_hi = ramp["v_wind"].iloc[-1]
    ax_rP.text(0.02, 0.94, f"v: {v_lo:.0f}→{v_hi:.0f} m/s",
               transform=ax_rP.transAxes, color="#aaa", fontsize=8, va="top")
else:
    # Show summary heat-map of P_kw_mean as fallback
    styled(ax_rp,  title="Wind ramp not available yet")
    styled(ax_rP,  title="(run mppt_ramp_only.jl)")
    styled(ax_rTw, title="")
    ax_rp.text(0.5, 0.5, "twist_ramp_v2.csv\nnot found",
               ha="center", va="center", color="#aaa", fontsize=10,
               transform=ax_rp.transAxes)
    for ax in [ax_rP, ax_rTw]:
        ax.set_visible(False)

# ── Title ──────────────────────────────────────────────────────────────────────
fig.suptitle(
    "MPPT Twist Sweep v2 — Corrected CT-thrust physics  |  10 kW TRPT prototype",
    color="white", fontsize=12, y=0.97)

out_png = OUT / "twist_sweep_v2_analysis.png"
fig.savefig(out_png, dpi=150, bbox_inches="tight", facecolor=BG)
plt.close()
print(f"Figure saved: {out_png}")

# ── Markdown report ────────────────────────────────────────────────────────────
lines = [
    "# MPPT Twist Sweep v2 — Summary Report\n\n",
    "Corrected CT-thrust physics | Back line active | Kite sized for 4 m/s launch\n\n",
]

# Best k_mppt per wind speed (highest P_kw_mean)
lines.append("## Optimal k_mppt per wind speed\n\n")
lines.append("| v_wind (m/s) | Best k_mult | P_kw | Twist (°) | T_max (N) | Δω (rad/s) |\n")
lines.append("|---|---|---|---|---|---|\n")

for v in V_WINDS:
    sub = smry[smry["v_wind"] == v].sort_values("P_kw_mean", ascending=False)
    if sub.empty:
        continue
    best = sub.iloc[0]
    lines.append(
        f"| {v:.0f} | {best['k_mult']:.2g}× | {best['P_kw_mean']:.2f} | "
        f"{best['twist_mean']:.1f} | {best['T_max_mean']:.0f} | "
        f"{best['delta_omega_mean']:.4f} |\n"
    )

lines.append("\n## Power summary by k_mult\n\n")
lines.append("| k_mult | v=8 P(kW) | v=10 P(kW) | v=11 P(kW) | v=13 P(kW) |\n")
lines.append("|---|---|---|---|---|\n")

V_COLS = [v for v in [8.0, 10.0, 11.0, 13.0] if v in V_WINDS]
for km in K_MULTS:
    sub = smry[smry["k_mult"] == km].set_index("v_wind")
    row_vals = []
    for v in V_COLS:
        if v in sub.index:
            row_vals.append(f"{sub.loc[v, 'P_kw_mean']:.2f}")
        else:
            row_vals.append("—")
    lines.append(f"| {km:.2g}× | {' | '.join(row_vals)} |\n")

if ramp is not None and not ramp.empty:
    p_at_14 = ramp[ramp["v_wind"] >= 13.9]["P_kw"].mean() if len(ramp[ramp["v_wind"] >= 13.9]) else float("nan")
    tw_at_14 = ramp[ramp["v_wind"] >= 13.9]["twist_deg"].mean() if len(ramp[ramp["v_wind"] >= 13.9]) else float("nan")
    lines.append(f"\n## Wind ramp (7→14 m/s over 150 s)\n\n")
    lines.append(f"- P at 14 m/s: {p_at_14:.2f} kW\n")
    lines.append(f"- Twist at 14 m/s: {tw_at_14:.1f}°\n")
    lines.append(f"- Ramp rows: {len(ramp)}\n")

md_path = OUT / "twist_sweep_v2_report.md"
md_path.write_text("".join(lines))
print(f"Report saved:  {md_path}")
print("Done.")
