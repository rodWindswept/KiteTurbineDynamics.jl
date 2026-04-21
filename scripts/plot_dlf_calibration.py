#!/usr/bin/env python3
"""scripts/plot_dlf_calibration.py
Generate Phase B Design Load Factor calibration figures from
scripts/results/trpt_opt/dlf/.
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

REPO    = Path(__file__).resolve().parent.parent
DLF_DIR = REPO / "scripts" / "results" / "trpt_opt" / "dlf"
OUT_DIR = DLF_DIR  # keep figures next to the data
plt.style.use("dark_background")

SCENARIO_LABELS = {
    "steady11":   "Steady 11 m/s (rated)",
    "steady15":   "Steady 15 m/s",
    "steady20":   "Steady 20 m/s",
    "steady25":   "Steady 25 m/s (peak)",
    "gust_11_25": "Coherent gust 11→25 m/s",
    "ebrake":     "Emergency brake (3× k_mppt step)",
}
SCENARIO_COLORS = {
    "steady11":   "#3DCFFF",
    "steady15":   "#7AD64A",
    "steady20":   "#FFB840",
    "steady25":   "#FF6464",
    "gust_11_25": "#C97AFF",
    "ebrake":     "#FF3838",
}


def fig1_envelope_per_ring():
    env = pd.read_csv(DLF_DIR / "envelope.csv")
    fig, ax = plt.subplots(figsize=(10, 5.8), dpi=130)
    for sc, sub in env.groupby("scenario"):
        sub = sub.sort_values("ring_id")
        ax.plot(sub["ring_id"], sub["DLF_peak"],
                marker="o", lw=2.0, label=SCENARIO_LABELS.get(sc, sc),
                color=SCENARIO_COLORS.get(sc, "white"))
    ax.axhline(0.5, color="grey", ls=":", label="Old assumed DLF = 0.5")
    ax.axhline(1.5, color="#FFFFFF", ls="--",
               label="Recommended DLF = 1.5 (calibrated)")
    ax.set_xlabel("Ring index (1 = ground anchor → 14 = hub)")
    ax.set_ylabel("Peak DLF  =  F_inward_per_vertex / T_line_static")
    ax.set_title("Phase B — Design Load Factor envelope per ring",
                 color="white", pad=12)
    ax.grid(alpha=0.3)
    ax.legend(fontsize=8, loc="upper center", ncol=2)
    fig.tight_layout()
    p = OUT_DIR / "fig_dlf_envelope_per_ring.png"
    fig.savefig(p, facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"wrote {p}")


def fig2_time_series_ebrake():
    df = pd.read_csv(DLF_DIR / "ebrake.csv")
    fig, axes = plt.subplots(2, 1, figsize=(10, 6.6), dpi=130, sharex=True)

    # Top: F_inward per vertex vs time, coloured by ring
    cmap = plt.get_cmap("plasma")
    rings = sorted(df["ring_id"].unique())
    for i, ri in enumerate(rings):
        sub = df[df["ring_id"] == ri]
        c = cmap(i / max(1, len(rings) - 1))
        axes[0].plot(sub["t"], sub["F_inward_per_vertex"],
                     color=c, lw=1.0, alpha=0.95)
    axes[0].axvline(2.0, color="white", ls="--", lw=0.8, label="brake step")
    axes[0].set_ylabel("F_inward per vertex (N)")
    axes[0].set_title("Emergency brake transient — per-ring inward force",
                      color="white", pad=8)
    axes[0].legend(fontsize=8, loc="upper right")
    axes[0].grid(alpha=0.25)

    # Bottom: hub wind (constant 11 m/s) and FOS minimum
    fos_min = df.groupby("t")["fos"].min().reset_index()
    axes[1].plot(fos_min["t"], fos_min["fos"], color="#FFB840", lw=1.4)
    axes[1].axhline(1.8, color="#FF3838", ls=":", label="FOS = 1.8 floor")
    axes[1].set_ylabel("min FOS across rings (live)")
    axes[1].set_xlabel("Time (s)")
    axes[1].set_yscale("log")
    axes[1].grid(alpha=0.25, which="both")
    axes[1].legend(fontsize=8)
    fig.tight_layout()
    p = OUT_DIR / "fig_ebrake_transient.png"
    fig.savefig(p, facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"wrote {p}")


def fig3_overlay_all_scenarios():
    fig, ax = plt.subplots(figsize=(10, 5.4), dpi=130)
    for sc, label in SCENARIO_LABELS.items():
        path = DLF_DIR / f"{sc}.csv"
        if not path.exists():
            continue
        df = pd.read_csv(path)
        # Take max F per vertex across rings vs time
        envelope = df.groupby("t")["F_inward_per_vertex"].max().reset_index()
        ax.plot(envelope["t"], envelope["F_inward_per_vertex"],
                lw=1.6, label=label, color=SCENARIO_COLORS[sc])
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("max F_inward per vertex across rings (N)")
    ax.set_title("Phase B — DLF envelope time-series across scenarios",
                 color="white", pad=10)
    ax.grid(alpha=0.3)
    ax.legend(fontsize=8)
    fig.tight_layout()
    p = OUT_DIR / "fig_scenario_envelope_timeseries.png"
    fig.savefig(p, facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"wrote {p}")


def fig4_dlf_summary_bars():
    env = pd.read_csv(DLF_DIR / "envelope.csv")
    summary = env.groupby("scenario").agg(
        DLF_max=("DLF_peak", "max"),
        DLF_p95=("DLF_p95",  "max"),
        DLF_mean=("DLF_mean", "mean"),
    ).reindex(list(SCENARIO_LABELS.keys()))

    x = np.arange(len(summary))
    fig, ax = plt.subplots(figsize=(9, 4.6), dpi=130)
    ax.bar(x - 0.25, summary["DLF_mean"], width=0.25,
           color="#3DCFFF", label="mean")
    ax.bar(x + 0.00, summary["DLF_p95"],  width=0.25,
           color="#FFB840", label="p95")
    ax.bar(x + 0.25, summary["DLF_max"],  width=0.25,
           color="#FF6464", label="peak")
    ax.axhline(0.5, color="grey", ls=":",
               label="prior OPT_DESIGN_LOAD_FACTOR = 0.5")
    ax.axhline(1.5, color="#FFFFFF", ls="--", label="recommended = 1.5")
    ax.set_xticks(x)
    ax.set_xticklabels([SCENARIO_LABELS[s] for s in summary.index],
                       rotation=22, ha="right", fontsize=8)
    ax.set_ylabel("Design Load Factor (F_v / T_line)")
    ax.set_title("Phase B — DLF mean / p95 / peak per scenario",
                 color="white", pad=10)
    ax.legend(fontsize=8, loc="upper left")
    ax.grid(alpha=0.3, axis="y")
    fig.tight_layout()
    p = OUT_DIR / "fig_dlf_summary_bars.png"
    fig.savefig(p, facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"wrote {p}")


if __name__ == "__main__":
    fig1_envelope_per_ring()
    fig2_time_series_ebrake()
    fig3_overlay_all_scenarios()
    fig4_dlf_summary_bars()
    print("DLF figures complete.")
