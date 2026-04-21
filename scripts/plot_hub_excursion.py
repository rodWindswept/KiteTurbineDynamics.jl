"""
Hub Excursion Analysis — plots and summary from hub_excursion_long run.
Run after hub_excursion_long.jl completes (or after each checkpoint).

Produces:
  results/lift_kite/hub_excursion_analysis.png  — 12-panel figure
  results/lift_kite/hub_excursion_report.md     — markdown summary table

Usage:
  python3 scripts/plot_hub_excursion.py
"""

import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from pathlib import Path
import sys

OUT = Path(__file__).parent / "results" / "lift_kite"
TS  = OUT / "long_timeseries.csv"
SM  = OUT / "long_summary.csv"
PSD = OUT / "long_psd.csv"

for f in [TS, SM, PSD]:
    if not f.exists():
        sys.exit(f"Missing: {f}\nRun hub_excursion_long.jl first.")

ts   = pd.read_csv(TS)
smry = pd.read_csv(SM)
psd  = pd.read_csv(PSD)

DEVICES  = ["SingleKite", "Stack×3", "RotaryLifter", "NoLift"]
V_WINDS  = sorted(ts["v_wind"].unique())
COLORS   = {"SingleKite": "#e05c2e", "Stack×3": "#e8a020",
            "RotaryLifter": "#2e7be0", "NoLift": "#888888"}
LABELS   = {"SingleKite": "Single kite", "Stack×3": "Stack ×3",
            "RotaryLifter": "Rotary lifter", "NoLift": "No lift (baseline)"}

V_MAIN = 11.0 if 11.0 in V_WINDS else V_WINDS[1] if len(V_WINDS) > 1 else V_WINDS[0]

# ── Figure layout ─────────────────────────────────────────────────────────────
fig = plt.figure(figsize=(18, 14))
fig.patch.set_facecolor("#0e1117")
gs  = gridspec.GridSpec(4, 3, figure=fig, hspace=0.42, wspace=0.36,
                        left=0.07, right=0.97, top=0.93, bottom=0.06)

AX_STYLE = dict(facecolor="#161b22", labelcolor="white", titlecolor="white")

def styled(ax, title="", xlabel="", ylabel=""):
    ax.set_facecolor("#161b22")
    ax.tick_params(colors="white", labelsize=8)
    for sp in ax.spines.values(): sp.set_color("#333")
    if title:  ax.set_title(title, color="white", fontsize=9, pad=4)
    if xlabel: ax.set_xlabel(xlabel, color="#aaa", fontsize=8)
    if ylabel: ax.set_ylabel(ylabel, color="#aaa", fontsize=8)
    ax.xaxis.label.set_color("#aaa"); ax.yaxis.label.set_color("#aaa")
    return ax

# ── Row 0: hub_z time series at v=11 m/s, all devices ────────────────────────
ax0 = fig.add_subplot(gs[0, :])
styled(ax0, title=f"Hub altitude time series — v = {V_MAIN:.0f} m/s, I = 15 %",
       xlabel="Time (s)", ylabel="Hub altitude z (m)")
sub = ts[ts["v_wind"] == V_MAIN]
for dev in DEVICES:
    d = sub[sub["device"] == dev]
    if len(d):
        ax0.plot(d["t"], d["hub_z"], color=COLORS[dev], lw=0.9,
                 label=LABELS[dev], alpha=0.9)
ax0.legend(loc="upper right", fontsize=8, framealpha=0.3,
           labelcolor="white", facecolor="#161b22")
ax0.axhline(15.0, color="#555", lw=0.6, ls="--", label="nominal 15 m")

# ── Row 1: hub_z std vs wind speed (bar) | Power time series | Power std bar ──
ax_std  = fig.add_subplot(gs[1, 0])
ax_pwr  = fig.add_subplot(gs[1, 1])
ax_pcv  = fig.add_subplot(gs[1, 2])

styled(ax_std, title="Hub altitude std vs wind speed",
       xlabel="Wind speed (m/s)", ylabel="hub_z std (mm)")
styled(ax_pwr, title=f"Power output — v = {V_MAIN:.0f} m/s",
       xlabel="Time (s)", ylabel="Power (kW)")
styled(ax_pcv, title="Power CV vs wind speed",
       xlabel="Wind speed (m/s)", ylabel="Power CV (%)")

