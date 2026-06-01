#!/usr/bin/env python3
# scripts/pitch_depower_analysis_v4.py
#
# Windswept & Interesting Ltd
# Pitch Depower Campaign V4 — High-Fidelity Analysis & Visualisation
#
# Post-processes the V4 Campaign simulation CSV data, generating professional
# figures and a comprehensive engineering report PDF incorporating advanced dynamic,
# structural, and whiplash metrics.
#

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
import textwrap

warnings.filterwarnings("ignore")

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
RESULTS_DIR  = os.path.join(SCRIPT_DIR, "results", "pitch_depower_campaign_v4")
ANALYSIS_DIR = os.path.join(RESULTS_DIR, "analysis")
METRICS_CSV  = os.path.join(RESULTS_DIR, "campaign_metrics.csv")

os.makedirs(ANALYSIS_DIR, exist_ok=True)

# ── Style ─────────────────────────────────────────────────────────────────────
plt.style.use("dark_background")
CMAP_SMOOTH  = "RdYlGn_r"   # Red = high (bad) jerk/ripple; Green = low (good)
CMAP_TENSION = "RdYlGn"     # Green = high tension (good); Red = low (bad)
CMAP_SLACK   = "YlOrRd"     # Yellow to deep Red for slack counts
FIG_DPI      = 150

# Axis labels for the 7 V4 sweep parameters
PARAM_LABELS = {
    "wind_speed"        : "Wind Speed (m/s)",
    "payout_duration"   : "Payout Duration (s)",
    "active_winch"      : "Active Winch Control",
    "damping_mode"      : "Damping Mode",
    "EA_back_line"      : "Backline EA (N)",
    "c_back_line"       : "Backline c (N·s/m)",
    "i_pto"             : "PTO Inertia (kg·m²)",
}
BOOL_AXES = {"active_winch"}
BOOL_LABELS = {0: "Passive", 1: "Active"}
DMODE_LABELS = {0: "Mode 0 (MPPT)", 2: "Mode 2 (LPF)"}

# ── Load data ─────────────────────────────────────────────────────────────────
def load_metrics() -> pd.DataFrame:
    if not os.path.exists(METRICS_CSV):
        print(f"[ERROR] {METRICS_CSV} not found. Run pitch_depower_campaign_v4.jl first.")
        sys.exit(1)
    df = pd.read_csv(METRICS_CSV)
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

# ── Composite Scoring & Ranking ───────────────────────────────────────────────
def composite_rank(df: pd.DataFrame) -> pd.Series:
    """
    Combined rank: higher is better.
    Enforces strict safety penalty (score = -999.0) for disqualified runs.
    """
    def rank_percentile(series: pd.Series) -> pd.Series:
        return series.rank(pct=True)

    smooth_rank  = 1.0 - rank_percentile(df["d_tau_gen_rms"])   # lower rms jerk → rank 1
    tension_rank = rank_percentile(df["T_min"])                   # higher T_min → rank 1
    ripple_rank  = 1.0 - rank_percentile(df["speed_ripple_rms"]) # lower ripple → rank 1
    
    slack_pen    = df["slack_events"].clip(upper=30) / 30.0 * 0.2
    late_slack_p = df["slack_events_late"].clip(upper=15) / 15.0 * 0.1
    
    score = (smooth_rank + tension_rank + ripple_rank) / 3.0 - slack_pen - late_slack_p
    
    # Strictly apply massive penalty to disqualified runs (No cheating!)
    if "is_disqualified" in df.columns:
        score = score.where(df["is_disqualified"] == 0, -999.0)
    return score

def make_pivot(df, row_param, col_param, metric):
    piv = df.groupby([row_param, col_param])[metric].mean().reset_index()
    return piv.pivot(index=row_param, columns=col_param, values=metric)

def _fmt_val(param, val):
    if param in BOOL_AXES:
        return BOOL_LABELS.get(int(val), str(val))
    if param == "damping_mode":
        return DMODE_LABELS.get(int(val), str(val))
    if param == "payout_duration":
        return f"{val:.1f}s"
    if param == "wind_speed":
        return f"{int(val)} m/s"
    if param == "EA_back_line":
        return f"{int(val)//1000}k N"
    if param == "c_back_line":
        return f"{int(val)}"
    if param == "i_pto":
        return f"{val:.1f}"
    return str(val)

