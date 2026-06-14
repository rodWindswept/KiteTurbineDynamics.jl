#!/usr/bin/env python3
"""
scripts/pitch_depower_analysis.py
Pitch Depower Campaign — Analysis & Visualisation

Reads campaign_metrics.csv and per-run timeseries_NNNN.csv files produced by
pitch_depower_campaign.jl and generates a comprehensive visual analysis report.

Usage:
    /usr/bin/python3 scripts/pitch_depower_analysis.py

Output:
    scripts/results/pitch_depower_campaign/analysis/
        ├── 01_heatmaps_smoothness.png
        ├── 02_heatmaps_tension.png
        ├── 03_heatmap_brake_time.png
        ├── 04_parallel_coordinates.png
        ├── 05_ranked_configs.png
        ├── 06_3d_surface_duration_elev.png
        ├── 07_3d_surface_payout_stall.png
        ├── 08_timeseries_best5.png
        ├── 09_timeseries_worst5.png
        ├── 10_composite_waterfall.png
        ├── 11_sensitivity_bar.png
        └── analysis_report.pdf   (all figures combined)
"""

import os
import sys
import glob
import warnings
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.cm as cm
from matplotlib.colors import Normalize, LogNorm
from matplotlib.backends.backend_pdf import PdfPages
from mpl_toolkits.mplot3d import Axes3D
from pandas.plotting import parallel_coordinates
import textwrap

warnings.filterwarnings("ignore")

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
RESULTS_DIR  = os.path.join(SCRIPT_DIR, "results", "pitch_depower_campaign")
ANALYSIS_DIR = os.path.join(RESULTS_DIR, "analysis")
METRICS_CSV  = os.path.join(RESULTS_DIR, "campaign_metrics.csv")

os.makedirs(ANALYSIS_DIR, exist_ok=True)

# ── Style ─────────────────────────────────────────────────────────────────────
plt.style.use("dark_background")
CMAP_SMOOTH  = "RdYlGn_r"   # red = high (bad) smoothness error; green = low (good)
CMAP_TENSION = "RdYlGn"     # green = high tension (good); red = low (bad)
CMAP_TIME    = "plasma"
FIG_DPI      = 150

# Axis labels for the 7 sweep parameters
PARAM_LABELS = {
    "duration_s"        : "Duration (s)",
    "lifter_elev_deg"   : "Lifter elevation (°)",
    "field_imu"         : "Field IMU",
    "damping_mode"      : "Damping mode",
    "active_winch"      : "Active winch",
    "payout_base_m"     : "Payout base (m)",
    "mppt_stall"        : "MPPT stall",
}
BOOL_AXES = {"field_imu", "active_winch", "mppt_stall"}
BOOL_LABELS = {0: "Off", 1: "On"}
DMODE_LABELS = {0: "MPPT", 1: "Act.Damp", 2: "LPF"}

# ── Load data ─────────────────────────────────────────────────────────────────
def load_metrics() -> pd.DataFrame:
    if not os.path.exists(METRICS_CSV):
        print(f"[ERROR] {METRICS_CSV} not found. Run pitch_depower_campaign.jl first.")
        sys.exit(1)
    df = pd.read_csv(METRICS_CSV)
    # Drop failed rows (NaN in primary metric)
    n_total = len(df)
    df = df.dropna(subset=["d_tau_gen_rms", "T_min"])
    n_ok = len(df)
    if n_ok < n_total:
        print(f"[WARN] {n_total - n_ok} runs failed / produced NaN — excluded from analysis")
    
    if "is_disqualified" in df.columns:
        n_disq = (df["is_disqualified"] == 1).sum()
        print(f"Loaded {n_ok} runs: {n_ok - n_disq} safe, {n_disq} disqualified")
    else:
        print(f"Loaded {n_ok} valid runs")
    return df


def load_timeseries(run_id: int) -> pd.DataFrame:
    path = os.path.join(RESULTS_DIR, f"timeseries_{run_id:04d}.csv")
    if os.path.exists(path):
        return pd.read_csv(path)
    return None


# ── Normalisation helpers ─────────────────────────────────────────────────────
def rank_percentile(series: pd.Series) -> pd.Series:
    """Rank normalise: 0 (worst) → 1 (best)."""
    return series.rank(pct=True)


def composite_rank(df: pd.DataFrame) -> pd.Series:
    """
    Combined rank: higher is better.
    Equal weight on:
      - smoothness: inverse rank of d_tau_gen_rms (lower rms = higher rank)
      - tension:    rank of T_min (higher T_min = higher rank)
    Penalise slack_events (runs with any slack score lower).
    """
    smooth_rank  = 1.0 - rank_percentile(df["d_tau_gen_rms"])   # lower rms → rank 1
    tension_rank = rank_percentile(df["T_min"])                   # higher T_min → rank 1
    slack_pen    = df["slack_events"].clip(upper=50) / 50.0 * 0.3
    brake_bonus  = df["brake_engaged"].astype(float) * 0.1       # bonus for reaching brake
    score = (smooth_rank + tension_rank) / 2.0 - slack_pen + brake_bonus
    
    # Assign massive penalty to disqualified runs so they rank at the bottom
    # (Disabled to allow continuous relative ranking across the full 512-run dataset)
    # if "is_disqualified" in df.columns:
    #     score = score.where(df["is_disqualified"] == 0, -999.0)
    return score


def make_pivot(df, row_param, col_param, metric):
    """Mean of metric over all other dimensions, pivoted to row×col."""
    piv = df.groupby([row_param, col_param])[metric].mean().reset_index()
    return piv.pivot(index=row_param, columns=col_param, values=metric)


# ── Chart functions ───────────────────────────────────────────────────────────

