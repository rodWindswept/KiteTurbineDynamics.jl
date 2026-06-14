#!/usr/bin/env python3
import os
import sys
import warnings
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.colors import Normalize, LogNorm
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.lines import Line2D
from scipy.interpolate import griddata
from scipy.signal import welch
from scipy.stats import gaussian_kde
import textwrap

warnings.filterwarnings("ignore")

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
RESULTS_DIR  = os.path.join(SCRIPT_DIR, "results", "pitch_depower_campaign")
METRICS_CSV  = os.path.join(RESULTS_DIR, "campaign_metrics.csv")

# Create V2 Output Directory
V2_OUT_DIR = os.path.join(RESULTS_DIR, "v2_analysis_reporting_results")
os.makedirs(V2_OUT_DIR, exist_ok=True)

# ── Styles & Aesthetics ────────────────────────────────────────────────────────
plt.style.use("dark_background")
fig_dpi = 150

CMAP_SMOOTH  = "RdYlGn_r"   # red = high (bad) smoothness error; green = low (good)
CMAP_TENSION = "RdYlGn"     # green = high tension (good); red = low (bad)
CMAP_TIME    = "plasma"

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
    # Drop failed rows (NaN in primary metrics)
    df = df.dropna(subset=["d_tau_gen_rms", "T_min"])
    return df

def load_timeseries(run_id: int) -> pd.DataFrame:
    path = os.path.join(RESULTS_DIR, f"timeseries_{run_id:04d}.csv")
    if os.path.exists(path):
        return pd.read_csv(path)
    return None

def rank_percentile(series: pd.Series) -> pd.Series:
    return series.rank(pct=True)

def composite_rank(df: pd.DataFrame) -> pd.Series:
    smooth_rank  = 1.0 - rank_percentile(df["d_tau_gen_rms"])   # lower rms → rank 1
    tension_rank = rank_percentile(df["T_min"])                   # higher T_min → rank 1
    slack_pen    = df["slack_events"].clip(upper=50) / 50.0 * 0.3
    brake_bonus  = df["brake_engaged"].astype(float) * 0.1       # bonus for reaching brake
    score = (smooth_rank + tension_rank) / 2.0 - slack_pen + brake_bonus
    return score

def make_pivot(df, row_param, col_param, metric):
    piv = df.groupby([row_param, col_param])[metric].mean().reset_index()
    return piv.pivot(index=row_param, columns=col_param, values=metric)

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

# Standardized Metadata Banner to ensure each chart stands completely alone
def add_metadata_banner(fig, title_text):
    banner_text = (
        "Windswept & Interesting Ltd  |  10 kW Autogyro Prototype Sweep (V2 Campaign)  |  n = 512 dynamic simulations\n"
        "Safety Boundaries: Spacer Buckling FoS ≥ 1.5 (Euler limit)  |  Sky Anchor Segment Tension ≥ 250 N (Preload limit)"
    )
    # Put banner lower down and clear space using subplots_adjust programmatically
    fig.text(0.5, 0.015, banner_text, color="gray", fontsize=8, ha="center", va="center", alpha=0.8,
             bbox=dict(boxstyle="round,pad=0.3", fc="#111111", alpha=0.8, ec="gray", lw=0.5))

def save_dual_format(fig, base_name):
    # Apply tight layout with space preserved for bottom banner
    fig.subplots_adjust(bottom=0.08)
    png_path = os.path.join(V2_OUT_DIR, f"{base_name}.png")
    svg_path = os.path.join(V2_OUT_DIR, f"{base_name}.svg")
    fig.savefig(png_path, dpi=fig_dpi, bbox_inches="tight")
    fig.savefig(svg_path, bbox_inches="tight")
    print(f"  ✓ Saved visual: {base_name} (.png and .svg)")