x_v = np.arange(len(V_WINDS))
bar_w = 0.2
devs_nobase = [d for d in DEVICES if d != "NoLift"]
for i, dev in enumerate(devs_nobase):
    s = smry[smry["device"] == dev]
    vals = [s[s["v_wind"] == v]["hub_z_std"].values[0]*1000
            if len(s[s["v_wind"] == v]) else 0 for v in V_WINDS]
    ax_std.bar(x_v + i*bar_w - bar_w, vals, bar_w,
               color=COLORS[dev], label=LABELS[dev], alpha=0.85)
    pcv = [s[s["v_wind"] == v]["P_cv_pct"].values[0]
           if len(s[s["v_wind"] == v]) else 0 for v in V_WINDS]
    ax_pcv.bar(x_v + i*bar_w - bar_w, pcv, bar_w,
               color=COLORS[dev], label=LABELS[dev], alpha=0.85)

ax_std.set_xticks(x_v); ax_std.set_xticklabels([f"{v:.0f}" for v in V_WINDS])
ax_pcv.set_xticks(x_v); ax_pcv.set_xticklabels([f"{v:.0f}" for v in V_WINDS])
ax_std.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor="#161b22")
ax_pcv.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor="#161b22")

sub11 = ts[ts["v_wind"] == V_MAIN]
for dev in devs_nobase:
    d = sub11[sub11["device"] == dev]
    if len(d):
        ax_pwr.plot(d["t"], d["P_kw"], color=COLORS[dev], lw=0.8,
                    label=LABELS[dev], alpha=0.85)
ax_pwr.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor="#161b22")
ax_pwr.axhline(10.0, color="#555", lw=0.6, ls="--")

# ── Row 2: PSD of hub_z | elevation angle | ω_gnd time series ────────────────
ax_psd  = fig.add_subplot(gs[2, 0])
ax_elev = fig.add_subplot(gs[2, 1])
ax_omg  = fig.add_subplot(gs[2, 2])

styled(ax_psd, title=f"Hub altitude PSD — v = {V_MAIN:.0f} m/s",
       xlabel="Frequency (Hz)", ylabel="PSD (m²/Hz)")
styled(ax_elev, title="Elevation angle std vs wind speed",
       xlabel="Wind speed (m/s)", ylabel="Elevation std (°)")
styled(ax_omg, title=f"Ground-shaft ω — v = {V_MAIN:.0f} m/s",
       xlabel="Time (s)", ylabel="ω_gnd (rad/s)")

psd11 = psd[psd["v_wind"] == V_MAIN]
for dev in DEVICES:
    d = psd11[psd11["device"] == dev]
    if len(d) and d["psd_m2_per_hz"].max() > 0:
        ax_psd.semilogy(d["freq_hz"], d["psd_m2_per_hz"] * 1e6,
                        color=COLORS[dev], lw=1.1, label=LABELS[dev])
ax_psd.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor="#161b22")
ax_psd.set_ylabel("PSD (mm²/Hz)", color="#aaa", fontsize=8)

for i, dev in enumerate(devs_nobase):
    s = smry[smry["device"] == dev]
    vals = [s[s["v_wind"] == v]["elev_std"].values[0]
            if len(s[s["v_wind"] == v]) else 0 for v in V_WINDS]
    ax_elev.bar(x_v + i*bar_w - bar_w, vals, bar_w,
                color=COLORS[dev], label=LABELS[dev], alpha=0.85)
ax_elev.set_xticks(x_v); ax_elev.set_xticklabels([f"{v:.0f}" for v in V_WINDS])
ax_elev.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor="#161b22")

for dev in devs_nobase:
    d = sub11[sub11["device"] == dev]
    if len(d):
        ax_omg.plot(d["t"], d["omega_gnd"], color=COLORS[dev], lw=0.8,
                    label=LABELS[dev], alpha=0.85)
ax_omg.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor="#161b22")

# ── Row 3: hub_z ratio table | instantaneous wind | corr time ─────────────────
ax_ratio = fig.add_subplot(gs[3, 0])
ax_wind  = fig.add_subplot(gs[3, 1])
ax_corr  = fig.add_subplot(gs[3, 2])

styled(ax_ratio, title="hub_z std ratio vs SingleKite",
       xlabel="Wind speed (m/s)", ylabel="Std ratio (lower = better)")