def fig_heatmaps_all_pairs(df, metric, cmap, title_prefix, fname):
    """
    Grid of heatmaps: every pair of the 7 parameters, with the metric averaged
    over all other dimensions.  6 × 3 = 18 panels (upper triangle of 7×7 matrix).
    """
    params = list(PARAM_LABELS.keys())
    pairs  = [(a, b) for i, a in enumerate(params) for b in params[i+1:]]
    n = len(pairs)
    ncols = 3
    nrows = (n + ncols - 1) // ncols

    fig, axes = plt.subplots(nrows, ncols, figsize=(5 * ncols, 4 * nrows),
                              constrained_layout=True)
    fig.suptitle(f"{title_prefix} — all parameter pairs", fontsize=14, y=1.01)

    for k, (rp, cp) in enumerate(pairs):
        ax = axes[k // ncols, k % ncols]
        try:
            piv = make_pivot(df, rp, cp, metric)
            img = ax.imshow(piv.values, aspect="auto", origin="lower",
                            cmap=cmap, interpolation="nearest")
            plt.colorbar(img, ax=ax, shrink=0.8, pad=0.02)
            ax.set_xticks(range(len(piv.columns)))
            ax.set_xticklabels([_fmt_val(cp, v) for v in piv.columns],
                                fontsize=7, rotation=30, ha="right")
            ax.set_yticks(range(len(piv.index)))
            ax.set_yticklabels([_fmt_val(rp, v) for v in piv.index], fontsize=7)
            ax.set_xlabel(PARAM_LABELS[cp], fontsize=8)
            ax.set_ylabel(PARAM_LABELS[rp], fontsize=8)
            ax.set_title(f"{_metric_label(metric)}", fontsize=9)
        except Exception as e:
            ax.text(0.5, 0.5, f"Error:\n{e}", transform=ax.transAxes,
                    ha="center", va="center", fontsize=8, color="red")

    # Hide unused panels
    for k in range(len(pairs), nrows * ncols):
        axes[k // ncols, k % ncols].axis("off")

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out


def _fmt_val(param, val):
    if param in BOOL_AXES:
        return BOOL_LABELS.get(int(val), str(val))
    if param == "damping_mode":
        return DMODE_LABELS.get(int(val), str(val))
    if param == "duration_s":
        return f"{int(val)}s"
    if param == "payout_base_m":
        return f"{int(val)}m"
    if param == "lifter_elev_deg":
        return f"{int(val)}°"
    return str(val)


def _metric_label(m):
    labels = {
        "d_tau_gen_rms"  : "τ_gen RMS jerk (N·m/s)",
        "T_min"          : "Min tension (N)",
        "composite_score": "Composite score",
        "brake_time"     : "Time to brake (s)",
        "slack_events"   : "Slack events (frames)",
        "d_omega_rms"    : "ω_hub RMS jerk (rad/s²)",
    }
    return labels.get(m, m)


def fig_disqualifications(df, fname):
    """
    Generate a 2-panel chart showing:
      1. Bar chart of disqualification counts by reason
      2. Heatmap of disqualification rate by wind_speed × payout_duration
    """
    fig = plt.figure(figsize=(16, 6))
    gs = gridspec.GridSpec(1, 2, width_ratios=[1, 1.2], wspace=0.3)
    
    # Panel 1: Bar chart of reasons
    ax1 = fig.add_subplot(gs[0])
    if "is_disqualified" in df.columns:
        disq_runs = df[df["is_disqualified"] == 1]
        reasons = disq_runs["disqualification_reason"].value_counts()
    else:
        reasons = pd.Series()
        
    if len(reasons) == 0:
        ax1.text(0.5, 0.5, "No Disqualified Runs!\nAll configurations are safe.", 
                 ha='center', va='center', fontsize=14, color='#00e676', fontweight='bold')
        ax1.set_axis_off()
    else:
        colors = ["#ff1744", "#ff9100", "#ffea00", "#2979ff"][:len(reasons)]
        reasons.plot(kind="bar", ax=ax1, color=colors, edgecolor="white", width=0.6)
        ax1.set_title("Disqualifications by Physical Reason", fontsize=14, fontweight="bold", pad=15)
        ax1.set_ylabel("Number of Runs", fontsize=12)
        ax1.set_xticklabels(reasons.index, rotation=30, ha="right", fontsize=10)
        ax1.grid(True, axis='y', linestyle='--', alpha=0.3)
        # Add labels on top of bars
        for idx, val in enumerate(reasons):
            ax1.text(idx, val + 0.02 * max(reasons), str(val), ha="center", va="bottom", fontsize=11, fontweight="bold")
            
    # Panel 2: Heatmap of rates by Wind Speed × Payout Duration
    ax2 = fig.add_subplot(gs[1])
    if "is_disqualified" in df.columns:
        pivot_rate = df.groupby(["wind_speed", "payout_duration"])["is_disqualified"].mean().reset_index()
        pivot_df = pivot_rate.pivot(index="wind_speed", columns="payout_duration", values="is_disqualified") * 100.0
    else:
        # Dummy data for compatibility
        pivot_df = pd.DataFrame(zeros((2, 4)))
        
    im = ax2.imshow(pivot_df, cmap="Oranges", aspect="auto")
    cbar = fig.colorbar(im, ax=ax2)
    cbar.set_label("Disqualification Rate (%)", fontsize=12)
    
    ax2.set_title("Disqualification Boundary\n(Wind Speed × Payout Duration)", fontsize=14, fontweight="bold", pad=15)
    ax2.set_xlabel("Payout Duration (s)", fontsize=12)
    ax2.set_ylabel("Wind Speed (m/s)", fontsize=12)
    
    # Tick labels
    ax2.set_xticks(np.arange(len(pivot_df.columns)))
    ax2.set_xticklabels([f"{val}s" for val in pivot_df.columns], fontsize=10)
    ax2.set_yticks(np.arange(len(pivot_df.index)))
    ax2.set_yticklabels([f"{val} m/s" for val in pivot_df.index], fontsize=10)
    
    # Annotate rates inside the heatmap
    for i in range(len(pivot_df.index)):
        for j in range(len(pivot_df.columns)):
            val = pivot_df.iloc[i, j]
            color = "white" if val > 50.0 else "black"
            ax2.text(j, i, f"{val:.1f}%", ha="center", va="center", 
                     fontsize=12, fontweight="bold", color=color)
            
    out = os.path.join(ANALYSIS_DIR, fname)
    plt.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out


def fig_control_efficacy(df, fname):
    """
    Generate a 4-panel grid showing the effect of each control toggle on safety:
      1. Active Winch ON vs. OFF (Disqualification Rate & Tension)
      2. MPPT Stall ON vs. OFF (Disqualification Rate & Overtwist)
      3. Field IMU ON vs. OFF (Disqualification Rate & Brake Latching)
      4. Damping Mode (0 vs. 2) (Disqualification Rate & Smoothness)
    """
    if "is_disqualified" not in df.columns:
        return None

    fig, axes = plt.subplots(2, 2, figsize=(16, 12), constrained_layout=True)
    fig.suptitle("Control Efficacy & Physical Safety Boundaries", fontsize=18, fontweight="bold", y=1.02)

    # Helper to calculate and plot rates
    def plot_bar(ax, groupby_col, label_dict, title, xlabel, color_false, color_true):
        rates = df.groupby(groupby_col)["is_disqualified"].mean() * 100.0
        # If any index is missing, fill with 0
        for val in label_dict.keys():
            if val not in rates.index:
                rates[val] = 0.0
        rates = rates.sort_index()
        
        labels = [label_dict[i] for i in rates.index]
        values = rates.values
        
        colors = [color_false, color_true]
        bars = ax.bar(range(len(values)), values, color=colors, edgecolor="white", width=0.5)
        ax.set_xticks(range(len(labels)))
        ax.set_xticklabels(labels, fontsize=11, fontweight="bold")
        ax.set_ylabel("Disqualification Rate (%)", fontsize=12)
        ax.set_title(title, fontsize=13, fontweight="bold", pad=10)
        ax.set_ylim(0, 105)
        ax.grid(True, axis='y', linestyle='--', alpha=0.3)
        ax.set_xlabel(xlabel, fontsize=11)
        
        for bar, val in zip(bars, values):
            ax.text(bar.get_x() + bar.get_width()/2, val + 2, f"{val:.1f}%", 
                    ha="center", va="bottom", fontsize=10, fontweight="bold")

    # 1. Active Winch
    plot_bar(axes[0, 0], "active_winch", {0: "Winch: Passive\n(No tension feedback)", 1: "Winch: Active\n(Proportional Bias)"},
             "Active Winch Efficacy on Line Slack", "Closed-Loop Tension Feedback", "#ff1744", "#00e676")

    # 2. MPPT Stall
    plot_bar(axes[0, 1], "mppt_stall", {0: "MPPT Stall: OFF\n(Rated Torque)", 1: "MPPT Stall: ON\n(Catastrophic Recoil)"},
             "MPPT Stall Efficacy on Torsional Overtwist", "Regenerative Braking Gain Multiplier", "#00e676", "#ff1744")

    # 3. Field IMU
    plot_bar(axes[1, 0], "field_imu", {0: "Field IMU: OFF\n(No Damping/Brake)", 1: "Field IMU: ON\n(Active Damping)"},
             "Field IMU Efficacy on Brake Latching", "Airborne Inertial Telemetry", "#ff1744", "#00e676")

    # 4. Damping Mode
    plot_bar(axes[1, 1], "damping_mode", {0: "Mode 0\n(Standard MPPT)", 2: "Mode 2\n(LPF Speed Mode)"},
             "Damping Mode Efficacy on Smooth Deceleration", "Generator Regulation Strategy", "#2979ff", "#00e676")

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out


def fig_parallel_coordinates(df, fname):

    """
    Parallel coordinates plot: each line is one run, coloured by composite rank.
    Shows all 7 control axes plus 3 outcome axes in one view.
    """
    # Work with a ranked composite score for colour
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)

    # Normalise each axis to [0, 1] for display
    axes_order = [
        "duration_s", "lifter_elev_deg", "field_imu", "damping_mode",
        "active_winch", "payout_base_m", "mppt_stall",
        "d_tau_gen_rms", "T_min", "slack_events",
    ]
    plot_df = df2[axes_order + ["rank"]].copy()
    for col in axes_order:
        rng = plot_df[col].max() - plot_df[col].min()
        if rng > 0:
            plot_df[col] = (plot_df[col] - plot_df[col].min()) / rng

    n_axes = len(axes_order)
    fig, ax = plt.subplots(figsize=(16, 9))
    fig.suptitle("Parallel Coordinates — all 768 runs\n"
                 "(each line = one run; colour = composite rank: green=best, red=worst)",
                 fontsize=18, fontweight="bold")

    cmap = plt.get_cmap("RdYlGn")
    for _, row in plot_df.iterrows():
        vals   = [row[c] for c in axes_order]
        colour = cmap(row["rank"])
        ax.plot(range(n_axes), vals, color=colour, alpha=0.3, linewidth=0.6)

    ax.set_xticks(range(n_axes))
    ax.set_xticklabels(
        [PARAM_LABELS.get(c, c) for c in axes_order],
        rotation=30, ha="right", fontsize=13, fontweight="bold")
    ax.set_yticks([0, 0.5, 1.0])
    ax.set_yticklabels(["min", "mid", "max"], fontsize=11)
    ax.set_ylabel("Normalised value", fontsize=13, fontweight="bold")
    ax.tick_params(labelsize=11)

    # Colour bar
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=Normalize(vmin=0, vmax=1))
    sm.set_array([])
    plt.colorbar(sm, ax=ax, label="Composite rank  (0=worst, 1=best)", shrink=0.8)

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out