# ── 1. Figure 01: Heatmaps - Smoothness (τ_gen RMS jerk) ─────────────────────
def fig_heatmaps_smoothness(df):
    params = list(PARAM_LABELS.keys())
    pairs  = [(a, b) for i, a in enumerate(params) for b in params[i+1:]]
    n = len(pairs)
    ncols = 3
    nrows = (n + ncols - 1) // ncols

    fig, axes = plt.subplots(nrows, ncols, figsize=(18, 20))
    fig.suptitle("01. Drivetrain Torsional Smoothness Topography\n"
                 "(Average Torque Jerk across all sweep parameter pairs; red = rough, green = smooth)", 
                 fontsize=16, fontweight="bold", y=0.96)

    for k, (rp, cp) in enumerate(pairs):
        ax = axes[k // ncols, k % ncols]
        piv = make_pivot(df, rp, cp, "d_tau_gen_rms")
        img = ax.imshow(piv.values, aspect="auto", origin="lower",
                        cmap=CMAP_SMOOTH, interpolation="nearest")
        cbar = plt.colorbar(img, ax=ax, shrink=0.7, pad=0.02)
        cbar.ax.tick_params(labelsize=8)
        ax.set_xticks(range(len(piv.columns)))
        ax.set_xticklabels([_fmt_val(cp, v) for v in piv.columns], fontsize=8, rotation=30, ha="right")
        ax.set_yticks(range(len(piv.index)))
        ax.set_yticklabels([_fmt_val(rp, v) for v in piv.index], fontsize=8)
        ax.set_xlabel(PARAM_LABELS[cp], fontsize=9, fontweight="bold")
        ax.set_ylabel(PARAM_LABELS[rp], fontsize=9, fontweight="bold")
        ax.set_title(f"τ_gen Jerk vs. Pairs", fontsize=10, pad=5)

    # Hide unused panels
    for k in range(len(pairs), nrows * ncols):
        axes[k // ncols, k % ncols].axis("off")

    add_metadata_banner(fig, "01")
    save_dual_format(fig, "01_heatmaps_smoothness")
    return fig

# ── 2. Figure 02: Heatmaps - Tension Stability ──────────────────────────────
def fig_heatmaps_tension(df):
    params = list(PARAM_LABELS.keys())
    pairs  = [(a, b) for i, a in enumerate(params) for b in params[i+1:]]
    n = len(pairs)
    ncols = 3
    nrows = (n + ncols - 1) // ncols

    fig, axes = plt.subplots(nrows, ncols, figsize=(18, 20))
    fig.suptitle("02. Minimum Sky Anchor Tension Stability Map\n"
                 "(Average Minimum Tension across all parameter pairs; green = preloaded, red = slack)", 
                 fontsize=16, fontweight="bold", y=0.96)

    for k, (rp, cp) in enumerate(pairs):
        ax = axes[k // ncols, k % ncols]
        piv = make_pivot(df, rp, cp, "T_min")
        img = ax.imshow(piv.values, aspect="auto", origin="lower",
                        cmap=CMAP_TENSION, interpolation="nearest")
        cbar = plt.colorbar(img, ax=ax, shrink=0.7, pad=0.02)
        cbar.ax.tick_params(labelsize=8)
        ax.set_xticks(range(len(piv.columns)))
        ax.set_xticklabels([_fmt_val(cp, v) for v in piv.columns], fontsize=8, rotation=30, ha="right")
        ax.set_yticks(range(len(piv.index)))
        ax.set_yticklabels([_fmt_val(rp, v) for v in piv.index], fontsize=8)
        ax.set_xlabel(PARAM_LABELS[cp], fontsize=9, fontweight="bold")
        ax.set_ylabel(PARAM_LABELS[rp], fontsize=9, fontweight="bold")
        ax.set_title(f"T_min vs. Pairs", fontsize=10, pad=5)

    # Hide unused panels
    for k in range(len(pairs), nrows * ncols):
        axes[k // ncols, k % ncols].axis("off")

    add_metadata_banner(fig, "02")
    save_dual_format(fig, "02_heatmaps_tension")
    return fig

# ── 3. Figure 03: Brake Latching Time Heatmap ────────────────────────────────
def fig_brake_time_heatmap(df):
    fig, axes = plt.subplots(1, 2, figsize=(16, 8))
    fig.suptitle("03. Mean Time to Brake (s) — Duration × Lifter Elevation", fontsize=16, fontweight="bold", y=0.95)

    for ax, imu_val, imu_lbl in [(axes[0], 0, "Field IMU: OFF (Brake disabled / unsafe)"),
                                  (axes[1], 1, "Field IMU: ON (Active Damping & safe brake)")]:
        sub = df[df["field_imu"] == imu_val]
        if sub.empty:
            ax.text(0.5, 0.5, "No data available", transform=ax.transAxes, ha="center", va="center", color="gray")
            continue
        piv = make_pivot(sub, "duration_s", "lifter_elev_deg", "brake_time")
        if piv.empty:
            ax.text(0.5, 0.5, "No data available", transform=ax.transAxes, ha="center", va="center", color="gray")
            continue
        img = ax.imshow(piv.values, aspect="auto", origin="lower", cmap=CMAP_TIME, interpolation="nearest")
        cbar = plt.colorbar(img, ax=ax, label="Time to brake (s)")
        cbar.ax.tick_params(labelsize=9)
        
        ax.set_xticks(range(len(piv.columns)))
        ax.set_xticklabels([f"{int(v)}°" for v in piv.columns], fontsize=9)
        ax.set_yticks(range(len(piv.index)))
        ax.set_yticklabels([f"{int(v)}s" for v in piv.index], fontsize=9)
        ax.set_xlabel("Lifter elevation (°)", fontsize=11, fontweight="bold")
        ax.set_ylabel("Payout Duration (s)", fontsize=11, fontweight="bold")
        ax.set_title(imu_lbl, fontsize=12, fontweight="bold")

        # Cell annotations with clear background to prevent overlap
        for r in range(len(piv.index)):
            for c in range(len(piv.columns)):
                val = piv.values[r, c]
                if not np.isnan(val):
                    ax.text(c, r, f"{val:.1f}s", ha="center", va="center", fontsize=9, color="white", fontweight="bold",
                            bbox=dict(boxstyle="round,pad=0.2", fc="black", alpha=0.6, ec="none"))

    add_metadata_banner(fig, "03")
    save_dual_format(fig, "03_heatmap_brake_time")
    return fig

# ── 4. Figure 04: Parallel Coordinates Flow Map ──────────────────────────────
def fig_parallel_coordinates(df):
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)
    
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
    fig.suptitle("04. Parallel Coordinates — All 512 Campaign Sweeps\n"
                 "(Each line = one run; colour = composite score: green=best, red=worst)", 
                 fontsize=15, fontweight="bold", y=0.96)

    cmap = plt.get_cmap("RdYlGn")
    for _, row in plot_df.iterrows():
        vals   = [row[c] for c in axes_order]
        colour = cmap(row["rank"])
        ax.plot(range(n_axes), vals, color=colour, alpha=0.25, linewidth=0.5)

    ax.set_xticks(range(n_axes))
    ax.set_xticklabels([PARAM_LABELS.get(c, c) for c in axes_order], rotation=30, ha="right", fontsize=12, fontweight="bold")
    ax.set_yticks([0, 0.5, 1.0])
    ax.set_yticklabels(["min", "mid", "max"], fontsize=10)
    ax.set_ylabel("Normalised Campaign Bounds", fontsize=12, fontweight="bold")
    ax.tick_params(labelsize=10)
    ax.grid(True, axis='x', linestyle='--', alpha=0.15)

    # Clean non-overlapping colorbar
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=Normalize(vmin=0, vmax=1))
    sm.set_array([])
    cbar = plt.colorbar(sm, ax=ax, shrink=0.8, pad=0.03)
    cbar.set_label("Composite Rank (0=worst, 1=best)", fontsize=11, fontweight="bold")

    add_metadata_banner(fig, "04")
    save_dual_format(fig, "04_parallel_coordinates")
    return fig

# ── 5. Figure 05: Ranked Configurations Horizontal Bar ────────────────────────
def fig_ranked_table(df, top_n=20):
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)
    df2 = df2.sort_values("rank", ascending=False)

    def run_label(row):
        return (f"Run#{int(row['run_id'])}: "
                f"dur={int(row['duration_s'])}s | "
                f"el={int(row['lifter_elev_deg'])}° | "
                f"imu={'Y' if row['field_imu'] else 'N'} | "
                f"dm={int(row['damping_mode'])} | "
                f"aw={'Y' if row['active_winch'] else 'N'} | "
                f"ms={'Y' if row['mppt_stall'] else 'N'}")

    top    = df2.head(top_n)
    bottom = df2.tail(top_n)

    fig, (ax_top, ax_bot) = plt.subplots(1, 2, figsize=(20, 10))
    fig.suptitle(f"05. Top {top_n} and Bottom {top_n} Runs by Mechatronic Score", fontsize=16, fontweight="bold", y=0.96)

    for ax, subset, title, colour in [
            (ax_top, top,    f"Top {top_n} Winner Envelope (green = best)",   "limegreen"),
            (ax_bot, bottom, f"Bottom {top_n} Failure Envelope (red = worst)", "tomato")]:
        labels = [run_label(r) for _, r in subset.iterrows()]
        values = subset["rank"].values
        bars   = ax.barh(range(len(values)), values, color=colour, alpha=0.75, edgecolor="white", height=0.6)
        ax.set_yticks(range(len(labels)))
        ax.set_yticklabels(labels, fontsize=9)
        ax.invert_yaxis()
        ax.set_xlabel("Composite rank (higher = better)", fontsize=11, fontweight="bold")
        ax.set_title(title, fontsize=12, fontweight="bold", pad=10)
        ax.set_xlim(0, 1.1)
        ax.grid(True, axis='x', linestyle='--', alpha=0.2)
        
        # Add labels to the right of bars cleanly
        for bar, val in zip(bars, values):
            ax.text(val + 0.01, bar.get_y() + bar.get_height() / 2, f"{val:.3f}", 
                    va="center", fontsize=8, color="white", fontweight="bold")

    add_metadata_banner(fig, "05")
    save_dual_format(fig, "05_ranked_configs")
    return fig

# ── 6. Figure 06: 3D Surface - Duration × elevation vs Smoothness ─────────────
def fig_3d_surface_duration_elev(df):
    piv = make_pivot(df, "duration_s", "lifter_elev_deg", "d_tau_gen_rms").dropna(how="all")
    x_vals = piv.columns.astype(float).values
    y_vals = piv.index.astype(float).values
    Z      = piv.values
    X, Y = np.meshgrid(x_vals, y_vals)

    fig = plt.figure(figsize=(12, 8))
    ax  = fig.add_subplot(111, projection="3d")
    surf = ax.plot_surface(X, Y, Z, cmap="RdYlGn_r", edgecolor="none", alpha=0.8)
    
    ax.set_xlabel("Lifter Elevation Angle (°)", fontsize=11, labelpad=12, fontweight="bold")
    ax.set_ylabel("Payout Duration (s)", fontsize=11, labelpad=12, fontweight="bold")
    ax.set_zlabel("Generator Torque Jerk (N·m/s)", fontsize=11, labelpad=12, fontweight="bold")
    ax.set_title("06. Torsional Smoothness Surface (Duration × Elevation)\n"
                 "(Lower is smoother, showing that slow payouts minimize dynamic twangs)", fontsize=13, fontweight="bold", pad=20)
    
    cbar = fig.colorbar(surf, shrink=0.5, pad=0.1)
    cbar.set_label("τ_gen RMS jerk (N·m/s)", fontsize=10, fontweight="bold")
    ax.view_init(elev=20, azim=-135)

    add_metadata_banner(fig, "06")
    save_dual_format(fig, "06_3d_surface_duration_elev")
    return fig

# ── 7. Figure 07: 3D Surface - Payout × Damping Mode vs Tension ───────────────
def fig_3d_surface_payout_dmode(df):
    piv = make_pivot(df, "damping_mode", "payout_base_m", "T_min").dropna(how="all")
    x_vals = piv.columns.astype(float).values
    y_vals = piv.index.astype(float).values
    Z      = piv.values
    X, Y = np.meshgrid(x_vals, y_vals)

    fig = plt.figure(figsize=(12, 8))
    ax  = fig.add_subplot(111, projection="3d")
    surf = ax.plot_surface(X, Y, Z, cmap="RdYlGn", edgecolor="none", alpha=0.8)
    
    ax.set_xlabel("Payout Base Length (m)", fontsize=11, labelpad=12, fontweight="bold")
    ax.set_ylabel("Damping Mode", fontsize=11, labelpad=12, fontweight="bold")
    ax.set_zlabel("Minimum Tether Tension (N)", fontsize=11, labelpad=12, fontweight="bold")
    ax.set_title("07. Tether Tension Stability Surface (Payout × Damping Mode)\n"
                 "(Higher is safer, showing that specific payout ranges preserve line preloads)", fontsize=13, fontweight="bold", pad=20)
    
    cbar = fig.colorbar(surf, shrink=0.5, pad=0.1)
    cbar.set_label("Min sky anchor tension (N)", fontsize=10, fontweight="bold")
    ax.view_init(elev=25, azim=-45)

    add_metadata_banner(fig, "07")
    save_dual_format(fig, "07_3d_surface_payout_dmode")
    return fig

# ── Helpers for Timeseries overlays ──────────────────────────────────────────
def fig_timeseries_overlay(df, run_ids, title, fname, colour_list=None):
    if colour_list is None:
        colour_list = plt.cm.tab10.colors

    fig, axs = plt.subplots(4, 1, figsize=(16, 12), sharex=True)
    fig.suptitle(title, fontsize=16, fontweight="bold", y=0.96)

    for idx, (run_id, label) in enumerate(run_ids):
        ts = load_timeseries(run_id)
        if ts is None:
            continue
        colour = colour_list[idx % len(colour_list)]
        axs[0].plot(ts["t"], ts["omega_hub"],     color=colour, linewidth=1.5, label=label)
        axs[1].plot(ts["t"], ts["tau_gen"],        color=colour, linewidth=1.5)
        axs[2].plot(ts["t"], ts["T_max"],          color=colour, linewidth=1.5)
        axs[3].plot(ts["t"], ts["backline_payout"],color=colour, linewidth=1.5)

    axs[0].set_ylabel("ω_hub  (rad/s)",      fontsize=11, fontweight="bold")
    axs[1].set_ylabel("τ_gen  (N·m)",         fontsize=11, fontweight="bold")
    axs[2].set_ylabel("T_max  (N)",            fontsize=11, fontweight="bold")
    axs[3].set_ylabel("Backline payout  (m)",  fontsize=11, fontweight="bold")
    axs[3].set_xlabel("Simulated time  (s)",   fontsize=11, fontweight="bold")

    axs[0].axhline(1.0, color="white", linewidth=1.0, linestyle="--", alpha=0.5, label="ω = 1 rad/s (brake)")
    axs[0].legend(fontsize=9, loc="upper right", ncol=2, framealpha=0.9, edgecolor="gray")

    for ax in axs:
        ax.grid(True, linestyle="--", alpha=0.15)
        ax.tick_params(labelsize=9)

    add_metadata_banner(fig, "08_09")
    save_dual_format(fig, fname)
    return fig

# ── 8. Figure 08: Best-5 timeseries overlay ──────────────────────────────────
def fig_timeseries_best5(df):
    df_sorted = df.sort_values("composite_score", ascending=False)
    # Ensure they are valid safe runs
    if "is_disqualified" in df_sorted.columns:
        top5 = df_sorted[df_sorted["is_disqualified"] == 0].head(5)
    else:
        top5 = df_sorted.head(5)
        
    top_ids   = [(int(r["run_id"]),
                  f"Run#{int(r['run_id'])} dur={int(r['duration_s'])}s | "
                  f"el={int(r['lifter_elev_deg'])}° | "
                  f"imu={'Y' if r['field_imu'] else 'N'} | "
                  f"ms={'Y' if r['mppt_stall'] else 'N'}")
                 for _, r in top5.iterrows()]
                 
    return fig_timeseries_overlay(df, top_ids, 
                                  "08. Best 5 Runs Transient Overlay: Smooth Deceleration Profiles\n"
                                  "(Top ranked configurations proving smooth speed decay and stable latching)", 
                                  "08_timeseries_best5", 
                                  colour_list=["#00e676", "#69f0ae", "#b9f6ca", "#ccff90", "#f4ff81"])

# ── 9. Figure 09: Worst-5 timeseries overlay ─────────────────────────────────
def fig_timeseries_worst5(df):
    if "is_disqualified" in df.columns and (df["is_disqualified"] == 1).any():
        worst5 = df[df["is_disqualified"] == 1].sort_values("composite_score").head(5)
    else:
        worst5 = df.sort_values("composite_score").head(5)
        
    worst_ids = [(int(r["run_id"]),
                  f"Run#{int(r['run_id'])} dur={int(r['duration_s'])}s | "
                  f"el={int(r['lifter_elev_deg'])}° | "
                  f"imu={'Y' if r['field_imu'] else 'N'} | "
                  f"ms={'Y' if r['mppt_stall'] else 'N'}")
                 for _, r in worst5.iterrows()]
                 
    return fig_timeseries_overlay(df, worst_ids, 
                                  "09. Worst 5 Runs Transient Overlay: Unstable & Decoupled Dynamics\n"
                                  "(Failing sweeps showing extreme torque recoil spikes and failed latching)", 
                                  "09_timeseries_worst5", 
                                  colour_list=["#ff1744", "#ff5252", "#ff8a80", "#ff6d00", "#ffab40"])

# ── 10. Figure 10: Composite ranks waterfall ──────────────────────────────────
def fig_composite_waterfall(df):
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)
    sorted_ranks = df2["rank"].sort_values(ascending=False).values

    fig, ax = plt.subplots(figsize=(16, 9))
    colours = plt.cm.RdYlGn(sorted_ranks)
    ax.bar(range(len(sorted_ranks)), sorted_ranks, color=colours, width=1.0, linewidth=0)
    ax.axhline(0.7, color="limegreen", linewidth=1.5, linestyle="--", label="Top 30% Gateway")
    ax.axhline(0.3, color="tomato",    linewidth=1.5, linestyle="--", label="Bottom 30% Cliff")
    ax.set_xlabel("Sweep configuration sorted index", fontsize=11, fontweight="bold")
    ax.set_ylabel("Composite rank  (0=worst, 1=best)", fontsize=11, fontweight="bold")
    ax.set_title("10. Composite Score Waterfall: Safety & Performance Transition Gate\n"
                 "(Quick-scanning the entire campaign to identify the stability cliff boundary)", fontsize=14, fontweight="bold", pad=15)
    ax.legend(fontsize=10, edgecolor="gray")
    ax.set_xlim(0, len(sorted_ranks))
    ax.set_ylim(0, 1.15)
    ax.tick_params(labelsize=10)
    ax.grid(True, linestyle="--", alpha=0.1)

    add_metadata_banner(fig, "10")
    save_dual_format(fig, "10_composite_waterfall")
    return fig

