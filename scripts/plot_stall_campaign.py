#!/usr/bin/env python3
# scripts/plot_stall_campaign.py
#
# Generates three comparative plots for the stall and ground-sensing campaign:
#   1. Drivetrain speed histories (stalling validation).
#   2. Ground Ring Axial Tension histories.
#   3. Winch payout histories.

import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

OUT_DIR = Path(__file__).parent / "results" / "diagnostics"
CSV_PATH = OUT_DIR / "stall_campaign_telemetry.csv"

if not CSV_PATH.exists():
    sys.exit(f"Error: Telemetry CSV not found at {CSV_PATH}. Run test/test_stall_control_campaign.jl first.")

df = pd.read_csv(CSV_PATH)
cases = df["case"].unique()

# Visual style
BG_COLOR = "#0e1117"
PANEL_COLOR = "#161b22"
SPINE_COLOR = "#333333"
GRID_COLOR = "#222a36"

COLORS = {
    "Mode 1 Baseline": "#e06060",          # Coral Red
    "Hypothesis A2 (Gnd Winch)": "#f5b041", # Orange
    "Hypothesis C (MPPT Stall)": "#5b8dd9",  # Sky Blue
    "Hypothesis AC (Combined)": "#66c296",  # Sage Green
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

print("\n=== Generating Stall Campaign Charts ===")

# --- 1. ANGULAR SPEED HISTORIES ---
fig, ax = setup_scientific_plot(10, 6.5)
style_axes(ax, "Generator Stalling Performance under k_MPPT Governor",
           "Simulation Time (s)", "Angular Velocity ω (rad/s)")

for case in cases:
    sub = df[df["case"] == case].sort_values("t")
    ax.plot(sub["t"], sub["omega_gnd"], color=COLORS.get(case, "#888888"), linewidth=2.0, label=f"{case} - Ground PTO")

ax.legend(fontsize=9, facecolor=PANEL_COLOR, edgecolor=SPINE_COLOR, labelcolor="white", loc="lower left")
finalize_and_save(fig, "pitch_depower_stall_speed.png")

# --- 2. GROUND RING TENSION HISTORIES ---
fig, ax = setup_scientific_plot(10, 6)
style_axes(ax, "Ground Ring Axial Tension under Ground-Sensing Control",
           "Simulation Time (s)", "Ground Ring Axial Tension (N)")

for case in cases:
    sub = df[df["case"] == case].sort_values("t")
    ax.plot(sub["t"], sub["T_gnd_avg"], color=COLORS.get(case, "#888888"), linewidth=2.0, label=case)

ax.axhline(150.0, color="#66c296", linestyle="--", linewidth=1.0, alpha=0.7, label="Winch Safety Threshold (150 N)")
ax.legend(fontsize=9, facecolor=PANEL_COLOR, edgecolor=SPINE_COLOR, labelcolor="white")
finalize_and_save(fig, "pitch_depower_stall_tension.png")

# --- 3. WINCHING PAYOUT HISTORIES ---
fig, ax = setup_scientific_plot(10, 6)
style_axes(ax, "Winch Payout modulated by Ground Ring Tension",
           "Simulation Time (s)", "Winch Payout Length (m)")

for case in cases:
    sub = df[df["case"] == case].sort_values("t")
    ax.plot(sub["t"], sub["backline_payout"], color=COLORS.get(case, "#888888"), linewidth=2.0, label=case)

ax.legend(fontsize=9, facecolor=PANEL_COLOR, edgecolor=SPINE_COLOR, labelcolor="white", loc="upper left")
finalize_and_save(fig, "pitch_depower_stall_payout.png")

print("=========================================\n")