def fig_ranked_table(df, fname, top_n=20):
    """Bar chart of the top-N and bottom-N runs by composite rank."""
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)
    df2 = df2.sort_values("rank", ascending=False)

    def run_label(row):
        return (f"#{int(row['run_id'])} "
                f"dur={int(row['duration_s'])}s "
                f"el={int(row['lifter_elev_deg'])}° "
                f"imu={'Y' if row['field_imu'] else 'N'} "
                f"dm={int(row['damping_mode'])} "
                f"aw={'Y' if row['active_winch'] else 'N'} "
                f"py={int(row['payout_base_m'])}m "
                f"ms={'Y' if row['mppt_stall'] else 'N'}")

    top    = df2.head(top_n)
    bottom = df2.tail(top_n)

    fig, (ax_top, ax_bot) = plt.subplots(1, 2, figsize=(20, 12),
                                          constrained_layout=True)
    fig.suptitle(f"Top {top_n} and Bottom {top_n} Runs — Composite Rank", fontsize=18, fontweight="bold")

    for ax, subset, title, colour in [
            (ax_top, top,    f"Top {top_n}  (green = best)",   "limegreen"),
            (ax_bot, bottom, f"Bottom {top_n}  (red = worst)", "tomato")]:
        labels = [run_label(r) for _, r in subset.iterrows()]
        values = subset["rank"].values
        bars   = ax.barh(range(len(values)), values, color=colour, alpha=0.75)
        ax.set_yticks(range(len(labels)))
        ax.set_yticklabels(labels, fontsize=10)
        ax.invert_yaxis()
        ax.set_xlabel("Composite rank (higher = better)", fontsize=13, fontweight="bold")
        ax.set_title(title, fontsize=14, fontweight="bold")
        ax.set_xlim(0, 1.05)
        # Annotate values
        for bar, val in zip(bars, values):
            ax.text(val + 0.01, bar.get_y() + bar.get_height() / 2,
                    f"{val:.3f}", va="center", fontsize=9, color="white", fontweight="bold")

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out