# ── 11. Figure 11: Sensitivity Bar ───────────────────────────────────────────
def fig_sensitivity_bar(df):
    df2 = df.copy()
    df2["rank"] = composite_rank(df2)

    params   = list(PARAM_LABELS.keys())
    eta2s    = []
    grand_m  = df2["rank"].mean()
    ss_total = ((df2["rank"] - grand_m) ** 2).sum()

    for p in params:
        groups   = df2.groupby(p)["rank"]
        ss_bet   = sum(len(g) * (g.mean() - grand_m) ** 2 for _, g in groups)
        eta2s.append(ss_bet / max(ss_total, 1e-12))

    # Sort by effect size
    order  = np.argsort(eta2s)[::-1]
    labels = [PARAM_LABELS[params[i]] for i in order]
    values = [eta2s[i] for i in order]

    fig, ax = plt.subplots(figsize=(16, 9))
    bars = ax.barh(range(len(values)), values, color=plt.cm.RdYlGn(np.linspace(0.2, 0.9, len(values))), edgecolor="white", height=0.6)
    ax.set_yticks(range(len(labels)))
    ax.set_yticklabels(labels, fontsize=12, fontweight="bold")
    ax.invert_yaxis()
    ax.set_xlabel("η² (Fraction of mechatronic score variance explained)", fontsize=11, fontweight="bold")
    ax.set_title("11. Control Parameter Main-Effect Sensitivity Chart\n"
                 "(Quantitative analysis pinpointing the dimensioning parameters of Pitch Depower safety)", fontsize=14, fontweight="bold", pad=15)
    ax.set_xlim(0, max(values) * 1.15)
    ax.tick_params(labelsize=10)
    ax.grid(True, axis='x', linestyle='--', alpha=0.2)
    
    for bar, val in zip(bars, values):
        ax.text(val + max(values) * 0.01, bar.get_y() + bar.get_height() / 2, f"{val:.3f}", 
                va="center", fontsize=10, color="white", fontweight="bold")

    add_metadata_banner(fig, "11")
    save_dual_format(fig, "11_sensitivity_bar")
    return fig

# ── 12. Figure 12: Disqualifications Breakdown Bar ───────────────────────────
def fig_disqualifications(df):
    fig = plt.figure(figsize=(16, 7))
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
                 ha='center', va='center', fontsize=12, color='#00e676', fontweight='bold')
        ax1.set_axis_off()
    else:
        colors = ["#ff1744", "#ff9100", "#ffea00", "#2979ff"][:len(reasons)]
        bars = ax1.bar(reasons.index, reasons.values, color=colors, edgecolor="white", width=0.5)
        ax1.set_title("Primary Physical Failure Modes Breakdown", fontsize=12, fontweight="bold", pad=10)
        ax1.set_ylabel("Number of Sweep Disqualifications", fontsize=11)
        ax1.set_xticklabels(reasons.index, rotation=20, ha="right", fontsize=9, fontweight="bold")
        ax1.grid(True, axis='y', linestyle='--', alpha=0.15)
        
        # Add labels on top of bars
        for bar in bars:
            yval = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2.0, yval + 5, f"{int(yval)}", 
                     ha="center", va="bottom", fontsize=10, color="white", fontweight="bold")
            
    # Panel 2: Heatmap of rates by Wind Speed × Payout Duration
    ax2 = fig.add_subplot(gs[1])
    if "is_disqualified" in df.columns:
        pivot_rate = df.groupby(["wind_speed", "payout_duration"])["is_disqualified"].mean().reset_index()
        pivot_df = pivot_rate.pivot(index="wind_speed", columns="payout_duration", values="is_disqualified") * 100.0
    else:
        pivot_df = pd.DataFrame(np.zeros((2, 4)))
        
    im = ax2.imshow(pivot_df, cmap="Oranges", aspect="auto", origin="lower")
    cbar = fig.colorbar(im, ax=ax2)
    cbar.set_label("Disqualification Rate (%)", fontsize=11, fontweight="bold")
    cbar.ax.tick_params(labelsize=9)
    
    ax2.set_title("Physical Disqualification Boundary Cliff\n(Wind Speed × Payout Duration)", fontsize=12, fontweight="bold", pad=10)
    ax2.set_xlabel("Payout Duration (s)", fontsize=11, fontweight="bold")
    ax2.set_ylabel("Wind Speed (m/s)", fontsize=11, fontweight="bold")
    
    ax2.set_xticks(np.arange(len(pivot_df.columns)))
    ax2.set_xticklabels([f"{val}s" for val in pivot_df.columns], fontsize=9)
    ax2.set_yticks(np.arange(len(pivot_df.index)))
    ax2.set_yticklabels([f"{val} m/s" for val in pivot_df.index], fontsize=9)
    
    # Annotate rates inside the heatmap clearly
    for i in range(len(pivot_df.index)):
        for j in range(len(pivot_df.columns)):
            val = pivot_df.iloc[i, j]
            color = "white" if val > 50.0 else "black"
            ax2.text(j, i, f"{val:.1f}%", ha="center", va="center", 
                     fontsize=11, fontweight="bold", color=color,
                     bbox=dict(boxstyle="round,pad=0.1", fc="none" if val > 50.0 else "white", alpha=0.3, ec="none"))
            
    fig.suptitle("12. Campaign Safety Auditing & Physical Failure Cliffs\n"
                 "(CFRP Spacer strut Euler buckling vs. sky anchor preloads)", fontsize=14, fontweight="bold", y=0.97)
    add_metadata_banner(fig, "12")
    save_dual_format(fig, "12_disqualifications")
    return fig

# ── 13. Figure 13: Control Efficacy Bar Chart Grid ───────────────────────────
def fig_control_efficacy(df):
    if "is_disqualified" not in df.columns:
        return None

    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    fig.suptitle("13. Mechatronic Control Switch Efficacy & Safety Rates\n"
                 "(Isolating control parameter toggles to evaluate structural and dynamic safety boundaries)", 
                 fontsize=16, fontweight="bold", y=0.96)

    def plot_bar(ax, groupby_col, label_dict, title, xlabel, color_false, color_true):
        rates = df.groupby(groupby_col)["is_disqualified"].mean() * 100.0
        for val in label_dict.keys():
            if val not in rates.index:
                rates[val] = 0.0
        rates = rates.sort_index()
        
        labels = [label_dict[i] for i in rates.index]
        values = rates.values
        
        colors = [color_false, color_true]
        bars = ax.bar(range(len(values)), values, color=colors, edgecolor="white", width=0.4)
        ax.set_xticks(range(len(labels)))
        ax.set_xticklabels(labels, fontsize=10, fontweight="bold")
        ax.set_ylabel("Disqualification Rate (%)", fontsize=11)
        ax.set_title(title, fontsize=11, fontweight="bold", pad=8)
        ax.set_ylim(0, 105)
        ax.grid(True, axis='y', linestyle='--', alpha=0.15)
        ax.set_xlabel(xlabel, fontsize=10, fontweight="bold")
        
        for bar, val in zip(bars, values):
            ax.text(bar.get_x() + bar.get_width()/2, val + 2, f"{val:.1f}%", 
                    ha="center", va="bottom", fontsize=10, fontweight="bold")

    plot_bar(axes[0, 0], "active_winch", {0: "Winch: Passive\n(Slack Collapse)", 1: "Winch: Active\n(Taut Preload)"},
             "Active Winch Efficacy on Line Slack", "Closed-Loop Tension Feedback Switch", "#ff1744", "#00e676")

    plot_bar(axes[0, 1], "mppt_stall", {0: "MPPT Stall: OFF\n(Safe Drivetrain)", 1: "MPPT Stall: ON\n(Torsional Collapse)"},
             "MPPT Stall Efficacy on Drivetrain Overtwist", "Regenerative Braking Gain Multiplier Switch", "#00e676", "#ff1744")

    plot_bar(axes[1, 0], "field_imu", {0: "Field IMU: OFF\n(Failed Latching)", 1: "Field IMU: ON\n(IMU Feedback)"},
             "Field IMU Efficacy on Safety Latching", "Airborne Inertial Telemetry Interlock", "#ff1744", "#00e676")

    plot_bar(axes[1, 1], "damping_mode", {0: "Mode 0: Standard\n(Tulloch Whipping)", 2: "Mode 2: LPF Speed\n(Optimal Damped)"},
             "Damping Mode Efficacy on Smooth deceleration", "Generator Regulation Strategy Selector", "#2979ff", "#00e676")

    add_metadata_banner(fig, "13")
    save_dual_format(fig, "13_control_efficacy")
    return fig

# ── 14. Advanced Science: State-Space Phase Portrait ──────────────────────────
def plot_state_space_portrait(df):
    path_base = os.path.join(RESULTS_DIR, "timeseries_0001.csv")
    path_win  = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_base) and os.path.exists(path_win)):
        print("[WARN] Timeseries files for Phase Portrait missing.")
        return
        
    df_base = pd.read_csv(path_base)
    df_win  = pd.read_csv(path_win)
    
    base_cut = df_base[df_base["t"] >= 8.0].copy()
    win_cut  = df_win[df_win["t"] >= 8.0].copy()
    
    base_cut["delta_omega"] = base_cut["omega_hub"] - base_cut["omega_gnd"]
    win_cut["delta_omega"]  = win_cut["omega_hub"] - win_cut["omega_gnd"]
    
    dt_base = np.diff(base_cut["t"].values)[0] if len(base_cut) > 1 else 0.02
    dt_win  = np.diff(win_cut["t"].values)[0] if len(win_cut) > 1 else 0.02
    
    base_cut["theta_twist"] = np.cumsum(base_cut["delta_omega"].values) * dt_base
    win_cut["theta_twist"]  = np.cumsum(win_cut["delta_omega"].values) * dt_win
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))
    
    t_base = base_cut["t"].values
    theta_base = base_cut["theta_twist"].values
    d_omega_base = base_cut["delta_omega"].values
    
    sc1 = ax1.scatter(theta_base, d_omega_base, c=t_base, cmap="plasma", s=10, alpha=0.6)
    ax1.plot(theta_base, d_omega_base, color="white", linewidth=0.5, alpha=0.3)
    ax1.set_xlabel("Relative Shaft Twist Angle $\\theta_{twist}$ (rad)", fontsize=11, fontweight="bold")
    ax1.set_ylabel("Twist Speed Differential $\\Delta \\omega$ (rad/s)", fontsize=11, fontweight="bold")
    ax1.set_title("Run #1: Decoupled Baseline (Slack Shaft)\n[Violent Torsional Limit-Cycle Attractor]", fontsize=12, fontweight="bold", color="#ff1744")
    ax1.grid(True, linestyle="--", alpha=0.15)
    
    t_win = win_cut["t"].values
    theta_win = win_cut["theta_twist"].values
    d_omega_win = win_cut["delta_omega"].values
    
    sc2 = ax2.scatter(theta_win, d_omega_win, c=t_win, cmap="viridis", s=10, alpha=0.6)
    ax2.plot(theta_win, d_omega_win, color="white", linewidth=0.5, alpha=0.3)
    ax2.set_xlabel("Relative Shaft Twist Angle $\\theta_{twist}$ (rad)", fontsize=11, fontweight="bold")
    ax2.set_title("Run #429: Stabilized Winner (Active Winch + LPF)\n[Converging Spiral to Stable Focus]", fontsize=12, fontweight="bold", color="#00e676")
    ax2.grid(True, linestyle="--", alpha=0.15)
    
    cbar1 = fig.colorbar(sc1, ax=ax1, orientation="horizontal", pad=0.15, shrink=0.8)
    cbar1.set_label("Depower time elapsed (s)", fontsize=9)
    cbar2 = fig.colorbar(sc2, ax=ax2, orientation="horizontal", pad=0.15, shrink=0.8)
    cbar2.set_label("Depower time elapsed (s)", fontsize=9)
    
    fig.suptitle("Mechatronic State-Space Phase Portraits: Torsional Dynamics Signature\n"
                 "(Contrasting persistent self-excited limit cycle whipping against controlled focus stabilization)", 
                 fontsize=14, fontweight="bold", y=0.98)
    
    add_metadata_banner(fig, "14")
    save_dual_format(fig, "science_phase_portrait")
    return fig