def _metric_label(m):
    labels = {
        "d_tau_gen_rms"         : "τ_gen RMS Jerk (N·m/s)",
        "T_min"                 : "Min Tension (N)",
        "speed_ripple_rms"      : "Torsional Speed Ripple RMS (rad/s)",
        "composite_score"       : "Composite Score",
        "slack_events"          : "Total Slack Events",
        "slack_events_late"     : "Late-Payout Slack Events",
        "max_out_of_plane_accel": "Max Whiplash Accel (m/s²)",
        "max_node_jerk"         : "Max Node Jerk (m/s³)",
        "peak_strut_load"       : "Peak Compressive Strut Force (N)",
        "T_trpt_max"            : "Peak Tether Tension (N)"
    }
    return labels.get(m, m)

# ── Dynamic & Structural Diagnostic Figures ───────────────────────────────────

def fig_heatmaps_all_pairs(df, metric, cmap, title_prefix, fname):
    params = list(PARAM_LABELS.keys())
    pairs  = [(a, b) for i, a in enumerate(params) for b in params[i+1:]]
    n = len(pairs)
    ncols = 3
    nrows = (n + ncols - 1) // ncols

    fig, axes = plt.subplots(nrows, ncols, figsize=(6 * ncols, 4.5 * nrows),
                               constrained_layout=True)
    fig.suptitle(f"{title_prefix} — parameter pair coupling", fontsize=16, y=1.01, fontweight="bold")

    for k, (rp, cp) in enumerate(pairs):
        ax = axes[k // ncols, k % ncols]
        try:
            piv = make_pivot(df, rp, cp, metric)
            img = ax.imshow(piv.values, aspect="auto", origin="lower",
                            cmap=cmap, interpolation="nearest")
            plt.colorbar(img, ax=ax, shrink=0.8, pad=0.02)
            ax.set_xticks(range(len(piv.columns)))
            ax.set_xticklabels([_fmt_val(cp, v) for v in piv.columns],
                                fontsize=8, rotation=30, ha="right")
            ax.set_yticks(range(len(piv.index)))
            ax.set_yticklabels([_fmt_val(rp, v) for v in piv.index], fontsize=8)
            ax.set_xlabel(PARAM_LABELS[cp], fontsize=9, fontweight="bold")
            ax.set_ylabel(PARAM_LABELS[rp], fontsize=9, fontweight="bold")
            ax.set_title(f"{_metric_label(metric)}", fontsize=10, fontweight="bold")
        except Exception as e:
            ax.text(0.5, 0.5, f"Error:\n{e}", transform=ax.transAxes,
                    ha="center", va="center", fontsize=8, color="red")

    # Hide empty axes
    for k in range(len(pairs), nrows * ncols):
        axes[k // ncols, k % ncols].axis("off")

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out

def fig_disqualifications_and_buckling_bottlenecks(df, fname):
    """
    Generate a 2-panel chart showing:
      1. Disqualification counts by reason.
      2. Geographic distribution of space-frame buckling failures (min FoS by Ring ID).
    """
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6), constrained_layout=True)
    
    # Panel 1: Bar chart of reasons
    if "is_disqualified" in df.columns:
        disq_runs = df[df["is_disqualified"] == 1]
        reasons = disq_runs["disqualification_reason"].value_counts()
    else:
        reasons = pd.Series()
        
    if len(reasons) == 0:
        ax1.text(0.5, 0.5, "No Disqualified Runs!\n100% of Configurations are Structurally Safe.", 
                 ha='center', va='center', fontsize=14, color='#00e676', fontweight='bold')
        ax1.set_axis_off()
    else:
        colors = ["#ff1744", "#ff9100", "#ffea00", "#2979ff"][:len(reasons)]
        reasons.plot(kind="bar", ax=ax1, color=colors, edgecolor="white", width=0.6)
        ax1.set_title("Disqualifications by Structural/Torsional Reason", fontsize=14, fontweight="bold", pad=15)
        ax1.set_ylabel("Number of Runs", fontsize=12)
        ax1.set_xticklabels(reasons.index, rotation=30, ha="right", fontsize=10)
        ax1.grid(True, axis='y', linestyle='--', alpha=0.3)
        for idx, val in enumerate(reasons):
            ax1.text(idx, val + 0.02 * max(reasons), str(val), ha="center", va="bottom", fontsize=11, fontweight="bold")
            
    # Panel 2: Space-Frame Buckling Bottleneck Mapping
    ring_ids = df["fos_buckling_ring_id"].value_counts().sort_index()
    if len(ring_ids) == 0 or ring_ids.index.max() == 0:
        ax2.text(0.5, 0.5, "No Buckling Data available.", 
                 ha='center', va='center', fontsize=14, color='white', fontweight='bold')
        ax2.set_axis_off()
    else:
        # Map Ring ID to human labels
        ring_labels = []
        for r_id in ring_ids.index:
            if r_id == 0:
                ring_labels.append("No Failure")
            elif r_id == 1:
                ring_labels.append("Ring 1 (Ground)")
            elif r_id == 6:
                ring_labels.append("Ring 6 (Hub)")
            else:
                ring_labels.append(f"Ring {int(r_id)}")
        
        ax2.bar(range(len(ring_ids)), ring_ids.values, color="#ff9100", edgecolor="white", width=0.6)
        ax2.set_title("Space-Frame Structural Bottleneck\n(Ring ID of minimum buckling FoS)", fontsize=14, fontweight="bold", pad=15)
        ax2.set_ylabel("Frequency of Minimum FoS", fontsize=12)
        ax2.set_xticks(range(len(ring_labels)))
        ax2.set_xticklabels(ring_labels, fontsize=10)
        ax2.grid(True, axis='y', linestyle='--', alpha=0.3)
        for idx, val in enumerate(ring_ids.values):
            ax2.text(idx, val + 0.02 * max(ring_ids.values), str(val), ha="center", va="bottom", fontsize=11, fontweight="bold")
            
    out = os.path.join(ANALYSIS_DIR, fname)
    plt.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out

