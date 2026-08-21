# scripts/chart_style.py
# Matplotlib style and helper library implementing KTD.jl Reporting Chart Standards

import os
import tomllib
import math
import matplotlib.pyplot as plt
from datetime import datetime

# Load TOML spec as single source of truth
SPEC_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "charts", "chart-spec.toml")
with open(SPEC_PATH, "rb") as f:
    spec = tomllib.load(f)

# Global constants for easy access
PALETTE = spec["palette"]
DESIGNS = spec["designs"]
THRESHOLDS = spec["thresholds"]

def ktd_style():
    """Applies the global KTD chart standard styles to matplotlib rcParams."""
    plt.rcParams["font.family"] = "sans-serif"
    plt.rcParams["font.sans-serif"] = [spec["fonts"]["sans"], "Arial", "DejaVu Sans"]
    plt.rcParams["font.size"] = spec["fonts"]["min_size"]
    plt.rcParams["axes.grid"] = True
    plt.rcParams["grid.alpha"] = 0.08
    plt.rcParams["grid.color"] = "black"
    plt.rcParams["axes.spines.top"] = False
    plt.rcParams["axes.spines.right"] = False
    plt.rcParams["figure.facecolor"] = "white"
    plt.rcParams["axes.facecolor"] = "white"
    plt.rcParams["savefig.facecolor"] = "white"
    plt.rcParams["figure.autolayout"] = True

def ktd_figure(width=None, height=None, **kwargs):
    """
    Creates a styled Figure and Axis.
    Uses default width and height from spec if not specified.
    """
    ktd_style()
    w = width if width is not None else spec["style"]["figure_width"]
    h = height if height is not None else spec["style"]["figure_height"]
    fig, ax = plt.subplots(figsize=(w, h), **kwargs)
    return fig, ax

def provenance_footer(fig, script_path, git_hash, csv_path, model_desc):
    """Adds a standardized provenance line at the bottom-left of the figure."""
    date_str = datetime.now().strftime("%Y-%m-%d")
    csv_name = os.path.basename(csv_path)
    footer_text = f"{script_path} @ {git_hash} · {csv_name} · {model_desc} · {date_str}"
    
    # Place text in figure coordinates (bottom-left)
    fig.text(0.01, 0.01, footer_text, fontsize=8, color="gray", ha="left", va="bottom")

def confidence_badge(ax, tier, position="top_right"):
    """Annotates the axis with a standardized confidence badge (H, M, P, or X)."""
    tier_str = str(tier).upper()
    if tier_str not in spec["confidence"]:
        raise ValueError(f"Confidence tier '{tier}' not found in spec. Available: H, M, P, X")
    badge_char = spec["confidence"][tier_str]["badge"]
    
    x, y = 0.95, 0.95
    ha, va = "right", "top"
    if position == "top_left":
        x, y = 0.05, 0.95
        ha, va = "left", "top"
    elif position == "bottom_right":
        x, y = 0.95, 0.05
        ha, va = "right", "bottom"
    elif position == "bottom_left":
        x, y = 0.05, 0.05
        ha, va = "left", "bottom"
        
    ax.text(x, y, f"[{badge_char}]", transform=ax.transAxes, ha=ha, va=va,
            fontsize=10, fontweight="bold", color="black")

def consistency_stamp(ax, type_sym, val, position="bottom_left"):
    """Adds a consistency stamp (e.g., P/kω³ ratio or energy conservation check)."""
    type_str = str(type_sym).strip(":") # Handle Julia-style symbol conversion if any
    passing = True
    if type_str == "power":
        # PRD §3.4: tick ONLY within tolerance; a failing stamp blocks publication
        passing = abs(val - 1.0) <= 0.01
        stamp_text = f"P/kω³ = {val:.2f} " + ("✓" if passing else "✗ FAIL")
    elif type_str == "energy":
        stamp_text = str(val)
    else:
        stamp_text = str(val)
        
    x, y = 0.05, 0.05
    ha, va = "left", "bottom"
    if position == "top_right":
        x, y = 0.95, 0.95
        ha, va = "right", "top"
    elif position == "top_left":
        x, y = 0.05, 0.95
        ha, va = "left", "top"
    elif position == "bottom_right":
        x, y = 0.95, 0.05
        ha, va = "right", "bottom"
        
    color = "#444444" if passing else THRESHOLDS.get("limit", "#D55E00")
    weight = "normal" if passing else "bold"
    ax.text(x, y, stamp_text, transform=ax.transAxes, ha=ha, va=va,
            fontsize=9, color=color, fontweight=weight)
    return passing

def rpm_twin_axis(ax, axis="x"):
    """Twin axis in rpm for THE ANGULAR-SPEED AXIS ONLY (PRD §3.1: the sole
    permitted dual-axis use is rad/s–rpm of the same quantity).
    axis='x' twins the x-axis (P(ω) plots); axis='y' twins the y-axis
    (only if ω is on y). Twinning a power/force axis is a standards violation."""
    _RPM_PER_RADPS = 60.0 / (2.0 * math.pi)  # bound at call time, not draw time
    funcs = (lambda v, c=_RPM_PER_RADPS: v * c,
             lambda v, c=_RPM_PER_RADPS: v / c)
    if axis == "x":
        secax = ax.secondary_xaxis('top', functions=funcs)
        secax.set_xlabel("ω (rpm)")
    else:
        secax = ax.secondary_yaxis('right', functions=funcs)
        secax.set_ylabel("ω (rpm)")
    return secax

def get_design_color(design_name):
    """Global design hue lookup. Raises on unknown designs — a silent fallback
    color would violate the fixed-hue rule (PRD: one design, one hue, everywhere)."""
    name = str(design_name)
    if name not in spec["designs"]:
        raise KeyError(f"Design '{name}' not in chart-spec.toml [designs]. "
                       f"Known: {', '.join(spec['designs'])}")
    return spec["designs"][name]

def get_threshold_color(threshold_type):
    return spec["thresholds"].get(str(threshold_type), "#000000")

def get_confidence_style(tier):
    tier_str = str(tier).upper()
    t = spec["confidence"][tier_str]
    
    # Map TOML line style names to matplotlib line styles
    ls_map = {"solid": "-", "dashed": "--", "dotted": ":", "dashdot": "-."}
    
    style = {
        "linestyle": ls_map.get(t["linestyle"], "-"),
        "marker": t["marker"],
    }
    
    if "color" in t:
        style["color"] = t["color"]
        
    # Map fills
    if t.get("fill") == "none":
        style["markerfacecolor"] = "none"
    elif t.get("fill") == "left":
        style["markerfacecoloralt"] = "white"
        style["fillstyle"] = "left"
    else:
        style["markerfacecolor"] = None # default full
        
    return style