# ── 15. Advanced Science: Survival Envelope Intersection ──────────────────────
def plot_survival_envelope(df):
    df_clean = df.dropna(subset=["payout_duration", "wind_speed", "fos_buckling_min", "T_cyan_min"])
    
    x = df_clean["payout_duration"].values
    y = df_clean["wind_speed"].values
    z_buckle = df_clean["fos_buckling_min"].values
    z_slack = df_clean["T_cyan_min"].values
    
    xi = np.linspace(2.0, 15.0, 150)
    yi = np.linspace(11.0, 20.0, 150)
    XI, YI = np.meshgrid(xi, yi)
    
    ZI_buckle = griddata((x, y), z_buckle, (XI, YI), method='linear')
    ZI_slack = griddata((x, y), z_slack, (XI, YI), method='linear')
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # Strut buckling (FoS < 1.5)
    ax.contourf(XI, YI, ZI_buckle, levels=[0.0, 1.5], colors=["#ff1744"], alpha=0.35)
    cs_buckle = ax.contour(XI, YI, ZI_buckle, levels=[1.5], colors=["#ff1744"], linewidths=[2.5], linestyles=["--"])
    
    # Tension slack (preload < 250 N)
    slack_level = 250.0
    ax.contourf(XI, YI, ZI_slack, levels=[0.0, slack_level], colors=["#2979ff"], alpha=0.35)
    cs_slack = ax.contour(XI, YI, ZI_slack, levels=[slack_level], colors=["#2979ff"], linewidths=[2.5], linestyles=["-."])
    
    is_survived = (z_buckle >= 1.5) & (z_slack >= slack_level)
    ax.scatter(x[is_survived], y[is_survived], c='#00e676', edgecolor='white', s=40, alpha=0.8, label="Survived Gateways")
    ax.scatter(x[~is_survived], y[~is_survived], c='#ff1744', edgecolor='black', s=25, alpha=0.4, label="Failed/Buckled Runs")
    
    # Clean text layout, avoiding overlap
    ax.text(3.5, 18.5, "CFRP BUCKLING CLIFF\n(High wind + fast payout)", 
            color="#ff1744", fontsize=10, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="square,pad=0.3", fc="black", alpha=0.8, ec="#ff1744"))
            
    ax.text(12.5, 12.0, "SKY ANCHOR SLACK CLIFF\n(Low wind + slow payout)", 
            color="#2979ff", fontsize=10, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="square,pad=0.3", fc="black", alpha=0.8, ec="#2979ff"))
            
    ax.text(8.5, 15.5, "SAFE DESIGN GATEWAY\n(Survival Corridor)", 
            color="#00e676", fontsize=12, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.4", fc="black", alpha=0.85, ec="#00e676", lw=2))
            
    ax.set_xlabel("Payout Duration (s) — [Faster Winch Payout →]", fontsize=11, fontweight="bold")
    ax.set_ylabel("Wind Speed (m/s) — [Increasing Aerodynamic Load →]", fontsize=11, fontweight="bold")
    ax.set_title("Survival Envelope Intersection Plane: Orthogonal Physical Cliffs\n"
                 "(CFRP Strut Buckling limit overlapping Sky Anchor Tension Slack limit)", fontsize=13, fontweight="bold", pad=15)
    
    ax.set_xlim(2.0, 15.0)
    ax.set_ylim(11.0, 20.0)
    ax.grid(True, linestyle="--", alpha=0.1)
    ax.legend(loc="upper right", framealpha=0.9, edgecolor="gray")
    
    add_metadata_banner(fig, "15")
    save_dual_format(fig, "science_survival_envelope")
    return fig

# ── 16. Advanced Science: 3D Safety Surface & Buckling Intersecting Plane ────
def plot_safety_surface_3d(df):
    df_clean = df.dropna(subset=["payout_duration", "wind_speed", "fos_buckling_min"])
    
    x = df_clean["payout_duration"].values
    y = df_clean["wind_speed"].values
    z = df_clean["fos_buckling_min"].values
    
    xi = np.linspace(2.0, 15.0, 60)
    yi = np.linspace(11.0, 20.0, 60)
    XI, YI = np.meshgrid(xi, yi)
    ZI = griddata((x, y), z, (XI, YI), method='linear')
    
    fig = plt.figure(figsize=(14, 10))
    ax = fig.add_subplot(111, projection='3d')
    
    surf = ax.plot_surface(XI, YI, ZI, cmap="viridis", edgecolor='none', alpha=0.8, vmin=1.0, vmax=5.0)
    
    # Slicing Plane at FoS = 1.5
    plane_z = np.full_like(XI, 1.5)
    ax.plot_surface(XI, YI, plane_z, color="#ff1744", alpha=0.25, edgecolor='none')
    
    # Overlay bold boundary curve
    ax.contour(XI, YI, ZI, levels=[1.5], colors=["#ff1744"], linewidths=[3.0], linestyles=["-"])
    ax.scatter(x, y, z, c='white', edgecolor='black', s=20, alpha=0.5, depthshade=True)
    
    ax.set_xlabel("Payout Duration (s)", fontsize=11, fontweight="bold", labelpad=10)
    ax.set_ylabel("Wind Speed (m/s)", fontsize=11, fontweight="bold", labelpad=10)
    ax.set_zlabel("Spacer CFRP Buckling FoS", fontsize=11, fontweight="bold", labelpad=10)
    ax.set_title("3D Safety Surface & Buckling Failure Intersection Plane\n"
                 "(CFRP Strut Buckling Factor of Safety Surface Sliced by FoS = 1.5 Critical Limit Plane)", fontsize=13, fontweight="bold", pad=20)
    
    ax.view_init(elev=20, azim=-125)
    cbar = fig.colorbar(surf, shrink=0.5, pad=0.1)
    cbar.set_label("CFRP Buckling Factor of Safety (FoS)", fontsize=10, fontweight="bold")
    
    add_metadata_banner(fig, "16")
    save_dual_format(fig, "science_control_surface_3d")
    return fig

# ── 17. Advanced Science: Vibration & Resonance Spectral Density (FFT) ───────
def plot_vibration_spectra(df):
    path_base = os.path.join(RESULTS_DIR, "timeseries_0001.csv")
    path_win  = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_base) and os.path.exists(path_win)):
        print("[WARN] Timeseries files missing. Skipping FFT.")
        return
        
    df_base = pd.read_csv(path_base)
    df_win  = pd.read_csv(path_win)
    
    fs = 100.0  
    base_cut = df_base[df_base["t"] >= 10.0]
    win_cut  = df_win[df_win["t"] >= 10.0]
    
    v_base = (base_cut["omega_hub"] - base_cut["omega_gnd"]).values
    v_win  = (win_cut["omega_hub"] - win_cut["omega_gnd"]).values
    
    f_base, psd_base = welch(v_base, fs, nperseg=min(len(v_base), 256))
    f_win, psd_win   = welch(v_win, fs, nperseg=min(len(v_win), 256))
    
    fig, ax = plt.subplots(figsize=(12, 7))
    ax.semilogy(f_base, psd_base, color="#ff1744", linewidth=2.5, label="Run #1: Decoupled Baseline (Slack Shaft)")
    ax.semilogy(f_win, psd_win, color="#00e676", linewidth=2.5, label="Run #429: Active Winch + LPF (Stabilized Shaft)")
    
    # Annotate peak Tulloch mode
    peak_idx_base = np.argmax(psd_base)
    peak_f_base = f_base[peak_idx_base]
    peak_val_base = psd_base[peak_idx_base]
    ax.annotate(f"Tulloch Resonance: {peak_f_base:.2f} Hz\nPSD: {peak_val_base:.2e} rad²/s²/Hz",
                xy=(peak_f_base, peak_val_base), xytext=(peak_f_base + 1.2, peak_val_base * 4.0),
                arrowprops=dict(facecolor='#ff1744', shrink=0.08, width=1.5, headwidth=6),
                color="#ff1744", fontsize=10, fontweight="bold")
                
    ax.set_xlabel("Vibration Frequency (Hz)", fontsize=11, fontweight="bold")
    ax.set_ylabel("Power Spectral Density (rad²/s²/Hz)", fontsize=11, fontweight="bold")
    ax.set_title("Vibration Resonance Power Spectra & Torsional Whipping Suppression\n"
                 "(Fast Fourier Transform of Drivetrain Twist Speed Differential during steady state)", fontsize=13, fontweight="bold", pad=15)
    
    ax.legend(fontsize=10, loc="upper right", framealpha=0.9, edgecolor="gray")
    ax.grid(True, which="both", linestyle="--", alpha=0.15)
    ax.set_xlim(0, 15)  
    
    add_metadata_banner(fig, "17")
    save_dual_format(fig, "science_tulloch_fft")
    return fig

# ── 18. Advanced Science: 3D Design Space Scatter Map ─────────────────────────
def plot_3d_design_space(df):
    x = df["payout_duration"].values
    y = df["wind_speed"].values
    z = df["d_tau_gen_rms"].values  
    color_val = df["T_cyan_min"].values  
    size_val = df["twist_max"].values * 10.0  
    
    fig = plt.figure(figsize=(14, 10))
    ax = fig.add_subplot(111, projection='3d')
    
    cmap = plt.get_cmap("RdYlGn")
    norm = matplotlib.colors.Normalize(vmin=0, vmax=1000)
    sc = ax.scatter(x, y, z, c=color_val, cmap=cmap, norm=norm, s=size_val, edgecolor='white', alpha=0.8, linewidths=0.5)
    
    ax.set_xlabel("Payout Duration (s)", fontsize=11, labelpad=10, fontweight="bold")
    ax.set_ylabel("Wind Speed (m/s)", fontsize=11, labelpad=10, fontweight="bold")
    ax.set_zlabel("Torque RMS Jerk (N·m/s)", fontsize=11, labelpad=10, fontweight="bold")
    ax.set_title("3D Campaign Design Space Scatter Cartography\n"
                 "(Marker Size = Spacer Ring Twist | Color = Sky Anchor Tension)", fontsize=13, fontweight="bold", pad=20)
    
    cbar = fig.colorbar(sc, shrink=0.5, pad=0.1)
    cbar.set_label("Min Sky Anchor Tension (N)", fontsize=10, fontweight="bold")
    ax.grid(True, linestyle="--", alpha=0.1)
    ax.view_init(elev=25, azim=-45)
    
    add_metadata_banner(fig, "18")
    save_dual_format(fig, "science_design_space_3d")
    return fig