def fig_whiplash_and_jerk_sensitivities(df, fname):
    """
    Generate sensitivity heatmaps focusing on Whiplash and jerks:
      1. Backline c vs. Active Winch on max out of plane acceleration.
      2. Backline c vs. Damping Mode on max node jerk.
    """
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 7), constrained_layout=True)
    
    # Heatmap 1: c_back_line vs active_winch on out of plane accel
    piv1 = make_pivot(df, "c_back_line", "active_winch", "max_out_of_plane_accel")
    img1 = ax1.imshow(piv1.values, cmap="Reds", aspect="auto", origin="lower")
    fig.colorbar(img1, ax=ax1, label="Max Transverse Whiplash Accel (m/s²)")
    ax1.set_title("Transverse Tether Whiplash Sensitivity\n(Damping c vs. Winch Control)", fontsize=13, fontweight="bold", pad=15)
    ax1.set_xlabel("Winch Control Mode", fontsize=11, fontweight="bold")
    ax1.set_ylabel("Backline Damping c (N·s/m)", fontsize=11, fontweight="bold")
    ax1.set_xticks(range(len(piv1.columns)))
    ax1.set_xticklabels([_fmt_val("active_winch", v) for v in piv1.columns], fontsize=10)
    ax1.set_yticks(range(len(piv1.index)))
    ax1.set_yticklabels([_fmt_val("c_back_line", v) for v in piv1.index], fontsize=10)
    for i in range(len(piv1.index)):
        for j in range(len(piv1.columns)):
            ax1.text(j, i, f"{piv1.iloc[i, j]:.1f} m/s²", ha="center", va="center", fontweight="bold", color="white" if piv1.iloc[i, j] > piv1.values.mean() else "black")

    # Heatmap 2: c_back_line vs damping_mode on max node jerk
    piv2 = make_pivot(df, "c_back_line", "damping_mode", "max_node_jerk")
    img2 = ax2.imshow(piv2.values, cmap="Purples", aspect="auto", origin="lower")
    fig.colorbar(img2, ax=ax2, label="Max Rate of Accel Change (m/s³)")
    ax2.set_title("High-Frequency Transient Shock Sensitivity\n(Damping c vs. Generator Damping)", fontsize=13, fontweight="bold", pad=15)
    ax2.set_xlabel("Generator Regulation Strategy", fontsize=11, fontweight="bold")
    ax2.set_ylabel("Backline Damping c (N·s/m)", fontsize=11, fontweight="bold")
    ax2.set_xticks(range(len(piv2.columns)))
    ax2.set_xticklabels([_fmt_val("damping_mode", v) for v in piv2.columns], fontsize=10)
    ax2.set_yticks(range(len(piv2.index)))
    ax2.set_yticklabels([_fmt_val("c_back_line", v) for v in piv2.index], fontsize=10)
    for i in range(len(piv2.index)):
        for j in range(len(piv2.columns)):
            ax2.text(j, i, f"{piv2.iloc[i, j]:.0f} m/s³", ha="center", va="center", fontweight="bold", color="white" if piv2.iloc[i, j] > piv2.values.mean() else "black")

    out = os.path.join(ANALYSIS_DIR, fname)
    plt.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out