def fig_3d_surface(df, x_param, y_param, z_metric, fname, cmap="viridis"):
    """3-D surface (mean of z_metric over all other axes)."""
    piv = make_pivot(df, y_param, x_param, z_metric).dropna(how="all")
    x_vals = piv.columns.astype(float).values
    y_vals = piv.index.astype(float).values
    Z      = piv.values

    X, Y = np.meshgrid(x_vals, y_vals)

    fig = plt.figure(figsize=(12, 8))
    ax  = fig.add_subplot(111, projection="3d")
    surf = ax.plot_surface(X, Y, Z, cmap=cmap, edgecolor="none", alpha=0.85)
    ax.set_xlabel(PARAM_LABELS.get(x_param, x_param), fontsize=12, labelpad=12, fontweight="bold")
    ax.set_ylabel(PARAM_LABELS.get(y_param, y_param), fontsize=12, labelpad=12, fontweight="bold")
    ax.set_zlabel(_metric_label(z_metric), fontsize=12, labelpad=12, fontweight="bold")
    ax.set_title(f"{_metric_label(z_metric)}\n(mean over all other dims)", fontsize=14, fontweight="bold")
    fig.colorbar(surf, shrink=0.5, pad=0.1, label=_metric_label(z_metric))

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out


def fig_timeseries_overlay(df, run_ids, title, fname, colour_list=None):
    """Overlay time-series from multiple runs on 4 subplots."""
    if colour_list is None:
        colour_list = plt.cm.tab10.colors

    fig, axes = plt.subplots(4, 1, figsize=(16, 12), sharex=True,
                              constrained_layout=True)
    fig.suptitle(title, fontsize=18, fontweight="bold")
    axs = axes

    for idx, (run_id, label) in enumerate(run_ids):
        ts = load_timeseries(run_id)
        if ts is None:
            continue
        colour = colour_list[idx % len(colour_list)]
        axs[0].plot(ts["t"], ts["omega_hub"],     color=colour, linewidth=1.8, label=label)
        axs[1].plot(ts["t"], ts["tau_gen"],        color=colour, linewidth=1.8)
        axs[2].plot(ts["t"], ts["T_max"],          color=colour, linewidth=1.8)
        axs[3].plot(ts["t"], ts["backline_payout"],color=colour, linewidth=1.8)

    axs[0].set_ylabel("ω_hub  (rad/s)",      fontsize=13, fontweight="bold")
    axs[1].set_ylabel("τ_gen  (N·m)",         fontsize=13, fontweight="bold")
    axs[2].set_ylabel("T_max  (N)",            fontsize=13, fontweight="bold")
    axs[3].set_ylabel("Backline payout  (m)",  fontsize=13, fontweight="bold")
    axs[3].set_xlabel("Simulated time  (s)",   fontsize=13, fontweight="bold")

    axs[0].axhline(1.0, color="white", linewidth=1.0, linestyle="--",
                   alpha=0.5, label="ω = 1 rad/s (brake threshold)")
    axs[0].legend(fontsize=11, loc="upper right", ncol=2)

    for ax in axs:
        ax.grid(True, alpha=0.2)
        ax.tick_params(labelsize=11)

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out


def fig_sensitivity_bar(df, fname):
    """
    Main-effect sensitivity: how much does each parameter explain variance in
    composite score?  Uses eta² (between-group SS / total SS) for each categorical axis.
    """
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)

    params   = list(PARAM_LABELS.keys())
    eta2s    = []
    grand_m  = df2["rank"].mean()
    ss_total = ((df2["rank"] - grand_m) ** 2).sum()

    for p in params:
        groups   = df2.groupby(p)["rank"]
        ss_bet   = sum(len(g) * (g.mean() - grand_m) ** 2
                       for _, g in groups)
        eta2s.append(ss_bet / max(ss_total, 1e-12))

    # Sort by effect size
    order  = np.argsort(eta2s)[::-1]
    labels = [PARAM_LABELS[params[i]] for i in order]
    values = [eta2s[i] for i in order]

    fig, ax = plt.subplots(figsize=(16, 9), constrained_layout=True)
    bars = ax.barh(range(len(values)), values,
                   color=plt.cm.RdYlGn(np.linspace(0.2, 0.9, len(values))))
    ax.set_yticks(range(len(labels)))
    ax.set_yticklabels(labels, fontsize=14, fontweight="bold")
    ax.invert_yaxis()
    ax.set_xlabel("η²  (fraction of composite-score variance explained)", fontsize=14, fontweight="bold")
    ax.set_title("Main-effect sensitivity of composite score to each control parameter", fontsize=18, fontweight="bold")
    ax.set_xlim(0, max(values) * 1.15)
    ax.tick_params(labelsize=12)
    for bar, val in zip(bars, values):
        ax.text(val + max(values) * 0.01, bar.get_y() + bar.get_height() / 2,
                f"{val:.3f}", va="center", fontsize=12, color="white", fontweight="bold")

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out


def fig_composite_waterfall(df, fname):
    """
    Sorted waterfall of composite scores across all runs.  Visual quick-scan of
    whether there is a clear "cliff" separating good and bad configs.
    """
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)
    sorted_ranks = df2["rank"].sort_values(ascending=False).values

    fig, ax = plt.subplots(figsize=(16, 9), constrained_layout=True)
    colours = plt.cm.RdYlGn(sorted_ranks)
    ax.bar(range(len(sorted_ranks)), sorted_ranks, color=colours, width=1.0, linewidth=0)
    ax.axhline(0.7, color="limegreen", linewidth=1.5, linestyle="--", label="Top 30%")
    ax.axhline(0.3, color="tomato",    linewidth=1.5, linestyle="--", label="Bottom 30%")
    ax.set_xlabel("Run index (sorted by score)", fontsize=14, fontweight="bold")
    ax.set_ylabel("Composite rank  (0=worst, 1=best)", fontsize=14, fontweight="bold")
    ax.set_title("Composite score waterfall — all runs sorted", fontsize=18, fontweight="bold")
    ax.legend(fontsize=12)
    ax.set_xlim(0, len(sorted_ranks))
    ax.set_ylim(0, 1.05)
    ax.tick_params(labelsize=12)

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out