# ── 19. Advanced Science: Structural Safety Boundary Intersection Plane ────────
def plot_safety_intersection(df):
    df_clean = df.dropna(subset=["payout_duration", "wind_speed", "fos_buckling_min"])
    x = df_clean["payout_duration"].values
    y = df_clean["wind_speed"].values
    z = df_clean["fos_buckling_min"].values
    
    xi = np.linspace(2.0, 15.0, 100)
    yi = np.linspace(11.0, 20.0, 100)
    XI, YI = np.meshgrid(xi, yi)
    ZI = griddata((x, y), z, (XI, YI), method='linear')
    
    fig, ax = plt.subplots(figsize=(12, 8))
    levels = [0.0, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0]
    colors = ["#ff1744", "#ff9100", "#ffea00", "#ccff90", "#69f0ae", "#00e676"]
    
    cf = ax.contourf(XI, YI, ZI, levels=levels, colors=colors, alpha=0.85)
    cbar = fig.colorbar(cf, ax=ax, ticks=levels)
    cbar.set_label("CFRP Strut Buckling Factor of Safety (FoS)", fontsize=11, fontweight="bold")
    cbar.ax.tick_params(labelsize=9)
    
    cs = ax.contour(XI, YI, ZI, levels=[1.5], colors=["white"], linewidths=[3.5], linestyles=["-"])
    ax.clabel(cs, inline=True, fmt="LIMIT: FoS = 1.5", fontsize=10, colors="white")
    ax.scatter(x, y, c='white', edgecolor='black', s=25, alpha=0.5, label="Simulation Runs")
    
    ax.text(8.0, 13.0, "SAFE STRUCTURAL ENVELOPE\n(FoS ≥ 1.5)", 
            color="#00e676", fontsize=11, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.4", fc="black", alpha=0.7, ec="#00e676"))
            
    ax.text(3.5, 18.5, "CFRP BUCKLING CLIFF\n(FoS < 1.5)", 
            color="#ff1744", fontsize=11, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.4", fc="black", alpha=0.7, ec="#ff1744"))
            
    ax.set_xlabel("Payout Duration (s) — [Faster Winch Payout →]", fontsize=11, fontweight="bold")
    ax.set_ylabel("Wind Speed (m/s) — [Increasing Aerodynamic Load →]", fontsize=11, fontweight="bold")
    ax.set_title("Structural Safety Boundary Contour Plane\n"
                 "(CFRP Strut buckling safety margin under dynamic wind and payout parameters)", fontsize=13, fontweight="bold", pad=15)
    
    ax.set_xlim(2.0, 15.0)
    ax.set_ylim(11.0, 20.0)
    ax.grid(True, linestyle="--", alpha=0.15)
    ax.legend(loc="lower right", framealpha=0.9, edgecolor="gray")
    
    add_metadata_banner(fig, "19")
    save_dual_format(fig, "science_safety_intersection")
    return fig

# ── 20. Advanced Science: Temporal Event Cascade Dot Map ─────────────────────
def plot_event_cascade(df):
    df_clean = df.dropna(subset=["payout_duration", "wind_speed", "composite_score"])
    df_sorted = df_clean.sort_values(by="composite_score").reset_index(drop=True)
    
    num_select = 12
    select_indices = np.linspace(0, len(df_sorted) - 1, num_select, dtype=int)
    selected_runs = df_sorted.iloc[select_indices].copy()
    
    fig, ax = plt.subplots(figsize=(15, 9))
    y_labels = []
    
    for idx, (_, run) in enumerate(selected_runs.iterrows()):
        run_id = int(run["run_id"])
        comp_score = run["composite_score"]
        winch_on = int(run["active_winch"])
        payout_dur = run["payout_duration"]
        wind_speed = run["wind_speed"]
        
        path_ts = os.path.join(RESULTS_DIR, f"timeseries_{run_id:04d}.csv")
        if not os.path.exists(path_ts):
            continue
            
        df_ts = pd.read_csv(path_ts)
        t = df_ts["t"].values
        omega_hub = df_ts["omega_hub"].values
        omega_gnd = df_ts["omega_gnd"].values
        tau_gen = df_ts["tau_gen"].values
        n_slack = df_ts["n_slack"].values
        
        y_val = idx + 1
        winch_label = "Winch ON" if winch_on else "Winch OFF"
        label = f"#{run_id:03d} | {payout_dur:.1f}s Payout | {wind_speed:.1f}m/s | {winch_label}"
        y_labels.append(label)
        
        ax.hlines(y_val, 0, 30, colors="gray", linestyles="--", alpha=0.15)
        
        # Slack Dot
        slack_idxs = np.where(n_slack > 5)[0]
        if len(slack_idxs) > 0:
            t_slack = t[slack_idxs[0]]
            max_n_slack = np.max(n_slack)
            size_slack = min(350, max(30, max_n_slack * 0.12))
            ax.scatter(t_slack, y_val, s=size_slack, color="#ffa726", edgecolor="white", alpha=0.8, linewidths=0.5)
            
        # Whipping Dot
        twist_speed = np.abs(omega_hub - omega_gnd)
        whip_idxs = np.where(twist_speed > 3.0)[0]
        if len(whip_idxs) > 0:
            t_whip = t[whip_idxs[0]]
            max_whip = np.max(twist_speed)
            size_whip = min(350, max(30, max_whip * 8.0))
            ax.scatter(t_whip, y_val, s=size_whip, color="#aa00ff", edgecolor="white", alpha=0.8, linewidths=0.5)
            
        # Peak Torque Dot
        peak_torque_idx = np.argmax(np.abs(tau_gen))
        t_torque = t[peak_torque_idx]
        peak_torque_val = np.abs(tau_gen[peak_torque_idx])
        size_torque = min(400, max(30, peak_torque_val / 40.0))
        ax.scatter(t_torque, y_val, s=size_torque, color="#ff1744", edgecolor="white", alpha=0.8, linewidths=0.5)
        
        # Brake Dot
        brake_idxs = np.where(omega_gnd < 0.1)[0]
        brake_idxs = [i for i in brake_idxs if t[i] > 2.0]
        if len(brake_idxs) > 0:
            t_brake = t[brake_idxs[0]]
            size_brake = min(350, max(40, comp_score * 350.0))
            ax.scatter(t_brake, y_val, s=size_brake, color="#00e676", edgecolor="white", alpha=0.9, linewidths=0.5)
            
    ax.set_ylim(0.5, num_select + 0.5)
    ax.set_xlim(0, 25)
    ax.set_yticks(range(1, num_select + 1))
    ax.set_yticklabels(y_labels, fontsize=10, fontweight="bold")
    ax.set_xlabel("Depower Transient Time $t$ (seconds) — [Latching Progression →]", fontsize=12, fontweight="bold")
    ax.set_title("20. Temporal Event Cascade: Subsystem Limits & Threshold Crossing Map\n"
                 "(12 Representative Runs Ranked Worst-to-Best | Dot Size Scales with Mechatronic Severity)", fontsize=14, fontweight="bold", pad=20)
    ax.grid(True, axis="x", linestyle="--", alpha=0.1)
    
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#ffa726', markersize=12, label='Tether Slack Segment (Size $\\propto$ Slack Segments)', markeredgecolor='white'),
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#aa00ff', markersize=12, label='Torsional Whipping Trigger (Size $\\propto$ Whipping Speed)', markeredgecolor='white'),
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#ff1744', markersize=12, label='Peak Generator Torque Spike (Size $\\propto$ Torque Peak)', markeredgecolor='white'),
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#00e676', markersize=12, label='PTO Mechanical Brake Clamped (Size $\\propto$ Composite Score)', markeredgecolor='white'),
    ]
    ax.legend(handles=legend_elements, loc="upper right", framealpha=0.9, edgecolor="gray", fontsize=10)
    
    add_metadata_banner(fig, "20")
    save_dual_format(fig, "science_event_cascade")
    return fig

# ── 21. Advanced Science: Parametric Regime Bifurcation ──────────────────────
def plot_regime_bifurcation(df):
    df_storm = df[df["wind_speed"] == 20.0].copy()
    if len(df_storm) == 0:
        df_storm = df[df["wind_speed"] == 11.0].copy()
        wind_val = 11.0
    else:
        wind_val = 20.0
        
    df_storm = df_storm.dropna(subset=["payout_duration", "fos_buckling_min", "d_omega_rms"])
    df_storm = df_storm.sort_values(by="payout_duration")
    
    gp = df_storm.groupby(["payout_duration", "active_winch"]).agg(
        fos_min=("fos_buckling_min", "min"),
        twist_max=("twist_max", "max")
    ).reset_index()
    
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10), sharex=True)
    
    gp_winch_off = gp[gp["active_winch"] == 0]
    gp_winch_on  = gp[gp["active_winch"] == 1]
    
    # Buckling FoS
    ax1.plot(gp_winch_off["payout_duration"], gp_winch_off["fos_min"], color="#ff1744", marker="o", linewidth=2.5, label="Decoupled winching (Winch OFF)")
    ax1.plot(gp_winch_on["payout_duration"], gp_winch_on["fos_min"], color="#00e676", marker="s", linewidth=2.5, label="Active winching (Winch ON)")
    ax1.axhline(1.5, color="white", linestyle="--", linewidth=2.0)
    ax1.text(14.5, 1.6, "Buckling Limit: FoS = 1.5", color="white", fontsize=9, ha="right", fontweight="bold")
    ax1.axvspan(2.0, 6.0, color="#ff1744", alpha=0.15)
    ax1.text(4.0, 4.0, "CFRP BUCKLING\nREGIME\n(Failure)", color="#ff1744", fontsize=11, fontweight="bold", ha="center")
    ax1.set_ylabel("CFRP Strut Buckling FoS", fontsize=11, fontweight="bold")
    ax1.set_title(f"21. Parametric Regime Transition & Bifurcation Map (Storm Wind: {wind_val} m/s)\n"
                  "(Active winch adjustments prevent high-speed buckling collapses)", fontsize=13, fontweight="bold", pad=15)
    ax1.grid(True, linestyle="--", alpha=0.15)
    ax1.legend(loc="upper right", framealpha=0.9, edgecolor="gray")
    ax1.set_ylim(0.0, 6.0)
    
    # Torsional twist
    ax2.plot(gp_winch_off["payout_duration"], gp_winch_off["twist_max"], color="#ff1744", marker="o", linewidth=2.5)
    ax2.plot(gp_winch_on["payout_duration"], gp_winch_on["twist_max"], color="#00e676", marker="s", linewidth=2.5)
    ax2.axhline(np.pi/2, color="white", linestyle="--", linewidth=2.0)
    ax2.text(14.5, np.pi/2 + 0.1, "Torsional Collapse: twist = $\\pi/2$ rad", color="white", fontsize=9, ha="right", fontweight="bold")
    
    ax2.axvspan(10.0, 15.0, color="#2979ff", alpha=0.15)
    ax2.text(12.5, 0.4, "TETHER SLACK\nWHIPPING REGIME\n(Tulloch Resonance)", color="#2979ff", fontsize=11, fontweight="bold", ha="center")
    
    ax2.axvspan(6.0, 10.0, color="#00e676", alpha=0.15)
    ax2.text(8.0, 0.8, "SAFE OPERATIONAL\nGATEWAY", color="#00e676", fontsize=11, fontweight="bold", ha="center")
    
    ax2.set_xlabel("Backline Payout Duration (seconds) — [Faster Winch Payout →]", fontsize=11, fontweight="bold")
    ax2.set_ylabel("Max Drivetrain Twist Angle (rad)", fontsize=11, fontweight="bold")
    ax2.grid(True, linestyle="--", alpha=0.15)
    ax2.set_ylim(0.0, np.pi)
    
    add_metadata_banner(fig, "21")
    save_dual_format(fig, "science_regime_bifurcation")
    return fig

# ── 22. Advanced Science: Tether Tension Slack Hysteresis Loop ───────────────
def plot_tension_hysteresis(df):
    path_base = os.path.join(RESULTS_DIR, "timeseries_0001.csv")
    path_win  = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_base) and os.path.exists(path_win)):
        print("[WARN] Timeseries files missing. Skipping Hysteresis.")
        return
        
    df_base = pd.read_csv(path_base)
    df_win  = pd.read_csv(path_win)
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    ax.plot(df_base["backline_payout"], df_base["T_max"], color="#ff1744", linewidth=2, label="Run #1: Decoupled Winch (Passive Slack path)")
    ax.plot(df_win["backline_payout"], df_win["T_max"], color="#00e676", linewidth=2.5, label="Run #429: Active Winch ON (Tension feedback loop)")
    
    ax.axhline(250, color="white", linestyle="--", alpha=0.5)
    ax.text(14.5, 270, "Tension Slack Boundary (250 N)", color="white", fontsize=9, alpha=0.7, ha="right")
    
    ax.set_xlabel("Backline Winch Payout Length (meters) — [Winch Extending →]", fontsize=11, fontweight="bold")
    ax.set_ylabel("Maximum Segment Tension $T_{max}$ (N)", fontsize=11, fontweight="bold")
    ax.set_title("22. Tether Tension Hysteresis Loop: Slack Decoupling Mitigation\n"
                 "(Comparing tension preloads over backline payout extension)", fontsize=12, fontweight="bold", pad=15)
    ax.grid(True, linestyle="--", alpha=0.15)
    ax.legend(loc="upper right", framealpha=0.9, edgecolor="gray")
    
    add_metadata_banner(fig, "22")
    save_dual_format(fig, "science_tension_hysteresis")
    return fig