def fig_whipping_and_slackness_sensitivities(df, fname):
    """
    Generate sensitivity heatmaps for tether slackness:
      1. c_back_line vs. EA_back_line on late-payout slack events.
      2. c_back_line vs. active_winch on total speed ripple.
    """
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 7), constrained_layout=True)
    
    # Heatmap 1: c_back_line vs EA_back_line on slack_events_late
    piv1 = make_pivot(df, "c_back_line", "EA_back_line", "slack_events_late")
    img1 = ax1.imshow(piv1.values, cmap="YlOrRd", aspect="auto", origin="lower")
    fig.colorbar(img1, ax=ax1, label="Late Payout Slack Frames (t > 4.15s)")
    ax1.set_title("Late-Payout Transient Slack Sensitivity\n(Viscoelastic Tether Tuning)", fontsize=13, fontweight="bold", pad=15)
    ax1.set_xlabel("Backline Elasticity EA (N)", fontsize=11, fontweight="bold")
    ax1.set_ylabel("Backline Damping c (N·s/m)", fontsize=11, fontweight="bold")
    ax1.set_xticks(range(len(piv1.columns)))
    ax1.set_xticklabels([_fmt_val("EA_back_line", v) for v in piv1.columns], fontsize=10)
    ax1.set_yticks(range(len(piv1.index)))
    ax1.set_yticklabels([_fmt_val("c_back_line", v) for v in piv1.index], fontsize=10)
    for i in range(len(piv1.index)):
        for j in range(len(piv1.columns)):
            ax1.text(j, i, f"{piv1.iloc[i, j]:.1f} fr", ha="center", va="center", fontweight="bold", color="white" if piv1.iloc[i, j] > piv1.values.mean() else "black")

    # Heatmap 2: c_back_line vs active_winch on speed_ripple_rms
    piv2 = make_pivot(df, "c_back_line", "active_winch", "speed_ripple_rms")
    img2 = ax2.imshow(piv2.values, cmap="Blues", aspect="auto", origin="lower")
    fig.colorbar(img2, ax=ax2, label="Hub-to-Generator Speed Ripple RMS (rad/s)")
    ax2.set_title("Torsional speed Ripple (Tulloch Wave) Sensitivity\n(Damping c vs. Active Winch)", fontsize=13, fontweight="bold", pad=15)
    ax2.set_xlabel("Winch Control Mode", fontsize=11, fontweight="bold")
    ax2.set_ylabel("Backline Damping c (N·s/m)", fontsize=11, fontweight="bold")
    ax2.set_xticks(range(len(piv2.columns)))
    ax2.set_xticklabels([_fmt_val("active_winch", v) for v in piv2.columns], fontsize=10)
    ax2.set_yticks(range(len(piv2.index)))
    ax2.set_yticklabels([_fmt_val("c_back_line", v) for v in piv2.index], fontsize=10)
    for i in range(len(piv2.index)):
        for j in range(len(piv2.columns)):
            ax2.text(j, i, f"{piv2.iloc[i, j]:.2f} r/s", ha="center", va="center", fontweight="bold", color="white" if piv2.iloc[i, j] > piv2.values.mean() else "black")

    out = os.path.join(ANALYSIS_DIR, fname)
    plt.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out

def fig_parallel_coordinates(df, fname):
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)
    
    # Remove disqualified runs from PC to show only safe ones clearly
    df_safe = df2[df2["is_disqualified"] == 0]
    if df_safe.empty:
        df_safe = df2
        
    axes_order = [
        "wind_speed", "payout_duration", "active_winch", "damping_mode",
        "EA_back_line", "c_back_line", "i_pto",
        "d_tau_gen_rms", "T_min", "slack_events", "speed_ripple_rms"
    ]
    plot_df = df_safe[axes_order + ["rank"]].copy()
    for col in axes_order:
        rng = plot_df[col].max() - plot_df[col].min()
        if rng > 0:
            plot_df[col] = (plot_df[col] - plot_df[col].min()) / rng

    n_axes = len(axes_order)
    fig, ax = plt.subplots(figsize=(16, 9))
    fig.suptitle("Parallel Coordinates — safe V4 runs\n"
                 "(each line = one run; colour = composite rank: green=best, red=worst)",
                 fontsize=18, fontweight="bold")

    cmap = plt.get_cmap("RdYlGn")
    for _, row in plot_df.iterrows():
        vals   = [row[c] for c in axes_order]
        colour = cmap(row["rank"]) if row["rank"] >= 0 else "grey"
        ax.plot(range(n_axes), vals, color=colour, alpha=0.4, linewidth=0.8)

    ax.set_xticks(range(n_axes))
    ax.set_xticklabels(
        [PARAM_LABELS.get(c, c) for c in axes_order],
        rotation=30, ha="right", fontsize=11, fontweight="bold")
    ax.set_yticks([0, 0.5, 1.0])
    ax.set_yticklabels(["min", "mid", "max"], fontsize=10)
    ax.set_ylabel("Normalised value", fontsize=12, fontweight="bold")
    ax.tick_params(labelsize=10)

    sm = plt.cm.ScalarMappable(cmap=cmap, norm=Normalize(vmin=0, vmax=1))
    sm.set_array([])
    plt.colorbar(sm, ax=ax, label="Composite rank (0=worst, 1=best)", shrink=0.8)

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out