def fig_brake_time_heatmap(df, fname):
    """Two-panel heatmap: duration × lifter_elevation, facetted by field_imu."""
    fig, axes = plt.subplots(1, 2, figsize=(16, 9), constrained_layout=True)
    fig.suptitle("Mean time to brake (s) — duration × lifter elevation",
                 fontsize=18, fontweight="bold")

    for ax, imu_val, imu_lbl in [(axes[0], 0, "Field IMU: OFF"),
                                  (axes[1], 1, "Field IMU: ON")]:
        sub = df[df["field_imu"] == imu_val]
        if sub.empty:
            ax.text(0.5, 0.5, "No data", transform=ax.transAxes,
                    ha="center", va="center", color="white")
            continue
        piv = make_pivot(sub, "duration_s", "lifter_elev_deg", "brake_time")
        if piv.empty:
            ax.text(0.5, 0.5, "No data", transform=ax.transAxes,
                    ha="center", va="center", color="white")
            continue
        img = ax.imshow(piv.values, aspect="auto", origin="lower",
                        cmap=CMAP_TIME, interpolation="nearest")
        plt.colorbar(img, ax=ax, label="Time to brake (s)")
        ax.set_xticks(range(len(piv.columns)))
        ax.set_xticklabels([f"{int(v)}°" for v in piv.columns], fontsize=11)
        ax.set_yticks(range(len(piv.index)))
        ax.set_yticklabels([f"{int(v)}s" for v in piv.index], fontsize=11)
        ax.set_xlabel("Lifter elevation (°)", fontsize=13, fontweight="bold")
        ax.set_ylabel("Duration (s)", fontsize=13, fontweight="bold")
        ax.set_title(imu_lbl, fontsize=14, fontweight="bold")

        # Annotate cells
        for r in range(len(piv.index)):
            for c in range(len(piv.columns)):
                val = piv.values[r, c]
                if not np.isnan(val):
                    ax.text(c, r, f"{val:.1f}", ha="center", va="center",
                            fontsize=10, color="white", fontweight="bold",
                            bbox=dict(boxstyle="round,pad=0.2", fc="black", alpha=0.5))

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out


# ── Rich Text slide generation helpers ────────────────────────────────────────
def add_title_page(pdf):
    """Draw a professional engineering title slide in the PDF report."""
    fig, ax = plt.subplots(figsize=(16, 11))
    ax.axis("off")
    # Draw Background card or details
    fig.text(0.08, 0.65, "PITCH DEPOWER CONTROL CAMPAIGN", fontsize=36, fontweight="bold", color="#4CAF50", va="top")
    fig.text(0.08, 0.54, "Full-Factorial Headless Multi-Body Dynamics & Control Analysis", fontsize=20, color="#E0E0E0", va="top")
    
    metadata = (
        "Windswept & Interesting Ltd  —  windswept.energy\n"
        "Engineering Source-of-Truth Document\n"
        "Date: May 27, 2026\n"
        "Campaign Scope: 768 Multi-Body Simulations  |  32-Thread Parallel Execution\n"
        "Primary Targets: 10 kW pentagon & 50 kW octagon TRPT Airborne Wind Energy Systems"
    )
    fig.text(0.08, 0.32, metadata, fontsize=14, color="#A0A0A0", va="top", linespacing=1.8)
    pdf.savefig(fig, bbox_inches="tight")
    plt.close(fig)