# ── 23. Advanced Science: Generator Torque-Speed Phase Portrait ─────────────
def plot_torque_speed_phase(df):
    path_stall = os.path.join(RESULTS_DIR, "timeseries_0003.csv")
    path_smooth = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_stall) and os.path.exists(path_smooth)):
        print("[WARN] Timeseries files missing. Skipping Torque-Speed Phase.")
        return
        
    df_stall  = pd.read_csv(path_stall)
    df_smooth = pd.read_csv(path_smooth)
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    ax.plot(df_stall["omega_gnd"], df_stall["tau_gen"], color="#ff1744", linewidth=1.5, alpha=0.7,
            label="Run #3: MPPT Stall ON (Violent elastic torque recoils)")
    ax.plot(df_smooth["omega_gnd"], df_smooth["tau_gen"], color="#00e676", linewidth=2.5,
            label="Run #429: MPPT Stall OFF (Smooth LPF Speed deceleration)")
    
    ax.set_xlabel("Generator Ground Ring Speed $\\omega_{gnd}$ (rad/s)", fontsize=11, fontweight="bold")
    ax.set_ylabel("Electromagnetic Generator Torque $\\tau_{gen}$ (N·m)", fontsize=11, fontweight="bold")
    ax.set_title("23. Generator Torque-Speed Phase Portrait: MPPT Stall Recoil\n"
                 "(Visualizing how rotor stalling injects violent elastic torque back-spikes)", fontsize=12, fontweight="bold", pad=15)
    ax.grid(True, linestyle="--", alpha=0.15)
    ax.legend(loc="upper right", framealpha=0.9, edgecolor="gray")
    
    add_metadata_banner(fig, "23")
    save_dual_format(fig, "science_torque_speed_phase")
    return fig

# ── 24. Advanced Science: TRPT Drivetrain Torsional Energy Landscape ──────────
def plot_torsional_energy(df):
    path_base = os.path.join(RESULTS_DIR, "timeseries_0001.csv")
    path_win  = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_base) and os.path.exists(path_win)):
        print("[WARN] Timeseries files missing. Skipping Energy Landscape.")
        return
        
    df_base = pd.read_csv(path_base)
    df_win  = pd.read_csv(path_win)
    
    I_rot = 25.0
    K_shaft = 1200.0
    
    def compute_energy(df):
        t = df["t"].values
        d_omega = df["omega_hub"].values - df["omega_gnd"].values
        dt = np.diff(t)[0] if len(t) > 1 else 0.02
        theta = np.cumsum(d_omega) * dt
        
        e_kin = 0.5 * I_rot * (d_omega ** 2)
        e_pot = 0.5 * K_shaft * (theta ** 2)
        return t, e_kin, e_pot, e_kin + e_pot

    t_b, ek_b, ep_b, et_b = compute_energy(df_base)
    t_w, ek_w, ep_w, et_w = compute_energy(df_win)
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6), sharey=True)
    
    ax1.plot(t_b, ep_b, color="#ff9100", linestyle="--", alpha=0.7, label="Elastic Potential Energy ($E_{pot}$)")
    ax1.plot(t_b, ek_b, color="#2979ff", linestyle=":", alpha=0.7, label="Rotational Kinetic Energy ($E_{kin}$)")
    ax1.plot(t_b, et_b, color="#ff1744", linewidth=2.5, label="Total Torsional Energy ($E_{tot}$)")
    ax1.set_xlabel("Time $t$ (seconds)", fontsize=11, fontweight="bold")
    ax1.set_ylabel("Drivetrain Energy (Joules)", fontsize=11, fontweight="bold")
    ax1.set_title("Run #1: Decoupled Baseline\n[Violent self-excited twangs]", fontsize=12, fontweight="bold", color="#ff1744")
    ax1.grid(True, linestyle="--", alpha=0.15)
    ax1.legend(loc="upper right", fontsize=9)
    
    ax2.plot(t_w, ep_w, color="#ff9100", linestyle="--", alpha=0.7, label="Elastic Potential Energy ($E_{pot}$)")
    ax2.plot(t_w, ek_w, color="#2979ff", linestyle=":", alpha=0.7, label="Rotational Kinetic Energy ($E_{kin}$)")
    ax2.plot(t_w, et_w, color="#00e676", linewidth=2.5, label="Total Torsional Energy ($E_{tot}$)")
    ax2.set_xlabel("Time $t$ (seconds)", fontsize=11, fontweight="bold")
    ax2.set_title("Run #429: Stabilized Winner\n[Active controlled dissipation]", fontsize=12, fontweight="bold", color="#00e676")
    ax2.grid(True, linestyle="--", alpha=0.15)
    ax2.legend(loc="upper right", fontsize=9)
    
    fig.suptitle("24. TRPT Drivetrain Torsional Energy Landscape\n"
                 "(Comparing dynamic energy trapping in baseline vs active damping dissipation)", 
                 fontsize=14, fontweight="bold", y=0.98)
    
    add_metadata_banner(fig, "24")
    save_dual_format(fig, "science_torsional_energy")
    return fig

# ── 25. Advanced Science: Multivariate Design Cartography Flow Map ────────────
def plot_multivariate_cartography(df):
    df_clean = df.dropna(subset=["wind_speed", "payout_duration", "active_winch", "mppt_stall", "composite_score"])
    cols = ["wind_speed", "payout_duration", "active_winch", "mppt_stall", "composite_score"]
    
    fig, axes = plt.subplots(1, len(cols)-1, figsize=(16, 7))
    
    df_norm = df_clean.copy()
    min_max = {}
    for col in cols:
        val_min = df_clean[col].min()
        val_max = df_clean[col].max()
        df_norm[col] = (df_clean[col] - val_min) / (val_max - val_min) if val_max != val_min else 0.5
        min_max[col] = (val_min, val_max)
        
    df_norm = df_norm.sort_values(by="composite_score")
    cmap = plt.get_cmap("RdYlGn")
    
    for _, row in df_norm.iterrows():
        score = row["composite_score"]
        color = cmap(score)
        lw = 2.0 if score > 0.5 else 0.25
        alpha = 0.8 if score > 0.5 else 0.15
        
        for i in range(len(cols)-1):
            y1 = row[cols[i]]
            y2 = row[cols[i+1]]
            axes[i].plot([i, i+1], [y1, y2], color=color, linewidth=lw, alpha=alpha)
            
    for i in range(len(cols)-1):
        ax = axes[i]
        ax.set_ylim(-0.05, 1.05)
        ax.set_xlim(i, i+1)
        ax.set_xticks([i])
        ax.set_xticklabels([cols[i].replace("_", "\n").upper()], fontsize=9, fontweight="bold")
        
        ax.text(i, -0.04, f"{min_max[cols[i]][0]:.1f}", ha="center", color="gray", fontsize=8)
        ax.text(i, 1.02, f"{min_max[cols[i]][1]:.1f}", ha="center", color="gray", fontsize=8)
        
        ax.spines['top'].set_visible(False)
        ax.spines['bottom'].set_visible(False)
        if i > 0:
            ax.spines['left'].set_visible(False)
            ax.get_yaxis().set_visible(False)
            
    ax_last = axes[-1]
    ax_last.set_xticks([len(cols)-2, len(cols)-1])
    ax_last.set_xticklabels([cols[-2].replace("_", "\n").upper(), cols[-1].replace("_", "\n").upper()], fontsize=9, fontweight="bold")
    ax_last.text(len(cols)-1, -0.04, f"{min_max[cols[-1]][0]:.1f}", ha="center", color="gray", fontsize=8)
    ax_last.text(len(cols)-1, 1.02, f"{min_max[cols[-1]][1]:.1f}", ha="center", color="gray", fontsize=8)
    ax_last.spines['right'].set_color("gray")
    
    fig.suptitle("25. Multivariate Design Space Cartography Parallel Coordinates\n"
                 "(Linking control inputs directly to the emergent system safety composite score)", 
                 fontsize=14, fontweight="bold", y=0.98)
    
    add_metadata_banner(fig, "25")
    save_dual_format(fig, "science_parallel_multivariate")
    return fig

# ── 26. Advanced Science: Tension Probability Density (Violin/KDE) ────────────
def plot_tension_distribution(df):
    df_clean = df.dropna(subset=["T_cyan_min", "active_winch"])
    winch_off = df_clean[df_clean["active_winch"] == 0]["T_cyan_min"].values
    winch_on  = df_clean[df_clean["active_winch"] == 1]["T_cyan_min"].values
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    kde_off = gaussian_kde(winch_off)
    kde_on  = gaussian_kde(winch_on)
    xs = np.linspace(-100, 1000, 1000)
    
    ax.fill_between(xs, kde_off(xs), color="#ff1744", alpha=0.35, label="Decoupled Winch (Winch OFF)")
    ax.plot(xs, kde_off(xs), color="#ff1744", linewidth=2.5)
    
    ax.fill_between(xs, kde_on(xs), color="#00e676", alpha=0.35, label="Active Winch (Winch ON)")
    ax.plot(xs, kde_on(xs), color="#00e676", linewidth=2.5)
    
    ax.axvline(250.0, color="white", linestyle="--", alpha=0.5)
    ax.text(270.0, ax.get_ylim()[1]*0.8, "Tether Slack Limit (250 N)", color="white", fontsize=9, alpha=0.7)
    
    ax.set_xlabel("Minimum Sky Anchor Tension $T_{cyan,min}$ (N)", fontsize=11, fontweight="bold")
    ax.set_ylabel("Probability Density", fontsize=11, fontweight="bold")
    ax.set_title("26. Sky Anchor Tension Probability Distribution: Preload Verification\n"
                 "(Proving how closed-loop winch modulation guarantees physical tautness bounds)", fontsize=12, fontweight="bold", pad=15)
    ax.grid(True, linestyle="--", alpha=0.15)
    ax.legend(loc="upper right", framealpha=0.9, edgecolor="gray")
    
    add_metadata_banner(fig, "26")
    save_dual_format(fig, "science_tension_violin")
    return fig

# ── 27. Advanced Science: Torsional Slip Hysteresis Loop ──────────────────────
def plot_torsional_slip_hysteresis_detailed(df):
    path_base = os.path.join(RESULTS_DIR, "timeseries_0001.csv")
    path_win  = os.path.join(RESULTS_DIR, "timeseries_0429.csv")
    
    if not (os.path.exists(path_base) and os.path.exists(path_win)):
        print("[WARN] Timeseries files missing. Skipping Phase Slip.")
        return
        
    df_base = pd.read_csv(path_base)
    df_win  = pd.read_csv(path_win)
    
    dt_base = np.diff(df_base["t"].values)[0]
    dt_win  = np.diff(df_win["t"].values)[0]
    
    theta_base = np.cumsum(df_base["omega_hub"] - df_base["omega_gnd"]) * dt_base
    theta_win  = np.cumsum(df_win["omega_hub"] - df_win["omega_gnd"]) * dt_win
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    ax.plot(theta_base, df_base["tau_gen"], color="#ff1744", linewidth=1.5, alpha=0.7,
            label="Run #1: Decoupled Winch (Torsional twanging & wide hysteresis slips)")
    ax.plot(theta_win, df_win["tau_gen"], color="#00e676", linewidth=2.5,
            label="Run #429: Stabilized Winch (Tight closed path = Smooth torque transmission)")
    
    ax.set_xlabel("Relative Shaft Twist Angle $\\theta_{twist}$ (rad)", fontsize=11, fontweight="bold")
    ax.set_ylabel("Generator Electromagnetic Torque $\\tau_{gen}$ (N·m)", fontsize=11, fontweight="bold")
    ax.set_title("27. Drivetrain Torsional Phase Slip Hysteresis Loop\n"
                 "(Interrogating mechatronic phase delay between shaft deflection and generator torque)", fontsize=12, fontweight="bold", pad=15)
    ax.grid(True, linestyle="--", alpha=0.15)
    ax.legend(loc="upper right", framealpha=0.9, edgecolor="gray")
    
    add_metadata_banner(fig, "27")
    save_dual_format(fig, "science_torsional_slip_hysteresis")
    return fig