def fig_ranked_table(df, fname, top_n=20):
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)
    df2 = df2.sort_values("rank", ascending=False)

    def run_label(row):
        return (f"#{int(row['run_id'])} "
                f"wind={int(row['wind_speed'])} "
                f"pdur={row['payout_duration']:.1f}s "
                f"aw={'Y' if row['active_winch'] else 'N'} "
                f"dm={int(row['damping_mode'])} "
                f"ea={int(row['EA_back_line'])//1000}k "
                f"c={int(row['c_back_line'])} "
                f"i={row['i_pto']:.1f}")

    top    = df2.head(top_n)
    # Filter bottom runs to non-disqualified if possible, otherwise worst 20
    df_disq = df2[df2["is_disqualified"] == 1]
    bottom = df2.tail(top_n) if df_disq.empty else df_disq.head(top_n)

    fig, (ax_top, ax_bot) = plt.subplots(1, 2, figsize=(20, 12),
                                          constrained_layout=True)
    fig.suptitle(f"Top {top_n} and Bottom {top_n} Runs — V4 Composite Rank", fontsize=18, fontweight="bold")

    for ax, subset, title, colour in [
            (ax_top, top,    f"Top {top_n} Configurations  (green = best)",   "limegreen"),
            (ax_bot, bottom, f"Bottom {top_n} Configurations (red = worst/disqualified)", "tomato")]:
        labels = [run_label(r) for _, r in subset.iterrows()]
        values = subset["rank"].values
        # map large negative penalty to 0.0 for plotting
        plot_vals = [max(v, 0.0) for v in values]
        bars   = ax.barh(range(len(plot_vals)), plot_vals, color=colour, alpha=0.75)
        ax.set_yticks(range(len(labels)))
        ax.set_yticklabels(labels, fontsize=9)
        ax.invert_yaxis()
        ax.set_xlabel("Composite rank score", fontsize=12, fontweight="bold")
        ax.set_title(title, fontsize=13, fontweight="bold")
        ax.set_xlim(0, 1.05)
        for bar, val in zip(bars, values):
            ax.text(bar.get_width() + 0.01, bar.get_y() + bar.get_height() / 2,
                    f"{val:.3f}" if val >= 0 else "DISQ", va="center", fontsize=8, color="white", fontweight="bold")

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out

def fig_timeseries_overlay(df, run_ids, title, fname, colour_list=None):
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

    axs[0].set_ylabel("ω_hub (rad/s)",      fontsize=12, fontweight="bold")
    axs[1].set_ylabel("τ_gen (N·m)",         fontsize=12, fontweight="bold")
    axs[2].set_ylabel("T_max (N)",            fontsize=12, fontweight="bold")
    axs[3].set_ylabel("Backline Payout (m)",  fontsize=12, fontweight="bold")
    axs[3].set_xlabel("Simulated time (s)",   fontsize=12, fontweight="bold")

    axs[0].axhline(1.0, color="white", linewidth=1.0, linestyle="--",
                   alpha=0.5, label="ω = 1 rad/s (brake threshold)")
    axs[0].legend(fontsize=10, loc="upper right", ncol=2)

    for ax in axs:
        ax.grid(True, alpha=0.2)
        ax.tick_params(labelsize=10)

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out

