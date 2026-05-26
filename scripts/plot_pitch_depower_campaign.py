#!/usr/bin/env python3
# scripts/plot_pitch_depower_campaign.py
#
# Parses the pitch depower hypothesis campaign telemetry and generates three comparative charts:
#   1. Average Tether Tension (T_avg) over time.
#   2. Shaft Twist (delta_alpha_deg) over time.
#   3. Winching Payout (backline_payout) over time.

import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

OUT_DIR = Path(__file__).parent / "results" / "diagnostics"
CSV_PATH = OUT_DIR / "hypothesis_testing_telemetry.csv"

if not CSV_PATH.exists():
    sys.exit(f"Error: Telemetry CSV not found at {CSV_PATH}. Run test/test_pitch_depower_control_campaign.jl first.")

df = pd.read_csv(CSV_PATH)
cases = df["case"].unique()

# Visual style
BG_COLOR = "#0e1117"
PANEL_COLOR = "#161b22"
SPINE_COLOR = "#333333"
GRID_COLOR = "#222a36"

COLORS = {
    "Mode 1 Baseline": "#e06060",         # Coral Red
    "Hypothesis A (Winch Bias)": "#f5b041", # Orange
    "Hypothesis B (40% Clamp)": "#5b8dd9",  # Sky Blue
    "Hypothesis AB (Combined)": "#66c296",  # Sage Green
}

def setup_scientific_plot(w=10, h=6):
    fig, ax = plt.subplots(figsize=(w, h))
    fig.patch.set_facecolor(BG_COLOR)
    ax.set_facecolor(PANEL_COLOR)
    ax.tick_params(colors="white", labelsize=11)
    ax.grid(color=GRID_COLOR, linestyle="--", linewidth=0.7)
    for sp in ax.spines.values():
        sp.set_color(SPINE_COLOR)
    return fig, ax

def style_axes(ax, title="", xlabel="", ylabel=""):
    if title:  ax.set_title(title, color="white", fontsize=13, fontweight="bold", pad=10)
    if xlabel: ax.set_xlabel(xlabel, color="#aaaaaa", fontsize=11, labelpad=5)
    if ylabel: ax.set_ylabel(ylabel, color="#aaaaaa", fontsize=11, labelpad=5)

def finalize_and_save(fig, name):
    path = OUT_DIR / name
    fig.tight_layout()
    fig.savefig(path, dpi=150, bbox_inches="tight", facecolor=BG_COLOR)
    plt.close(fig)
    print(f"  Saved plot: {path.name}")

print("\n=== Generating Pitch Depower Hypothesis Campaign Charts ===")

# --- 1. TETHER TENSION HISTORIES ---
fig, ax = setup_scientific_plot(10, 6)
style_axes(ax, "Average Tether Tension (T_avg) under Pitch Depower Hypotheses",
           "Simulation Time (s)", "Average Tether Tension (N)")

for case in cases:
    sub = df[df["case"] == case].sort_values("t")
    ax.plot(sub["t"], sub["T_avg"], color=COLORS.get(case, "#888888"), linewidth=2.0, label=case)

ax.axhline(15.0, color="#66c296", linestyle="--", linewidth=1.0, alpha=0.7, label="Minimum Target Stiffness (15 N)")
ax.axhline(5.0, color="#e06060", linestyle="--", linewidth=1.0, alpha=0.7, label="Slack-Line Limit (5 N)")
ax.legend(fontsize=9, facecolor=PANEL_COLOR, edgecolor=SPINE_COLOR, labelcolor="white")
finalize_and_save(fig, "pitch_depower_campaign_tension.png")

# --- 2. SHAFT TWIST HISTORIES ---
fig, ax = setup_scientific_plot(10, 6)
style_axes(ax, "TRPT Shaft Twist Angle (Δα) under Pitch Depower Hypotheses",
           "Simulation Time (s)", "Total Shaft Twist Δα (degrees)")

for case in cases:
    sub = df[df["case"] == case].sort_values("t")
    ax.plot(sub["t"], sub["delta_alpha_deg"], color=COLORS.get(case, "#888888"), linewidth=2.0, label=case)

ax.legend(fontsize=9, facecolor=PANEL_COLOR, edgecolor=SPINE_COLOR, labelcolor="white")
finalize_and_save(fig, "pitch_depower_campaign_twist.png")

# --- 3. WINCHING PAYOUT HISTORIES ---
fig, ax = setup_scientific_plot(10, 6)
style_axes(ax, "Backline Winch Payout Profiles under Pitch Depower Hypotheses",
           "Simulation Time (s)", "Winch Payout Length (m)")

for case in cases:
    sub = df[df["case"] == case].sort_values("t")
    ax.plot(sub["t"], sub["backline_payout"], color=COLORS.get(case, "#888888"), linewidth=2.0, label=case)

ax.legend(fontsize=9, facecolor=PANEL_COLOR, edgecolor=SPINE_COLOR, labelcolor="white", loc="upper left")
finalize_and_save(fig, "pitch_depower_campaign_payout.png")

# --- 4. ACTUAL LIFT LINE TENSION HISTORIES ---
fig, ax = setup_scientific_plot(10, 6)
style_axes(ax, "Actual Lift Line Tension (T_lift) under Pitch Depower Hypotheses",
           "Simulation Time (s)", "Actual Lift Line Tension (N)")

for case in cases:
    sub = df[df["case"] == case].sort_values("t")
    # T_lift_aero represents the actual tension in the lift line governed by the lift kite
    ax.plot(sub["t"], sub["T_lift_aero"], color=COLORS.get(case, "#888888"), linewidth=2.0, label=case)

ax.legend(fontsize=9, facecolor=PANEL_COLOR, edgecolor=SPINE_COLOR, labelcolor="white")
finalize_and_save(fig, "pitch_depower_campaign_lifttension.png")

# --- 5. TOPMOST TRPT SEGMENT TENSION HISTORIES ---
fig, ax = setup_scientific_plot(10, 6)
style_axes(ax, "Topmost TRPT Drivetrain Segment Tension (T_top_avg)",
           "Simulation Time (s)", "Tether Tension (N)")

for case in cases:
    sub = df[df["case"] == case].sort_values("t")
    # T_top_avg represents the tethers in the topmost TRPT segment (sky-anchor -> hub)
    ax.plot(sub["t"], sub["T_top_avg"], color=COLORS.get(case, "#888888"), linewidth=2.0, label=case)
    if not sub.empty:
        normal_t = sub["T_top_normal"].iloc[0]
        ax.axhline(normal_t, color=COLORS.get(case, "#888888"), linestyle=":", linewidth=1.0, alpha=0.4)

ax.axhline(50.0, color="#e06060", linestyle="--", linewidth=1.0, alpha=0.7, label="Hub Unsupported Slack Limit (50 N)")
ax.legend(fontsize=9, facecolor=PANEL_COLOR, edgecolor=SPINE_COLOR, labelcolor="white")
finalize_and_save(fig, "pitch_depower_campaign_top_trpt.png")

print("=========================================\n")
