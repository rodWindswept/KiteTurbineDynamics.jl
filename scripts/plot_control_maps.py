#!/usr/bin/env python3
"""Plot control map timeseries: per-ring FoS evolution, collapse margin, worst ring, failing count."""
import sys, os
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

OUT_DIR = os.path.join(os.path.dirname(__file__), "results", "control_maps", "figures")
os.makedirs(OUT_DIR, exist_ok=True)

PALETTE = {"canonical_10kw": "#00BCD4", "v10_tight": "#FF5722", "v10_reinforced": "#4CAF50"}
WIND_COLORS = {5.0: "#2196F3", 7.0: "#4CAF50", 9.0: "#FFC107",
               11.0: "#FF9800", 13.0: "#F44336", 15.0: "#9C27B0"}


def load_design(name):
    """Load summary + timeseries for a design."""
    base = os.path.join(os.path.dirname(__file__), "results", "control_maps")
    summary = pd.read_csv(os.path.join(base, f"{name}_summary.csv"))
    ts = pd.read_csv(os.path.join(base, f"{name}_timeseries.csv"))
    return summary, ts


def plot_fos_evolution(name, summary, ts, ax=None):
    """Min FoS over time for each wind speed that reached rated."""
    if ax is None:
        _, ax = plt.subplots(figsize=(10, 5))
    rated = summary[summary.reached_rated == True]
    for _, row in rated.iterrows():
        v = row.v_wind
        mask = (ts.t_s >= 0)  # all slices for this design — timeseries spans all winds
        # We need to group timeseries by wind. Currently ts has no v_wind column.
        # For now, plot all timeseries on one axis with color by t_s as proxy.
        # FIX: the timeseries CSV spans all winds sequentially. We approximate by index.
    # Simple approach: plot the full timeseries
    ax.plot(ts.t_s, ts.min_fos, color=PALETTE.get(name, "#333"), lw=1.5, label=name)
    ax.axhline(1.5, color="red", ls="--", lw=1, label="FoS=1.5 floor")
    ax.set_ylabel("Min Ring FoS"); ax.set_xlabel("Time (s)")
    ax.set_title(f"Min FoS Evolution — {name}")
    ax.legend(); ax.grid(True, alpha=0.3)
    return ax


def plot_all_fos(summaries, timeseries_dict):
    """All designs on one FoS comparison plot — clipped to show structural range."""
    fig, ax = plt.subplots(figsize=(12, 6))
    for name, ts in timeseries_dict.items():
        if ts is None or len(ts) == 0:
            continue
        fos = ts.min_fos.copy()
        fos[fos > 50] = 50  # clip massive values from canonical overshoot
        ax.plot(ts.t_s, fos, color=PALETTE.get(name, "#333"),
                lw=1.5, label=name, alpha=0.8)
    ax.axhline(1.5, color="red", ls="--", lw=2, label="FoS=1.5 floor")
    ax.axhline(3.0, color="green", ls=":", lw=1, label="FoS=3.0 target")
    ax.set_ylabel("Min Ring FoS (clipped at 50)"); ax.set_xlabel("Time (s)")
    ax.set_title("Ring FoS Evolution — All Designs")
    ax.legend(loc="upper right"); ax.grid(True, alpha=0.3)
    ax.set_ylim(0, 20)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "fos_evolution_all.png"), dpi=150)
    print(f"Saved: fos_evolution_all.png")


def plot_collapse_margin(timeseries_dict):
    """Collapse margin evolution for all designs."""
    fig, ax = plt.subplots(figsize=(12, 6))
    for name, ts in timeseries_dict.items():
        if ts is None or len(ts) == 0:
            continue
        ax.plot(ts.t_s, ts.collapse_margin_deg, color=PALETTE.get(name, "#333"),
                lw=1.5, label=name, alpha=0.8)
    ax.axhline(5.0, color="red", ls="--", lw=2, label="5° hard freeze")
    ax.axhline(20.0, color="orange", ls=":", lw=1.5, label="20° soft taper")
    ax.set_ylabel("Collapse Margin (deg)"); ax.set_xlabel("Time (s)")
    ax.set_title("Tulloch Collapse Margin Evolution — All Designs")
    ax.legend(); ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "collapse_margin_all.png"), dpi=150)
    print(f"Saved: collapse_margin_all.png")


def plot_failing_rings(timeseries_dict):
    """Number of failing rings (FoS < 1.5) over time."""
    fig, ax = plt.subplots(figsize=(12, 6))
    for name, ts in timeseries_dict.items():
        if ts is None or len(ts) == 0:
            continue
        ax.plot(ts.t_s, ts.n_failing, color=PALETTE.get(name, "#333"),
                lw=1.5, label=name, alpha=0.8)
    ax.set_ylabel("Rings with FoS < 1.5"); ax.set_xlabel("Time (s)")
    ax.set_title("Failing Ring Count — All Designs")
    ax.legend(); ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "failing_rings_all.png"), dpi=150)
    print(f"Saved: failing_rings_all.png")