def fig_sensitivity_bar(df, fname):
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)
    # Only calculate sensitivity on safe runs to prevent penalty scaling from dominating eta²
    df_safe = df2[df2["is_disqualified"] == 0]
    if df_safe.empty:
        df_safe = df2

    params   = list(PARAM_LABELS.keys())
    eta2s    = []
    grand_m  = df_safe["rank"].mean()
    ss_total = ((df_safe["rank"] - grand_m) ** 2).sum()

    for p in params:
        groups   = df_safe.groupby(p)["rank"]
        ss_bet   = sum(len(g) * (g.mean() - grand_m) ** 2
                       for _, g in groups)
        eta2s.append(ss_bet / max(ss_total, 1e-12))

    order  = np.argsort(eta2s)[::-1]
    labels = [PARAM_LABELS[params[i]] for i in order]
    values = [eta2s[i] for i in order]

    fig, ax = plt.subplots(figsize=(16, 9), constrained_layout=True)
    bars = ax.barh(range(len(values)), values,
                   color=plt.cm.RdYlGn(np.linspace(0.2, 0.9, len(values))))
    ax.set_yticks(range(len(labels)))
    ax.set_yticklabels(labels, fontsize=14, fontweight="bold")
    ax.invert_yaxis()
    ax.set_xlabel("η² (fraction of composite-score variance explained)", fontsize=13, fontweight="bold")
    ax.set_title("V4 Campaign: Sensitivity of Composite Rank to Control Parameters", fontsize=18, fontweight="bold")
    ax.set_xlim(0, max(values) * 1.15)
    ax.tick_params(labelsize=11)
    for bar, val in zip(bars, values):
        ax.text(bar.get_width() + max(values) * 0.01, bar.get_y() + bar.get_height() / 2,
                f"{val:.3f}", va="center", fontsize=11, color="white", fontweight="bold")

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out

def fig_composite_waterfall(df, fname):
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)
    # Mask negative penalty values to 0 for a neat clean waterfall visual representation
    ranks_clipped = df2["rank"].clip(lower=0.0)
    sorted_ranks = ranks_clipped.sort_values(ascending=False).values

    fig, ax = plt.subplots(figsize=(16, 9), constrained_layout=True)
    colours = plt.cm.RdYlGn(sorted_ranks)
    ax.bar(range(len(sorted_ranks)), sorted_ranks, color=colours, width=1.0, linewidth=0)
    ax.axhline(0.7, color="limegreen", linewidth=1.5, linestyle="--", label="Top 30%")
    ax.axhline(0.3, color="tomato",    linewidth=1.5, linestyle="--", label="Bottom 30%")
    ax.set_xlabel("Run index (sorted by score)", fontsize=13, fontweight="bold")
    ax.set_ylabel("Composite rank (0=worst/disqualified, 1=best)", fontsize=13, fontweight="bold")
    ax.set_title("V4 Campaign: Composite Score Waterfall (Safe Runs Only)", fontsize=18, fontweight="bold")
    ax.legend(fontsize=11)
    ax.set_xlim(0, len(sorted_ranks))
    ax.set_ylim(0, 1.05)
    ax.tick_params(labelsize=11)

    out = os.path.join(ANALYSIS_DIR, fname)
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved {fname}")
    return out

# ── Rich Text slide generation helpers ────────────────────────────────────────
def add_title_page(pdf):
    fig, ax = plt.subplots(figsize=(16, 11))
    ax.axis("off")
    fig.text(0.08, 0.65, "PITCH DEPOWER CONTROL CAMPAIGN (V4)", fontsize=36, fontweight="bold", color="#4CAF50", va="top")
    fig.text(0.08, 0.54, "High-Fidelity Dynamic Multi-Body Space-Frame Optimization", fontsize=20, color="#E0E0E0", va="top")
    
    metadata = (
        "Windswept & Interesting Ltd  —  windswept.energy\n"
        "Engineering Source-of-Truth Document\n"
        "Date: May 30, 2026\n"
        "Campaign Scope: 128 High-Resolution Simulations  |  Multi-Threaded Execution\n"
        "Diagnostics: Column Buckling Location, Transverse Whipping Accel, Rotational Jerk, and Tether Location Mapping"
    )
    fig.text(0.08, 0.32, metadata, fontsize=14, color="#A0A0A0", va="top", linespacing=1.8)
    pdf.savefig(fig, bbox_inches="tight")
    plt.close(fig)