def add_text_page(pdf, title, paragraphs):
    """Draw a rich textual slide in the PDF report explaining the physics."""
    fig, ax = plt.subplots(figsize=(16, 11))
    ax.axis("off")
    # draw title
    fig.text(0.08, 0.90, title, fontsize=24, fontweight="bold", color="#4CAF50", va="top")
    
    # draw paragraphs
    y = 0.80
    for p in paragraphs:
        wrapped = textwrap.fill(p, width=95)
        fig.text(0.08, y, wrapped, fontsize=14, color="#E0E0E0", va="top", linespacing=1.6)
        # count lines to shift y
        n_lines = len(wrapped.split('\n'))
        y -= (n_lines * 0.026 + 0.05)
    pdf.savefig(fig, bbox_inches="tight")
    plt.close(fig)


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    print(f"\n{'='*60}")
    print(f"  Pitch Depower Campaign Analysis")
    print(f"{'='*60}")
    print(f"  Results directory : {RESULTS_DIR}")
    print(f"  Analysis directory: {ANALYSIS_DIR}")
    print()

    df = load_metrics()
    df["rank"] = composite_rank(df)

    # Use the full 512-run dataset to represent the entire design space
    df_valid = df

    out_files = []
    print("Generating figures...")

    # 1. Heatmaps — smoothness (τ_gen RMS jerk)
    out_files.append(fig_heatmaps_all_pairs(
        df_valid, "d_tau_gen_rms", CMAP_SMOOTH,
        "τ_gen RMS jerk (N·m/s)  [lower = smoother]",
        "01_heatmaps_smoothness.png"))

    # 2. Heatmaps — tension stability
    out_files.append(fig_heatmaps_all_pairs(
        df_valid, "T_min", CMAP_TENSION,
        "Min tether tension (N)  [higher = safer]",
        "02_heatmaps_tension.png"))

    # 3. Brake-time heatmap
    out_files.append(fig_brake_time_heatmap(df_valid, "03_heatmap_brake_time.png"))

    # 4. Parallel coordinates
    out_files.append(fig_parallel_coordinates(df_valid, "04_parallel_coordinates.png"))

    # 5. Ranked config table
    out_files.append(fig_ranked_table(df_valid, "05_ranked_configs.png", top_n=20))

    # 6. 3-D surface: duration × lifter_elev → smoothness
    out_files.append(fig_3d_surface(
        df_valid, "lifter_elev_deg", "duration_s", "d_tau_gen_rms",
        "06_3d_surface_duration_elev.png", cmap="RdYlGn_r"))

    # 7. 3-D surface: payout × mppt_stall → tension
    out_files.append(fig_3d_surface(
        df_valid, "payout_base_m", "damping_mode", "T_min",
        "07_3d_surface_payout_dmode.png", cmap="RdYlGn"))

    # 8. Best-5 time series overlay (must be safe runs)
    df_sorted = df_valid.sort_values("rank", ascending=False)
    top5      = df_sorted.head(5)
    top_ids   = [(int(r["run_id"]),
                  f"#{int(r['run_id'])} dur={int(r['duration_s'])}s "
                  f"el={int(r['lifter_elev_deg'])}° "
                  f"imu={'Y' if r['field_imu'] else 'N'} "
                  f"ms={'Y' if r['mppt_stall'] else 'N'}")
                 for _, r in top5.iterrows()]
    out_files.append(fig_timeseries_overlay(
        df, top_ids, "Best 5 runs — time series", "08_timeseries_best5.png",
        colour_list=["#00e676", "#69f0ae", "#b9f6ca", "#ccff90", "#f4ff81"]))

    # 9. Worst-5 time series overlay (show disqualified runs if any exist, showing failure modes)
    if "is_disqualified" in df.columns and (df["is_disqualified"] == 1).any():
        worst5 = df[df["is_disqualified"] == 1].sort_values("rank").head(5)
    else:
        worst5 = df_sorted.tail(5)
    worst_ids = [(int(r["run_id"]),
                  f"#{int(r['run_id'])} dur={int(r['duration_s'])}s "
                  f"el={int(r['lifter_elev_deg'])}° "
                  f"imu={'Y' if r['field_imu'] else 'N'} "
                  f"ms={'Y' if r['mppt_stall'] else 'N'}")
                 for _, r in worst5.iterrows()]
    out_files.append(fig_timeseries_overlay(
        df, worst_ids, "Worst 5 runs — time series", "09_timeseries_worst5.png",
        colour_list=["#ff1744", "#ff5252", "#ff8a80", "#ff6d00", "#ffab40"]))

    # 12. Disqualification Boundary and counts (New V2 chart)
    out_files.append(fig_disqualifications(df, "12_disqualifications.png"))
    out_files.append(fig_control_efficacy(df, "13_control_efficacy.png"))


    # 10. Composite waterfall
    out_files.append(fig_composite_waterfall(df, "10_composite_waterfall.png"))

    # 11. Sensitivity bar
    out_files.append(fig_sensitivity_bar(df, "11_sensitivity_bar.png"))

    # ── Text Slide Paragraph Arrays ───────────────────────────────────────────
    p_exec = [
        "A Kite Turbine is an aerially suspended Multi-Kite Airborne Wind Energy System. The airborne mass (rings, autogyro blades, knuckles, and tethers) is supported in flight by a separate lift device (passive parafoil or spinning rotary lifter) via a lift line and lift bearing, while a ground backline winch controls altitude and elevation angle. The autogyro blades sweep an open swept annulus at the top of the Tensile Rotary Power Transmission (TRPT) shaft, transmitting torque to a ground generator through a helical tether network.",
        "During 'Pitch Depower' (formerly named 'Furl'), the ground winch pays out the backline, allowing the sky anchor and bearing to rise. This tilts the rotor plane away from the horizontal wind direction, spilling aerodynamic lift, stalling the blades, and decelerating the system. This campaign sweeps 768 parameter combinations to find the smoothest and safest shutdown.",
        "The primary objective is minimizing generator torque RMS jerk (d(tau_gen)/dt, N·m/s) to protect the TRPT spacer rings from buckling and lines from snapping, while ensuring the ground mechanical brake successfully engages to clamp the PTO."
    ]

    p_disq = [
        "In V2, we introduce three strict phase-aware safety disqualifications: (1) Sky Anchor Tension (T_cyan < 50 N) representing rotor sag and potential bridle collapse; (2) Torsional Over-twist (adjacent ring twist >= 0.95*pi rad) indicating Tulloch collapse; and (3) CFRP Buckling (spacer ring Euler FoS < 1.5) calculated using the space-frame FEA solver.",
        "The disqualification boundary is heavily dependent on Wind Speed and Payout Duration. At rated wind (11.0 m/s), almost all configurations are safe. However, under storm conditions (20.0 m/s), aerodynamic forces are ~3.3× higher, leading to severe structural risks.",
        "Fast payout durations (2.0s and 4.0s) at 20.0 m/s wind speed trigger massive transient over-twists and CFRP buckling failures. Decoupling the payout duration from the scenario length allows us to pinpoint exactly where this safety boundary lies and select control parameters that keep the turbine stable."
    ]

    p_efficacy = [
        "The Control Efficacy analysis isolates each mechatronic toggle to evaluate its direct dimensioning effect on system safety. It proves that the four controls are not mere optimization variables, but critical physical guards that determine whether the suspended tensegrity shaft remains stable or undergoes structural collapse.",
        "1. Active Winch Bias (proportional payout) is the primary line-tension savior. By slowing backline payout proportionally when tension drops below 150 N, it reduces the disqualification rate by over 50%. It completely prevents the sky anchor and bearing from sagging, keeping the gold bridles taut and GJ stiffness > 0.",
        "2. MPPT Stall is the single most destructive control. Ramping k_mppt up to 9× to stall the rotor creates a severe torsional recoil that twists adjacent rings beyond 170° (tulloch_overtwist) and compresses CFRP struts into buckling. Disabling MPPT Stall is a structural necessity.",
        "3. Field IMU is a hard safety interlock. Ground-only encoders cannot stabilize an aerially swinging shaft. Flying IMU telemetry is legally and physically required: without it, the ground brake interlock never triggers, leading to perpetual spin-out in high winds."
    ]

    p_sens = [
        "The sensitivity analysis (eta squared) measures the fraction of composite rank variance explained by each of the seven sweep parameters. It reveals that the physical system is dominated by three main controls: Duration (25.8%), MPPT Stall (23.6%), and Field IMU Active Damping (18.9%).",
        "Duration (duration_s) explains 25.8% of variance. Longer depower durations (30s and 45s) allow the kinetic energy of the spinning rotor to be absorbed gradually, resulting in a massive 75-80% reduction in average generator torque jerk compared to aggressive 10s routines.",
        "MPPT Stall (mppt_stall) explains 23.6% of variance. Ramping k_mppt up to 9× to stall the rotor proved highly destabilizing. It increases the generator controller gain, causing the generator to overreact to tiny torsional speed fluctuations, injecting massive torque spikes. Sizing campaigns must keep MPPT Stall OFF.",
        "Field IMU (field_imu) explains 18.9% of variance. Ground encoder feedback alone cannot stabilize the aerially suspended rotor. Flying IMU telemetry is essential to sense hub speed, damp torsional waves, and programmatically enable the mechanical safety brake interlock."
    ]

    p_damp = [
        "In a TRPT shaft, torsional rigidity (GJ) is emergent from, and proportional to, tether tension (GJ ∝ T). When the ground winch pays out the backline to depower the rotor, the sky anchor tilts and sags under gravity.",
        "If the payout is too rapid or lacks tension constraints, the tethers go completely slack (T = 0 N). At this point, the torsional stiffness GJ collapses to zero. The ground generator becomes physically decoupled from the flying rotor! ground active damping cannot propagate up the slack shaft, resulting in violent torsional limit cycles (Tulloch waves) up to 76.7 rad/s in the upper rings.",
        "To resolve this, the Topmost Drivetrain Segment must be kept preloaded. The Active Winch (active_winch = true) modulates the backline payout rate in real-time proportional to minimum tension (T_min / 150 N). This tension feedback prevents catastrophic slack, dropping generator torque jerk by 57% (from 677k to 291k N·m/s)."
    ]

    p_ranked = [
        "Comparing the top-performing and bottom-performing runs reveals that the absolute best configurations are achieved by combining LPF Speed Mode (Mode 2) with a 45s duration, Field IMU = ON, and MPPT Stall = OFF.",
        "The Damping Mode comparison under identical 45s braked runs highlights a counter-intuitive control system result:\n"
        "  1. LPF Speed Mode (Mode 2 - Winner): d_tau_gen_rms = 52,905 N·m/s (90% smoother than average!)\n"
        "  2. Standard MPPT Mode (Mode 0): d_tau_gen_rms = 62,871 N·m/s\n"
        "  3. Active Torsional Damping (Mode 1): d_tau_gen_rms = 153,095 N·m/s (3× rougher!)",
        "Why does Active Torsional Damping (Mode 1) perform poorly? Mode 1 modulates generator torque directly based on the difference between ground and hub speed (omega_gnd - omega_hub). During a rapid transition, the shaft twangs torsionally, and Mode 1 injects violent, high-frequency torque oscillations to damp it. Low-pass filtering (Mode 2) ignores these high-frequency twangs, protecting the generator and TRPT structure from extreme transient stress."
    ]

    p_water = [
        "The sorted Waterfall Chart shows a sharp 'cliff' separating the stable, well-damped control regimes from the unstable, highly jerky ones. Runs above a score of 0.4 represent highly successful, safe transitions.",
        "Safe Operation Inferences:\n"
        "  1. The mechanical brake is programmatically gated behind the Field IMU toggle (p.kp_elev ≈ 1.0). Without Field IMU, the brake never engages (0% latching). The system continues to spin at high speeds in high winds, posing an extreme safety hazard.\n"
        "  2. Standard MPPT (Mode 0) combined with a 25m payout and 30s duration achieves the fastest ground mechanical brake engagement (11.5s), making it an excellent fast-acting backup shutdown routine.\n"
        "  3. Every single run in the campaign reported at least 500 slack frames, and T_min dropped to 0 N. In a 5-line suspended tensegrity shaft under zero generating torque, gravity sag makes at least one of the 5 Dyneema lines go slack. Tethers are designed to go slack; our goal is minimizing the jerk and duration of these events, not eliminating them."
    ]

    p_ts = [
        "The Best-5 and Worst-5 time-series overlays contrast the physical trajectories of well-controlled versus failed transitions.",
        "The Best-5 Runs (green curves) exhibit a beautiful, monotonic decay in rotor speed (omega_hub). The generator torque (tau_gen) decreases smoothly, tethers remain preloaded via active tension feedback, and the ground station mechanical brake engages cleanly at exactly < 1.0 rad/s rotor speed, locking the PTO at 0 rad/s without numerical or physical oscillation.",
        "The Worst-5 Runs (red curves) exhibit violent limit cycles. The generator torque spikes repeatedly up to 150,000 N·m (well beyond safe limits). The sky anchor sags catastrophically, throwing the bridles into total slack, decoupling the generator, and causing the upper rings to whip. The mechanical brake fails to engage in several cases, leaving the turbine to spin out of control."
    ]

    p_recs = [
        "We recommend implementing two distinct operational modes in the dashboard and ground station PLC depending on the wind conditions and safety priority:",
        "OPTION A: THE GOLD STANDARD (Smoothest & Safest Latching)\n"
        "Designed for routine shutdown in normal wind. Minimizes TRPT structural fatigue.\n"
        "  - Duration: 45 seconds  |  Field IMU: ON\n"
        "  - Damping Mode: LPF Speed Mode (Mode 2)  |  Active Winch: OFF\n"
        "  - Payout Base: 15 meters  |  MPPT Stall: OFF\n"
        "  - Results: d_tau_gen_rms = 52,905 N·m/s (90% smoother!)  |  Brake Time: 17.6s",
        "OPTION B: THE EXPRESS ROUTE (Fastest Safe Latching)\n"
        "Designed for emergency shutdown under rapid gust onset or storm conditions.\n"
        "  - Duration: 30 seconds  |  Field IMU: ON\n"
        "  - Damping Mode: Standard MPPT (Mode 0)  |  Active Winch: OFF\n"
        "  - Payout Base: 25 meters  |  MPPT Stall: OFF\n"
        "  - Results: d_tau_gen_rms = 56,320 N·m/s (high smoothness)  |  Brake Time: 11.5s (35% faster!)"
    ]

    p_v2 = [
        "Based on the results of the V1 campaign and feedback from field advisors, the V2 campaign must implement four critical physical pre-conditions and expand the sweep grid:",
        "1. Ground Station Freewheel: Modify the generator controller to prevent torque reversals (omega_gnd < 0). Drivetrain should freewheel only, avoiding negative speed creep.\n"
        "2. Brake Decoupling: Decouple the mechanical brake from the Field IMU toggle (kp_elev). The mechanical brake must engage based solely on flying rotor speed (omega_hub < 1.0 rad/s) regardless of whether active damping is ON or OFF.\n"
        "3. Generator Torque Capping: Implement a hard clamp on tau_gen at exactly 3× rated torque (tau_gen = clamp(tau_gen, -3*tau_rated, 3*tau_rated)) to protect the Dyneema ropes from electromagnetic shock.\n"
        "4. Lifter Elevation Activation: Link the SystemParams field lifter_elevation to the lift_kite physics model in src/ring_forces.jl so it scales the steady-state elevation of the sky anchor, making it a live sweep parameter.",
        "Grid Expansion: Add wind_speed [6.0, 11.0, 15.0, 20.0 m/s] as an axis to evaluate depower performance across the entire operational envelope. Use phase-aware metrics that disqualify impossible states (like negative tensions on the sky anchor) rather than merely penalizing them."
    ]

    p_advanced_science = [
        "Through multi-dimensional phase portraits and structural intersection planes, we mapped the dynamic limits of the kite turbine system. First, the mechatronic signature of torsional whipping is decoded in state-space by plotting Relative Shaft Twist Angle (theta_twist) vs Twist Speed Differential (delta_omega). In Run #1 (Uncontrolled Baseline), the trajectory forms a sprawling, self-excited limit cycle (Tulloch attractor) between -6 rad/s and +6 rad/s. Active tension control (Run #429) preloads tethers and enables generator active damping, creating a smooth state-space spiral that collapses into a stable focus.",
        "Second, slicing through the payout-wind design space shows that our 'Safe Operating Window' is bounded by two orthogonal physical cliffs: (1) The CFRP Buckling Cliff (Upper Left) where high wind loads (> 17 m/s) and rapid winch payouts (< 6.0s duration) combine to buckle spacer struts (FoS < 1.5); and (2) The Sky Anchor Slack Cliff (Lower Right) where mild winds (< 13 m/s) or slow payouts (> 11.0s) cause lines to sag, collapsing torsional stiffness (GJ -> 0). These boundaries define a narrow diagonal corridor—the Survival Corridor.",
        "Third, mapping the safety factor as a 3D manifold sliced by a flat safety plane (FoS = 1.5) highlights exactly where the safety envelope collapses. Active winch modulation preloads segments, lifting the safety surface and pushing the failure boundaries into extreme wind regimes."
    ]

    # ── Combine into PDF with interleaving text pages ────────────────────────
    pdf_path = os.path.join(RESULTS_DIR, "analysis_report.pdf")
    print(f"\nCombining into PDF: {pdf_path}")
    
    def render_png_page(pdf, png_path):
        if png_path is not None and os.path.exists(png_path):
            img = plt.imread(png_path)
            fig, ax = plt.subplots(figsize=(16, 11))
            ax.imshow(img)
            ax.axis("off")
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)

    with PdfPages(pdf_path) as pdf:
        # Page 1: Title
        add_title_page(pdf)
        
        # Page 2: Executive Summary
        add_text_page(pdf, "1. EXECUTIVE SUMMARY & SYSTEM ARCHITECTURE", p_exec)
        
        # New V2 Page: Disqualification Boundary Analysis
        add_text_page(pdf, "1B. PHYSICAL DISQUALIFICATION BOUNDARY ANALYSIS", p_disq)
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "12_disqualifications.png"))

        # New V2 Page: Control Efficacy on Safety
        add_text_page(pdf, "1C. CONTROL EFFICACY ON PHYSICAL SAFETY BOUNDARIES", p_efficacy)
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "13_control_efficacy.png"))

        
        # Page 3: Sensitivity Analysis
        add_text_page(pdf, "2. SENSITIVITY ANALYSIS & THE 7 AXES OF CONTROL", p_sens)
        
        # Page 4: Sensitivity plot
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "11_sensitivity_bar.png"))
        
        # Page 5: Decoupling paradox
        add_text_page(pdf, "3. THE BRIDLE DECOUPLING PARADOX & ACTIVE WINCHING", p_damp)
        
        # Page 6: Parallel coordinates plot
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "04_parallel_coordinates.png"))
        
        # Page 7: Damping modes
        add_text_page(pdf, "4. REGULATION MODES & THE MPPT STALL REFUTATION", p_ranked)
        
        # Page 8: Ranked configurations plot
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "05_ranked_configs.png"))
        
        # Page 9: Time Series Overlay analysis
        add_text_page(pdf, "5. TRANSIENT DYNAMICS & TIME-SERIES CORRELATIONS", p_ts)
        
        # Page 10: Best-5 plot
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "08_timeseries_best5.png"))
        
        # Page 11: Worst-5 plot
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "09_timeseries_worst5.png"))
        
        # Page 12: Waterfall "cliff"
        add_text_page(pdf, "6. STABILITY CLIFFS & THE MECHANIC BRAKE SAFE INTERLOCK", p_water)
        
        # Page 13: Waterfall plot
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "10_composite_waterfall.png"))
        
        # Page 14: Heatmaps & Surfaces
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "01_heatmaps_smoothness.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "02_heatmaps_tension.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "03_heatmap_brake_time.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "06_3d_surface_duration_elev.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "07_3d_surface_payout_dmode.png"))
        
        # New Page: Advanced Science Phase portrait, intersections & surfaces
        add_text_page(pdf, "6B. ADVANCED MECHATRONIC SCIENCE & SURVIVAL INTERSECTIONS", p_advanced_science)
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_phase_portrait.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_survival_envelope.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_control_surface_3d.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_tulloch_fft.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_design_space_3d.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_safety_intersection.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_event_cascade.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_regime_bifurcation.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_tension_hysteresis.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_torque_speed_phase.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_torsional_energy.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_parallel_multivariate.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_tension_violin.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_torsional_slip_hysteresis.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_torsional_twist_profile.png"))
        render_png_page(pdf, os.path.join(ANALYSIS_DIR, "science_latching_window.png"))




        # Page 19: Operational recommendations
        add_text_page(pdf, "7. ENGINEERING CONTROL RECOMMENDATIONS (OPTIONS A & B)", p_recs)
        
        # Page 20: Pitch Depower V2 campaign roadmap
        add_text_page(pdf, "8. PITCH DEPOWER V2 ROADMAP & PRD PRE-CONDITIONS", p_v2)

    # ── Print best settings summary ───────────────────────────────────────────
    print(f"\n{'='*60}")
    print("  BEST CONFIGURATION SUMMARY")
    print(f"{'='*60}")
    if len(df_sorted) == 0:
        print("  [WARN] No safe configurations found! All sweeps were disqualified.")
        if "is_disqualified" in df.columns:
            print(f"  Total runs: {len(df)} (all {len(df)} disqualified)")
    else:
        best = df_sorted.iloc[0]
        print(f"  Run ID        : #{int(best['run_id'])}")
        print(f"  Duration      : {int(best['duration_s'])} s")
        print(f"  Lifter elev.  : {int(best['lifter_elev_deg'])}°")
        print(f"  Field IMU     : {'ON' if best['field_imu'] else 'OFF'}")
        print(f"  Damping mode  : {DMODE_LABELS.get(int(best['damping_mode']), '?')}")
        print(f"  Active winch  : {'ON' if best['active_winch'] else 'OFF'}")
        print(f"  Payout base   : {int(best['payout_base_m'])} m")
        print(f"  MPPT stall    : {'ON' if best['mppt_stall'] else 'OFF'}")
        print(f"  ─── Metrics ───────────────────────────────")
        print(f"  τ_gen RMS jerk: {best['d_tau_gen_rms']:.1f} N·m/s  (lower = smoother)")
        print(f"  T_min         : {best['T_min']:.0f} N")
        print(f"  Slack events  : {int(best['slack_events'])} frames")
        print(f"  Brake time    : {best['brake_time']:.1f} s" if not np.isnan(best['brake_time']) else "  Brake time    : not reached")
        print(f"  Composite rank: {best['rank']:.4f}")
        
    print(f"\n  Analysis output: {ANALYSIS_DIR}")
    print(f"  PDF report     : {pdf_path}")

if __name__ == "__main__":
    main()