def plot_worst_ring(timeseries_dict):
    """Worst ring index over time."""
    fig, ax = plt.subplots(figsize=(12, 6))
    for name, ts in timeseries_dict.items():
        if ts is None or len(ts) == 0:
            continue
        ax.plot(ts.t_s, ts.worst_ring, color=PALETTE.get(name, "#333"),
                lw=1.5, label=name, alpha=0.8)
    ax.set_ylabel("Worst Ring Index (1 = ground)"); ax.set_xlabel("Time (s)")
    ax.set_title("Worst Ring Index (lowest FoS) — All Designs")
    ax.legend(); ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "worst_ring_all.png"), dpi=150)
    print(f"Saved: worst_ring_all.png")


def plot_kmppt_wind(summaries):
    """k_mppt vs wind speed — shows the inverted control law."""
    fig, ax = plt.subplots(figsize=(10, 6))
    for name, summary in summaries.items():
        if summary is None:
            continue
        rated = summary[summary.reached_rated == True]
        ax.plot(rated.v_wind, rated.k_mppt, "o-", color=PALETTE.get(name, "#333"),
                lw=2, markersize=8, label=name)
    ax.set_ylabel("k_mppt"); ax.set_xlabel("Wind Speed (m/s)")
    ax.set_title("Control Law k(v_wind) — WRONG FLANK (overspeed solutions)")
    ax.legend(); ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "kmppt_vs_wind.png"), dpi=150)
    print(f"Saved: kmppt_vs_wind.png")


def plot_power_vs_wind(summaries):
    """Power at endpoint vs wind speed."""
    fig, ax = plt.subplots(figsize=(10, 6))
    for name, summary in summaries.items():
        if summary is None:
            continue
        rated = summary[summary.reached_rated == True]
        ax.plot(rated.v_wind, rated.P_kw, "o-", color=PALETTE.get(name, "#333"),
                lw=2, markersize=8, label=name)
    ax.axhline(50.0, color="gray", ls="--", lw=1, label="50 kW rated")
    ax.axhline(10.0, color="gray", ls=":", lw=1, label="10 kW rated")
    ax.set_ylabel("Power (kW)"); ax.set_xlabel("Wind Speed (m/s)")
    ax.set_title("Power at Endpoint — All Designs (overshoots rated)")
    ax.legend(); ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "power_vs_wind.png"), dpi=150)
    print(f"Saved: power_vs_wind.png")


def plot_power_timeseries(timeseries_dict):
    """Power evolution over time for all designs."""
    fig, ax = plt.subplots(figsize=(12, 6))
    for name, ts in timeseries_dict.items():
        if ts is None or len(ts) == 0:
            continue
        ax.plot(ts.t_s, ts.P_kw, color=PALETTE.get(name, "#333"),
                lw=1.5, label=name, alpha=0.8)
    ax.set_ylabel("Generator Power (kW)"); ax.set_xlabel("Time (s)")
    ax.set_title("Power Evolution — All Designs")
    ax.legend(); ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "power_timeseries_all.png"), dpi=150)
    print(f"Saved: power_timeseries_all.png")


def plot_omega_timeseries(timeseries_dict):
    """Rotor speed evolution over time for all designs."""
    fig, ax = plt.subplots(figsize=(12, 6))
    for name, ts in timeseries_dict.items():
        if ts is None or len(ts) == 0:
            continue
        ax.plot(ts.t_s, ts.ω_rpm, color=PALETTE.get(name, "#333"),
                lw=1.5, label=name, alpha=0.8)
    ax.set_ylabel("Hub Speed (rpm)"); ax.set_xlabel("Time (s)")
    ax.set_title("Rotor Speed Evolution — All Designs")
    ax.legend(); ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT_DIR, "omega_timeseries_all.png"), dpi=150)
    print(f"Saved: omega_timeseries_all.png")


if __name__ == "__main__":
    designs = ["canonical_10kw", "v10_tight", "v10_reinforced"]
    summaries = {}
    timeseries = {}

    for name in designs:
        try:
            s, t = load_design(name)
            summaries[name] = s
            timeseries[name] = t
            print(f"Loaded {name}: {len(s)} summary rows, {len(t)} timeseries slices")
        except Exception as e:
            print(f"Skipping {name}: {e}")
            summaries[name] = None
            timeseries[name] = None

    plot_all_fos(summaries, timeseries)
    plot_collapse_margin(timeseries)
    plot_failing_rings(timeseries)
    plot_worst_ring(timeseries)
    plot_kmppt_wind(summaries)
    plot_power_vs_wind(summaries)
    plot_power_timeseries(timeseries)
    plot_omega_timeseries(timeseries)

    print("\nDone. All figures in:", OUT_DIR)