styled(ax_wind, title=f"Instantaneous wind — v = {V_MAIN:.0f} m/s",
       xlabel="Time (s)", ylabel="Wind speed (m/s)")
styled(ax_corr, title="Hub altitude autocorrelation time",
       xlabel="Wind speed (m/s)", ylabel="Corr. time (s)")

# Ratio relative to SingleKite
sk_stds = {}
for v in V_WINDS:
    row = smry[(smry["v_wind"] == v) & (smry["device"] == "SingleKite")]
    sk_stds[v] = row["hub_z_std"].values[0] if len(row) else 1.0

for i, dev in enumerate([d for d in DEVICES if d != "SingleKite" and d != "NoLift"]):
    ratios = []
    for v in V_WINDS:
        row = smry[(smry["v_wind"] == v) & (smry["device"] == dev)]
        r = row["hub_z_std"].values[0] / sk_stds[v] if len(row) and sk_stds[v] > 0 else 0
        ratios.append(r)
    ax_ratio.bar(x_v + i*bar_w - bar_w/2, ratios, bar_w,
                 color=COLORS[dev], label=LABELS[dev], alpha=0.85)

ax_ratio.axhline(1.0, color=COLORS["SingleKite"], lw=1, ls="--", label="SingleKite reference")
ax_ratio.set_xticks(x_v); ax_ratio.set_xticklabels([f"{v:.0f}" for v in V_WINDS])
ax_ratio.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor="#161b22")

d11 = sub11[sub11["device"] == "SingleKite"]
if len(d11):
    ax_wind.plot(d11["t"], d11["v_wind_inst"], color="#aaa", lw=0.7, alpha=0.8)
ax_wind.axhline(V_MAIN, color="#555", lw=0.8, ls="--")

for i, dev in enumerate(devs_nobase):
    s = smry[smry["device"] == dev]
    vals = [s[s["v_wind"] == v]["corr_time_s"].values[0]
            if len(s[s["v_wind"] == v]) else 0 for v in V_WINDS]
    ax_corr.bar(x_v + i*bar_w - bar_w, vals, bar_w,
                color=COLORS[dev], label=LABELS[dev], alpha=0.85)
ax_corr.set_xticks(x_v); ax_corr.set_xticklabels([f"{v:.0f}" for v in V_WINDS])
ax_corr.legend(fontsize=7, framealpha=0.3, labelcolor="white", facecolor="#161b22")

# ── Title ─────────────────────────────────────────────────────────────────────
fig.suptitle(
    "TRPT Lift Device Comparison — Dynamic Hub Excursion  |  10 kW prototype  |  I = 15 %",
    color="white", fontsize=12, y=0.97)

fig.savefig(OUT / "hub_excursion_analysis.png", dpi=150,
            bbox_inches="tight", facecolor=fig.get_facecolor())
plt.close()
print(f"Figure saved: {OUT}/hub_excursion_analysis.png")

# ── Markdown summary ──────────────────────────────────────────────────────────
lines = ["# Hub Excursion Long Run — Summary\n",
         f"Turbulence intensity: {15}%  |  T_sim: 60 s per case\n\n"]

for v in V_WINDS:
    lines.append(f"## v_wind = {v:.0f} m/s\n\n")
    lines.append("| Device | hub_z std (mm) | Ratio vs Single | "
                 "P_mean (kW) | P_CV (%) | Elev std (°) | Corr. time (s) |\n")
    lines.append("|--------|---------------|-----------------|"
                 "------------|----------|--------------|----------------|\n")
    sk_std = sk_stds.get(v, 1.0)
    for dev in DEVICES:
        row = smry[(smry["v_wind"] == v) & (smry["device"] == dev)]
        if not len(row): continue
        r = row.iloc[0]
        ratio = r["hub_z_std"] / sk_std if sk_std > 0 else 0
        lines.append(
            f"| {r['device']} | {r['hub_z_std']*1000:.2f} | {ratio:.2f}× | "
            f"{r['P_mean_kw']:.2f} | {r['P_cv_pct']:.1f} | "
            f"{r['elev_std']:.3f} | {r['corr_time_s']:.2f} |\n")
    lines.append("\n")

md_path = OUT / "hub_excursion_report.md"
md_path.write_text("".join(lines))
print(f"Report saved:  {md_path}")
print("\nDone.")