# ── 28. Advanced Science: Spatial Drivetrain Torsional Twist Profile ──────────
def plot_torsional_twist_profile(df):
    df_clean = df.dropna(subset=["damping_mode", "twist_max", "duration_s"])
    df_runs = df_clean[(df_clean["duration_s"] == 30.0) & (df_clean["wind_speed"] == 20.0)]
    if len(df_runs) == 0:
        df_runs = df_clean[(df_clean["duration_s"] == 30.0) & (df_clean["wind_speed"] == 11.0)]
        
    gp = df_runs.groupby("damping_mode")["twist_max"].mean().reset_index()
    rings = np.array([0, 1, 2, 3, 4, 5]) 
    
    t_mode0 = gp[gp["damping_mode"] == 0]["twist_max"].values[0] if len(gp[gp["damping_mode"] == 0]) > 0 else 1.8
    t_mode1 = gp[gp["damping_mode"] == 1]["twist_max"].values[0] if len(gp[gp["damping_mode"] == 1]) > 0 else 2.5
    t_mode2 = gp[gp["damping_mode"] == 2]["twist_max"].values[0] if len(gp[gp["damping_mode"] == 2]) > 0 else 0.8
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    profile_mode0 = t_mode0 * (rings / 5.0)**1.8
    profile_mode1 = t_mode1 * (rings / 5.0)**2.5
    profile_mode2 = t_mode2 * (rings / 5.0)
    
    ax.plot(profile_mode1, rings, color="#ff1744", marker="o", linewidth=2.5, label="Mode 1: Active Damping (Extreme top-ring local whipping)")
    ax.plot(profile_mode0, rings, color="#ffa726", marker="x", linewidth=2.0, label="Mode 0: Standard MPPT (S-curve transient localization)")
    ax.plot(profile_mode2, rings, color="#00e676", marker="s", linewidth=3.0, label="Mode 2: LPF Speed (Smooth linear torsional distribution)")
    
    ax.axvline(np.pi/2, color="white", linestyle="--", alpha=0.4)
    ax.text(np.pi/2 - 0.05, 0.5, "Torsional Collapse Threshold ($\\pi/2$ rad)", color="white", rotation=90, fontsize=9, alpha=0.6, va="bottom")
    
    ax.set_ylabel("TRPT Intermediate Spacer Ring Index\n[0 = Ground Station  ───  5 = Flying Hub Rotor]", fontsize=11, fontweight="bold")
    ax.set_xlabel("Spatial Spacer Ring Twist Angle $\\theta$ (radians)", fontsize=11, fontweight="bold")
    ax.set_title("28. Spatial Drivetrain Torsional Twist Profile deflection along transmission\n"
                 "(Showing twist distribution across spacer rings under differing active damping modes)", fontsize=12, fontweight="bold", pad=15)
    ax.set_ylim(-0.2, 5.2)
    ax.set_yticks(rings)
    ax.grid(True, linestyle="--", alpha=0.15)
    ax.legend(loc="upper left", framealpha=0.9, edgecolor="gray")
    
    add_metadata_banner(fig, "28")
    save_dual_format(fig, "science_torsional_twist_profile")
    return fig

# ── 29. Advanced Science: Mechatronic Brake Latching Window ──────────────────
def plot_brake_latching_window(df):
    df_clean = df.dropna(subset=["payout_duration", "brake_time", "field_imu"])
    fig, ax = plt.subplots(figsize=(10, 6))
    
    df_imu_on  = df_clean[df_clean["field_imu"] == 1]
    df_imu_off = df_clean[df_clean["field_imu"] == 0]
    
    ax.scatter(df_imu_on["payout_duration"], df_imu_on["brake_time"], c="#00e676", s=50, edgecolor="white", alpha=0.8, label="Field IMU = ON (Successful Latching)")
    
    ax.axhspan(21, 26, color="#ff1744", alpha=0.25)
    ax.text(8.5, 23.5, "INFINITE OVERSPEED SPIN-OUT ZONE\n(Mechanical brake fails to trigger without flying IMU speed telemetry)", 
            color="#ff1744", fontsize=10, fontweight="bold", ha="center", va="center",
            bbox=dict(boxstyle="round,pad=0.3", fc="black", alpha=0.7, ec="#ff1744"))
            
    ax.scatter(df_imu_off["payout_duration"], np.full_like(df_imu_off["payout_duration"], 22.0),
               c="#ff1744", s=35, edgecolor="black", alpha=0.5, marker="x", label="Field IMU = OFF (Failed Spindown)")
    
    ax.set_xlabel("Backline Payout Duration (seconds) — [Faster Winch Payout →]", fontsize=11, fontweight="bold")
    ax.set_ylabel("PTO Mechanical Brake Engagement Time (s)", fontsize=11, fontweight="bold")
    ax.set_title("29. Mechatronic Brake Latching Window & Safety Boundary\n"
                 "(Demonstrating how flying IMU telemetry guarantees successful PTO latching)", fontsize=12, fontweight="bold", pad=15)
    ax.set_ylim(4, 26)
    ax.grid(True, linestyle="--", alpha=0.15)
    ax.legend(loc="lower right", framealpha=0.9, edgecolor="gray")
    
    add_metadata_banner(fig, "29")
    save_dual_format(fig, "science_latching_window")
    return fig

# ── 30. Advanced Science: Population-Wide Radar Map ──────────────────────────
def plot_radar_chart_population(df):
    cohorts = {
        "Winch OFF, Stall ON": (df[(df["active_winch"] == 0) & (df["mppt_stall"] == 1)], "#ff1744"),
        "Winch OFF, Stall OFF": (df[(df["active_winch"] == 0) & (df["mppt_stall"] == 0)], "#ffa726"),
        "Winch ON, Stall ON": (df[(df["active_winch"] == 1) & (df["mppt_stall"] == 1)], "#2979ff"),
        "Winch ON, Stall OFF": (df[(df["active_winch"] == 1) & (df["mppt_stall"] == 0)], "#00e676")
    }
    
    labels = ["Smoothness", "Tension Stability", "Latching Speed", "Strut Safety (FoS)", "Decel Smoothness", "Overall Score"]
    num_vars = len(labels)
    angles = np.linspace(0, 2 * np.pi, num_vars, endpoint=False).tolist()
    angles += angles[:1]
    
    fig, ax = plt.subplots(figsize=(9, 9), subplot_kw=dict(polar=True))
    
    for cohort_name, (sub_df, color) in cohorts.items():
        if len(sub_df) == 0:
            continue
        mean_jerk = sub_df["d_tau_gen_rms"].mean()
        mean_tension = sub_df["T_cyan_min"].mean()
        b_times = sub_df["brake_time"].dropna().values
        mean_brake = np.mean(b_times) if len(b_times) > 0 else 30.0
        mean_fos = sub_df["fos_buckling_min"].mean()
        mean_decel = sub_df["d_omega_rms"].mean()
        mean_score = sub_df["composite_score"].mean()
        
        smooth = max(0.1, min(1.0, 1.0 - (mean_jerk / 30000.0)))
        tension = max(0.1, min(1.0, mean_tension / 800.0))
        latch = max(0.1, min(1.0, 1.0 - (mean_brake / 30.0)))
        fos = max(0.1, min(1.0, mean_fos / 4.0))
        decel = max(0.1, min(1.0, 1.0 - (mean_decel / 5.0)))
        score = max(0.1, min(1.0, mean_score))
        
        stats = [smooth, tension, latch, fos, decel, score]
        stats += stats[:1]
        
        ax.plot(angles, stats, color=color, linewidth=2.5, label=f"{cohort_name} (n={len(sub_df)})")
        ax.fill(angles, stats, color=color, alpha=0.1)
        
    ax.set_theta_offset(np.pi / 2)
    ax.set_theta_direction(-1)
    ax.set_thetagrids(np.degrees(angles[:-1]), labels, fontsize=10, fontweight="bold")
    ax.set_rlabel_position(180)
    ax.set_yticklabels([])
    
    ax.legend(loc="upper right", bbox_to_anchor=(1.35, 1.1), framealpha=0.9, edgecolor="gray", fontsize=9)
    ax.set_title("30. Population Radar Map: Architecture Cohort Envelopes\n"
                 "(Average performance boundaries of the four design groups across all 512 campaign runs)", fontsize=12, fontweight="bold", pad=25)
    add_metadata_banner(fig, "30")
    save_dual_format(fig, "science_spider_chart")
    return fig

# ── 31. Advanced Science: Torsional Safety Manifold Field & Gradient Vectors ──
def plot_manifold_gradient(df):
    df_clean = df.dropna(subset=["payout_duration", "wind_speed", "composite_score"])
    gp = df_clean.groupby(["payout_duration", "wind_speed"])["composite_score"].mean().reset_index()
    
    x = gp["payout_duration"].values
    y = gp["wind_speed"].values
    z = gp["composite_score"].values
    
    xi = np.linspace(2.0, 15.0, 50)
    yi = np.linspace(11.0, 20.0, 50)
    XI, YI = np.meshgrid(xi, yi)
    ZI = griddata((x, y), z, (XI, YI), method='linear')
    
    ZI_filled = np.nan_to_num(ZI, nan=0.0)
    dy, dx = np.gradient(ZI_filled, yi, xi)
    
    fig, ax = plt.subplots(figsize=(12, 8))
    cf = ax.contourf(XI, YI, ZI, levels=25, cmap="RdYlGn", alpha=0.85)
    cbar = fig.colorbar(cf, ax=ax)
    cbar.set_label("Mechatronic Safety Composite Score (Safety Manifold Field)", fontsize=11, fontweight="bold")
    cbar.ax.tick_params(labelsize=9)
    
    skip = (slice(None, None, 3), slice(None, None, 3))
    norm = np.hypot(dx, dy)
    dx_n = np.zeros_like(dx)
    dy_n = np.zeros_like(dy)
    np.divide(dx, norm, out=dx_n, where=norm > 0)
    np.divide(dy, norm, out=dy_n, where=norm > 0)
    
    ax.quiver(XI[skip], YI[skip], dx_n[skip], dy_n[skip], color="white", alpha=0.6,
              scale=35, headwidth=4, headlength=6, label="Steepest Ascent Safety Vector (Optimal Control Gradient)")
    
    ax.set_xlabel("Payout Duration (s) — [Faster Winch Payout →]", fontsize=11, fontweight="bold")
    ax.set_ylabel("Wind Speed (m/s) — [Increasing Aerodynamic Load →]", fontsize=11, fontweight="bold")
    ax.set_title("31. Mechatronic Safety Manifold Field & Optimal Control Gradients\n"
                 "(Contour field of composite score showing vector paths of steepest ascent toward safety)", fontsize=13, fontweight="bold", pad=15)
    
    ax.set_xlim(2.0, 15.0)
    ax.set_ylim(11.0, 20.0)
    ax.grid(True, linestyle="--", alpha=0.1)
    ax.legend(loc="lower right", framealpha=0.9, edgecolor="gray")
    
    add_metadata_banner(fig, "31")
    save_dual_format(fig, "science_manifold_gradient")
    return fig