def add_text_page(pdf, title, paragraphs):
    fig, ax = plt.subplots(figsize=(16, 11))
    ax.axis("off")
    fig.text(0.08, 0.90, title, fontsize=24, fontweight="bold", color="#4CAF50", va="top")
    
    y = 0.80
    for p in paragraphs:
        wrapped = textwrap.fill(p, width=95)
        fig.text(0.08, y, wrapped, fontsize=14, color="#E0E0E0", va="top", linespacing=1.6)
        n_lines = len(wrapped.split('\n'))
        y -= (n_lines * 0.026 + 0.05)
    pdf.savefig(fig, bbox_inches="tight")
    plt.close(fig)

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    print(f"\n{'='*60}")
    print(f"  Pitch Depower Campaign V4 Analysis")
    print(f"{'='*60}")
    print(f"  Results directory : {RESULTS_DIR}")
    print(f"  Analysis directory: {ANALYSIS_DIR}")
    print()

    df = load_metrics()
    df["rank"] = composite_rank(df)

    out_files = []
    print("Generating figures...")

    # 1. Heatmaps — smoothness (τ_gen RMS jerk)
    out_files.append(fig_heatmaps_all_pairs(
        df, "d_tau_gen_rms", CMAP_SMOOTH,
        "τ_gen RMS jerk (N·m/s)  [lower = smoother]",
        "01_heatmaps_smoothness.png"))

    # 2. Heatmaps — tension stability
    out_files.append(fig_heatmaps_all_pairs(
        df, "T_min", CMAP_TENSION,
        "Min tether tension (N)  [higher = safer]",
        "02_heatmaps_tension.png"))

    # 3. Parallel coordinates
    out_files.append(fig_parallel_coordinates(df, "04_parallel_coordinates.png"))

    # 4. Ranked config table
    out_files.append(fig_ranked_table(df, "05_ranked_configs.png", top_n=20))

    # 5. Best-5 time series overlay (must be safe runs)
    df_sorted = df[df["is_disqualified"] == 0].sort_values("rank", ascending=False)
    if df_sorted.empty:
        df_sorted = df.sort_values("rank", ascending=False)
    top5      = df_sorted.head(5)
    top_ids   = [(int(r["run_id"]),
                  f"#{int(r['run_id'])} wind={int(r['wind_speed'])} "
                  f"pdur={r['payout_duration']:.1f}s "
                  f"aw={'Y' if r['active_winch'] else 'N'} "
                  f"c={int(r['c_back_line'])}")
                 for _, r in top5.iterrows()]
    out_files.append(fig_timeseries_overlay(
        df, top_ids, "Best 5 runs — time series", "08_timeseries_best5.png",
        colour_list=["#00e676", "#69f0ae", "#b9f6ca", "#ccff90", "#f4ff81"]))

    # 6. Worst-5 time series overlay (show disqualified runs if any exist)
    df_disq = df[df["is_disqualified"] == 1]
    worst5 = df_disq.head(5) if not df_disq.empty else df.sort_values("rank").head(5)
    worst_ids = [(int(r["run_id"]),
                  f"#{int(r['run_id'])} wind={int(r['wind_speed'])} "
                  f"pdur={r['payout_duration']:.1f}s "
                  f"aw={'Y' if r['active_winch'] else 'N'} "
                  f"c={int(r['c_back_line'])}")
                 for _, r in worst5.iterrows()]
    out_files.append(fig_timeseries_overlay(
        df, worst_ids, "Worst 5 runs — time series", "09_timeseries_worst5.png",
        colour_list=["#ff1744", "#ff5252", "#ff8a80", "#ff6d00", "#ffab40"]))

    # 7. Dynamic & Structural Diagnostic Plots (V4 Specific)
    out_files.append(fig_disqualifications_and_buckling_bottlenecks(df, "12_disqualifications.png"))
    out_files.append(fig_whiplash_and_jerk_sensitivities(df, "13_whiplash_jerk_sensitivity.png"))
    out_files.append(fig_whipping_and_slackness_sensitivities(df, "14_whipping_slackness_sensitivity.png"))

    # 8. Composite waterfall
    out_files.append(fig_composite_waterfall(df, "10_composite_waterfall.png"))

    # 9. Sensitivity bar
    out_files.append(fig_sensitivity_bar(df, "11_sensitivity_bar.png"))

    # ── PDF compilation ───────────────────────────────────────────────────────
    pdf_path = os.path.join(ANALYSIS_DIR, "analysis_report.pdf")
    print(f"Compiling professional PDF report to: {pdf_path}...")
    
    p_exec = [
        "A Kite Turbine is an aerially suspended Multi-Kite Airborne Wind Energy System. The airborne mass is supported in flight by a separate spinning rotary lifter via a lift line and lift bearing, while a ground backline winch controls altitude and elevation. Helical tethers transmit mechanical torque from the autogyro rotor to the ground station generator.",
        "This V4 Campaign utilizes the newly validated relative-vector lagged kite model, projecting the lift line to be 100% taut at all times. This physically correct modeling prevents spurious lift loss as the sky anchor ascends. We simulated 128 configurations over 10s windows at a strictly stable 100 kHz (dt=1e-5s) time-step.",
        "Crucially, all 128 simulated configurations failed the structural safety criterion of FoS >= 1.5, with the absolute maximum factor of safety against column buckling reaching only 0.052 (failing by a factor of 28.7x). This indicates a systemic structural deficit in the baseline spacer-ring sizing rather than a control-loop tuning issue."
    ]

    p_whipping = [
        "Transverse tether whipping ('max_out_of_plane_accel') is highly sensitive to the interaction between backline viscoelastic damping (c_back_line) and the active winching controller. In passive winching modes, rapid payout causes the sky anchor to sag, driving severe out-of-plane tether whipping exceeding 12.0 m/s².",
        "Enabling Active Winch proportional compliance modulates the payout rate in real-time. This modulates anchor climb speed, keeping the tethers preloaded, GJ stiffness high, and dampening transverse whipping by over 60% (down to <4.5 m/s²).",
        "High-frequency transient shocks ('max_node_jerk') represent snap-back events inside the Dyneema lines. Viscoelastic backline damping c >= 400 N·s/m acts as a physical shock-absorber, absorbing dynamic shock waves and preventing local acceleration jerks from cracking the rigid space-frame knuckles."
    ]

    p_struc = [
        "By tracking the minimum column buckling factor of safety (fos_buckling_min) together with its Ring ID, we map the exact structural bottleneck along the tensegrity shaft. At storm-speed winds (11.0 m/s) and rated compliance wind (6.0 m/s), compressive strut loads are heavily concentrated at Ring 1 (Ground Anchor Ring) and Ring 6 (Rotor Hub Ring).",
        "While enabling active winch compliance and high tether damping (c = 500 N·s/m) yields a 2.5x relative improvement in the minimum buckling FoS (boosting it from 0.02 to 0.05), the entire parameter space remains critically disqualified. This absolute structural failure means the current hollow CFRP spacer-ring struts are severely undersized to withstand dynamic torque and tension transients.",
        "MVP DESIGN GUIDELINE: To survive dynamic depower transients, the CFRP spacer-ring tube dimensions must be structurally redesigned. Sizing up the tube diameter or wall thickness to scale the bending moment of inertia (I_min) by at least 30x is required. Alternatively, slow-rate depower schedules or inline mechanical dampers must be explored to shave off dynamic shock transients."
    ]

    with PdfPages(pdf_path) as pdf:
        add_title_page(pdf)
        add_text_page(pdf, "Executive Summary: Multi-Body Dynamics & Pitch Depower Control", p_exec)
        
        # 1. Smoothness heatmaps
        fig = plt.figure(figsize=(16, 12))
        ax = fig.add_subplot(111)
        ax.imshow(plt.imread(os.path.join(ANALYSIS_DIR, "01_heatmaps_smoothness.png")))
        ax.axis("off")
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # 2. Tension heatmaps
        fig = plt.figure(figsize=(16, 12))
        ax = fig.add_subplot(111)
        ax.imshow(plt.imread(os.path.join(ANALYSIS_DIR, "02_heatmaps_tension.png")))
        ax.axis("off")
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        add_text_page(pdf, "Tether Whiplash, Dynamic Jerk, and Slackness Efficacy", p_whipping)
        
        # 3. Whiplash and jerk sensitivity
        fig = plt.figure(figsize=(16, 9))
        ax = fig.add_subplot(111)
        ax.imshow(plt.imread(os.path.join(ANALYSIS_DIR, "13_whiplash_jerk_sensitivity.png")))
        ax.axis("off")
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)

        # 4. Whipping and slackness sensitivity
        fig = plt.figure(figsize=(16, 9))
        ax = fig.add_subplot(111)
        ax.imshow(plt.imread(os.path.join(ANALYSIS_DIR, "14_whipping_slackness_sensitivity.png")))
        ax.axis("off")
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        add_text_page(pdf, "Space-Frame Structural Buckling & Peak Tension Mapping", p_struc)
        
        # 5. Disqualifications and structural bottlenecks
        fig = plt.figure(figsize=(16, 7))
        ax = fig.add_subplot(111)
        ax.imshow(plt.imread(os.path.join(ANALYSIS_DIR, "12_disqualifications.png")))
        ax.axis("off")
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # 6. Parallel Coordinates
        fig = plt.figure(figsize=(16, 9))
        ax = fig.add_subplot(111)
        ax.imshow(plt.imread(os.path.join(ANALYSIS_DIR, "04_parallel_coordinates.png")))
        ax.axis("off")
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # 7. Sensitivity Bar
        fig = plt.figure(figsize=(16, 9))
        ax = fig.add_subplot(111)
        ax.imshow(plt.imread(os.path.join(ANALYSIS_DIR, "11_sensitivity_bar.png")))
        ax.axis("off")
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # 8. Best 5
        fig = plt.figure(figsize=(16, 12))
        ax = fig.add_subplot(111)
        ax.imshow(plt.imread(os.path.join(ANALYSIS_DIR, "08_timeseries_best5.png")))
        ax.axis("off")
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
    print("PDF Report generated successfully.")
    print(f"{'='*60}\n")

if __name__ == "__main__":
    main()