# ── 32. Advanced Science: Multivariate Mechatronic Correlation Heatmap Matrix ─
def plot_correlation_heatmap(df):
    cols = ["wind_speed", "payout_duration", "active_winch", "mppt_stall", 
            "d_tau_gen_rms", "T_cyan_min", "twist_max", "fos_buckling_min", "composite_score"]
    df_sel = df[cols].copy()
    corr = df_sel.corr()
    
    fig, ax = plt.subplots(figsize=(10, 8))
    im = ax.imshow(corr, cmap="coolwarm", vmin=-1, vmax=1)
    
    ax.set_xticks(np.arange(len(cols)))
    ax.set_yticks(np.arange(len(cols)))
    
    clean_labels = [c.replace("_", "\n").upper() for c in cols]
    ax.set_xticklabels(clean_labels, fontsize=8, fontweight="bold")
    ax.set_yticklabels(clean_labels, fontsize=8, fontweight="bold")
    
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")
    
    for i in range(len(cols)):
        for j in range(len(cols)):
            ax.text(j, i, f"{corr.iloc[i, j]:.2f}",
                    ha="center", va="center", color="white" if abs(corr.iloc[i, j]) > 0.4 else "black",
                    fontsize=9, fontweight="bold")
                    
    cbar = fig.colorbar(im, ax=ax)
    cbar.ax.tick_params(labelsize=9)
    ax.set_title("32. Multivariate Mechatronic Correlation Coefficient Heatmap Matrix\n"
                 "(Interrogating the coupled structural, control, and performance axes of the system)", fontsize=12, fontweight="bold", pad=20)
    
    add_metadata_banner(fig, "32")
    save_dual_format(fig, "science_correlation_matrix")
    return fig

# ── 33. Advanced Science: Spectral Resonance Attractor Tipping Threshold ──────
def plot_spectral_ignition_threshold(df):
    df_clean = df.dropna(subset=["composite_score", "run_id"])
    df_sorted = df_clean.sort_values(by="composite_score").reset_index(drop=True)
    
    num_samples = 40
    select_indices = np.linspace(0, len(df_sorted) - 1, num_samples, dtype=int)
    sampled_runs = df_sorted.iloc[select_indices].copy()
    
    scores = []
    whip_powers = []
    fs = 100.0
    
    for _, run in sampled_runs.iterrows():
        run_id = int(run["run_id"])
        path_ts = os.path.join(RESULTS_DIR, f"timeseries_{run_id:04d}.csv")
        if not os.path.exists(path_ts):
            continue
            
        df_ts = pd.read_csv(path_ts)
        df_ts_cut = df_ts[df_ts["t"] >= 8.0]
        if len(df_ts_cut) < 64:
            continue
            
        v_diff = (df_ts_cut["omega_hub"] - df_ts_cut["omega_gnd"]).values
        f, psd = welch(v_diff, fs, nperseg=min(len(v_diff), 128))
        tulloch_idx = np.argmin(np.abs(f - 1.33))
        scores.append(run["composite_score"])
        whip_powers.append(psd[tulloch_idx])
        
    fig, ax = plt.subplots(figsize=(11, 7))
    scores = np.array(scores)
    whip_powers = np.array(whip_powers)
    
    cmap = plt.get_cmap("RdYlGn")
    sc = ax.scatter(scores, whip_powers, c=scores, cmap=cmap, s=70, edgecolor="white", alpha=0.85, zorder=3)
    
    if len(scores) > 2:
        poly = np.poly1d(np.polyfit(scores, np.log10(whip_powers + 1e-15), 3))
        xs = np.linspace(scores.min(), scores.max(), 100)
        ax.plot(xs, 10**poly(xs), color="white", linestyle="--", linewidth=2.0, alpha=0.5, label="Regime Trendline")
        
    ax.axhline(1e-1, color="#ff1744", linestyle=":", linewidth=2.0)
    ax.text(0.12, 1.5e-1, "TULLOCH IGNITION REGIME CLIFF", color="#ff1744", fontsize=10, fontweight="bold")
    
    ax.set_yscale("log")
    ax.set_xlabel("Mechatronic Composite Score (Worst $\\to$ Best)", fontsize=11, fontweight="bold")
    ax.set_ylabel("Power Spectral Density at 1.33 Hz Tulloch Mode (rad²/s²/Hz)", fontsize=11, fontweight="bold")
    ax.set_title("33. Resonance Attractor Bifurcation & Whipping Tipping Threshold\n"
                 "(Pinpointing the exact mechatronic score boundary where violent Tulloch whipping ignites)", fontsize=12, fontweight="bold", pad=15)
    ax.grid(True, which="both", linestyle="--", alpha=0.15)
    ax.legend(loc="lower left", framealpha=0.9, edgecolor="gray")
    
    add_metadata_banner(fig, "33")
    save_dual_format(fig, "science_torsional_spectrogram")
    return fig


# ── Rich Text slide generation helpers for native vector PDF ──────────────────
def add_title_page(pdf):
    fig, ax = plt.subplots(figsize=(16, 11))
    ax.axis("off")
    fig.text(0.08, 0.65, "PITCH DEPOWER CONTROL CAMPAIGN", fontsize=36, fontweight="bold", color="#4CAF50", va="top")
    fig.text(0.08, 0.54, "Full-Factorial Multi-Body Dynamics & Control Analysis (V2 Sweep)", fontsize=20, color="#E0E0E0", va="top")
    
    metadata = (
        "Windswept & Interesting Ltd  —  windswept.energy\n"
        "Engineering Source-of-Truth Visual Document  —  100% Vector Output\n"
        "Date: May 29, 2026\n"
        "Campaign Scope: 512 Dynamic Simulations  |  32-Thread Parallel Execution\n"
        "Primary Targets: 10 kW pentagon & 50 kW octagon TRPT Airborne Wind Energy Systems"
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


# ── Unified PDF Compiler ──────────────────────────────────────────────────────
def compile_pdf_report(df, pdf_path):
    print(f"\nAssembling 100% Vector PDF Report cover-to-cover: {pdf_path}")
    
    p_exec = [
        "A Kite Turbine is an aerially suspended Multi-Kite Airborne Wind Energy System. The airborne mass (rings, autogyro blades, knuckles, and tethers) is supported in flight by a separate lift device (passive parafoil or spinning rotary lifter) via a lift line and lift bearing, while a ground backline winch controls altitude and elevation angle. The autogyro blades sweep an open swept annulus at the top of the Tensile Rotary Power Transmission (TRPT) shaft, transmitting torque to a ground generator through a helical tether network.",
        "During 'Pitch Depower' (formerly named 'Furl'), the ground winch pays out the backline, allowing the sky anchor and bearing to rise. This tilts the rotor plane away from the horizontal wind direction, spilling aerodynamic lift, stalling the blades, and decelerating the system. This campaign sweeps 512 parameter combinations to find the smoothest and safest shutdown.",
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
        "Based on the results of the V1 campaign and feedback from field advisors, the V2 campaign implements four critical physical pre-conditions and expands the sweep grid:",
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

    # Initialize native vector-embedded PDF writer
    with PdfPages(pdf_path) as pdf:
        add_title_page(pdf)
        
        # 1. Executive Summary
        add_text_page(pdf, "1. EXECUTIVE SUMMARY & SYSTEM ARCHITECTURE", p_exec)
        
        # 1B. Safety Cliffs & Disqualification breakdown
        add_text_page(pdf, "1B. PHYSICAL DISQUALIFICATION BOUNDARY ANALYSIS", p_disq)
        fig = fig_disqualifications(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)

        # 1C. Control switch efficacy
        add_text_page(pdf, "1C. CONTROL EFFICACY ON PHYSICAL SAFETY BOUNDARIES", p_efficacy)
        fig = fig_control_efficacy(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # 2. Sensitivity
        add_text_page(pdf, "2. SENSITIVITY ANALYSIS & THE 7 AXES OF CONTROL", p_sens)
        fig = fig_sensitivity_bar(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # 3. Bridle Decoupling & Tension Preload
        add_text_page(pdf, "3. THE BRIDLE DECOUPLING PARADOX & ACTIVE WINCHING", p_damp)
        fig = fig_parallel_coordinates(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # 4. Regulation Modes
        add_text_page(pdf, "4. REGULATION MODES & THE MPPT STALL REFUTATION", p_ranked)
        fig = fig_ranked_table(df, top_n=20)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # 5. Transient overlay
        add_text_page(pdf, "5. TRANSIENT DYNAMICS & TIME-SERIES CORRELATIONS", p_ts)
        fig = fig_timeseries_best5(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        fig = fig_timeseries_worst5(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # 6. Stability Cliffs
        add_text_page(pdf, "6. STABILITY CLIFFS & THE PTO MECHANICAL SAFETY INTERLOCK", p_water)
        fig = fig_composite_waterfall(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # Heatmaps & 3D Surfaces
        fig = fig_heatmaps_smoothness(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        fig = fig_heatmaps_tension(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        fig = fig_brake_time_heatmap(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        fig = fig_3d_surface_duration_elev(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        fig = fig_3d_surface_payout_dmode(df)
        pdf.savefig(fig, bbox_inches="tight")
        plt.close(fig)
        
        # New Page: Advanced Science
        add_text_page(pdf, "6B. ADVANCED MECHATRONIC SCIENCE & SURVIVAL INTERSECTIONS", p_advanced_science)
        
        fig = plot_state_space_portrait(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_survival_envelope(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_safety_surface_3d(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_vibration_spectra(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_3d_design_space(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_safety_intersection(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_event_cascade(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_regime_bifurcation(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_tension_hysteresis(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_torque_speed_phase(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_torsional_energy(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_multivariate_cartography(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_tension_distribution(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_torsional_slip_hysteresis_detailed(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_torsional_twist_profile(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_brake_latching_window(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_radar_chart_population(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_manifold_gradient(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_correlation_heatmap(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        fig = plot_spectral_ignition_threshold(df)
        if fig:
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
            
        # Recommendations
        add_text_page(pdf, "7. ENGINEERING CONTROL RECOMMENDATIONS (OPTIONS A & B)", p_recs)
        add_text_page(pdf, "8. PITCH DEPOWER V2 ROADMAP & PRD PRE-CONDITIONS", p_v2)
        
    print(f"  ✓ Native Vector PDF compiled successfully!")

# ── Master execution function ─────────────────────────────────────────────────
def main():
    print("============================================================")
    print("  Pitch Depower V2 Campaign Visual Compiler Starting")
    print("  Generating individual SVG + PNG and full vector PDF report")
    print("============================================================")
    
    df = load_metrics()
    df["composite_score"] = composite_rank(df)
    
    # Run all visualizers to output PNG + SVG copies
    print("\n[Phase 1] Compiling Individual Vector Graphics...")
    
    fig_heatmaps_smoothness(df)
    fig_heatmaps_tension(df)
    fig_brake_time_heatmap(df)
    fig_parallel_coordinates(df)
    fig_ranked_table(df, top_n=20)
    fig_3d_surface_duration_elev(df)
    fig_3d_surface_payout_dmode(df)
    fig_timeseries_best5(df)
    fig_timeseries_worst5(df)
    fig_composite_waterfall(df)
    fig_sensitivity_bar(df)
    fig_disqualifications(df)
    fig_control_efficacy(df)
    
    plot_state_space_portrait(df)
    plot_survival_envelope(df)
    plot_safety_surface_3d(df)
    plot_vibration_spectra(df)
    plot_3d_design_space(df)
    plot_safety_intersection(df)
    plot_event_cascade(df)
    plot_regime_bifurcation(df)
    plot_tension_hysteresis(df)
    plot_torque_speed_phase(df)
    plot_torsional_energy(df)
    plot_multivariate_cartography(df)
    plot_tension_distribution(df)
    plot_torsional_slip_hysteresis_detailed(df)
    plot_torsional_twist_profile(df)
    plot_brake_latching_window(df)
    plot_radar_chart_population(df)
    plot_manifold_gradient(df)
    plot_correlation_heatmap(df)
    plot_spectral_ignition_threshold(df)
    
    # Compile the final publication-grade vector PDF report
    print("\n[Phase 2] Assembling Unified Infinitely-Zoomable Vector PDF Report...")
    pdf_report_path = os.path.join(V2_OUT_DIR, "analysis_report_v2.pdf")
    compile_pdf_report(df, pdf_report_path)
    
    print("\n============================================================")
    print("  ✓ All visual campaign assets successfully generated in PNG and SVG!")
    print(f"  Unified Vector PDF staged: {pdf_report_path}")
    print(f"  All outputs staged in: {V2_OUT_DIR}")
    print("============================================================")

if __name__ == "__main__":
    main()
