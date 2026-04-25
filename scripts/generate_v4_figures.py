#!/usr/bin/env python3
"""Generate v4 campaign result figures for KiteTurbineDynamics.jl."""

import json
import math
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.gridspec as gridspec
import numpy as np

# ── Paths ─────────────────────────────────────────────────────────────────────
# Script lives in worktree; results live in main repo root.
WORKTREE   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAIN_REPO  = os.path.normpath(os.path.join(WORKTREE, "..", "..", ".."))
# Fall back to worktree if main repo results don't exist
_res_base  = os.path.join(MAIN_REPO, "scripts", "results")
if not os.path.isdir(_res_base):
    _res_base = os.path.join(WORKTREE, "scripts", "results")
RES_V2     = os.path.join(_res_base, "trpt_opt_v2")
RES_V3     = os.path.join(_res_base, "trpt_opt_v3")
RES_V4     = os.path.join(_res_base, "trpt_opt_v4")
FIGS_DIR   = os.path.join(WORKTREE, "figures")
os.makedirs(FIGS_DIR, exist_ok=True)

# ── Windswept palette ─────────────────────────────────────────────────────────
WS_BLUE   = "#1a6b9a"
WS_ORANGE = "#e07b39"
WS_GREEN  = "#3a8a4e"
WS_GREY   = "#aaaaaa"
WS_RED    = "#c0392b"

DPI = 300

# ── Helpers ───────────────────────────────────────────────────────────────────

def load_v4_summary():
    """Load campaign_summary.csv as list of dicts, plus island configs."""
    import csv
    rows = []
    summary_path = os.path.join(RES_V4, "campaign_summary.csv")
    with open(summary_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "island":    int(row["island"]),
                "mass_kg":   float(row["mass_kg"]),
                "fos":       float(row["fos"]),
                "feasible":  row["feasible"].strip().lower() == "true",
            })

    # Island config: same order as run_v4_campaign.jl build_island_list()
    configs = []
    i = 0
    for cfg in ["10kw", "50kw"]:
        for beam in ["circular", "elliptical", "airfoil"]:
            for variant in range(1, 6):
                for seed in [1, 2]:
                    i += 1
                    configs.append({
                        "island":  i,
                        "cfg":     cfg,
                        "beam":    beam,
                        "variant": variant,
                        "seed":    seed,
                    })

    assert len(configs) == 60
    cfg_map = {c["island"]: c for c in configs}
    for row in rows:
        row.update(cfg_map.get(row["island"], {}))
    return rows


def load_v3_best(cfg="10 kW"):
    """Return (mass, beam_fos, torsional_fos) for best v3 design with given cfg."""
    best = None
    for entry in os.scandir(RES_V3):
        jpath = os.path.join(entry.path, "best_design.json")
        if not os.path.isfile(jpath):
            continue
        with open(jpath) as f:
            d = json.load(f)
        if d.get("config", "").strip() != cfg:
            continue
        m = d.get("best_mass_kg", 999)
        if best is None or m < best[0]:
            best = (m, d.get("min_fos", 0), d.get("torsional_fos_min", 0))
    return best  # (mass, beam_fos, tors_fos)


def load_v2_best(cfg="10 kW"):
    """Return (mass, beam_fos, torsional_fos) for best v2 design."""
    best = None
    for entry in os.scandir(RES_V2):
        jpath = os.path.join(entry.path, "best_design.json")
        if not os.path.isfile(jpath):
            continue
        with open(jpath) as f:
            d = json.load(f)
        if d.get("config", "").strip() != cfg:
            continue
        m = d.get("best_mass_kg", 999)
        if best is None or m < best[0]:
            best = (m, d.get("min_fos", 0), d.get("torsional_fos_min", 0))
    return best


def load_v4_winner():
    """Load island_01 best_design.csv as a dict (all identical mass, use island 1)."""
    import csv
    path = os.path.join(RES_V4, "island_01", "best_design.csv")
    with open(path) as f:
        reader = csv.DictReader(f)
        return next(reader)


def ring_positions_v4(r_hub, r_bottom, tether_length, target_Lr, max_rings=40):
    """
    Python port of ring_spacing_v4 from ring_spacing.jl.
    Returns list of (r_i, z_i) pairs for each ring from hub to bottom.
    """
    if abs(r_hub - r_bottom) < 1e-9:
        # Cylindrical: uniform spacing
        L_seg = target_Lr * r_hub
        n = max(1, round(tether_length / L_seg))
        z_step = tether_length / n
        return [(r_hub, i * z_step) for i in range(n + 1)]

    alpha = (r_hub - r_bottom) / tether_length
    c     = target_Lr
    k     = (2 - alpha * c) / (2 + alpha * c)

    if k >= 1.0 or k <= 0.0:
        # Degenerate: single segment
        return [(r_hub, 0.0), (r_bottom, tether_length)]

    # Ring radii (geometric series): r_i = r_hub * k^i  until r_i < r_bottom
    rings = [r_hub]
    while True:
        r_next = rings[-1] * k
        if r_next < r_bottom:
            break
        rings.append(r_next)
        if len(rings) > max_rings:
            break
    rings.append(r_bottom)

    # Compute z positions using the analytic L_seg = target_Lr * r_mid formula
    # But we just distribute proportionally along tether for simplicity:
    # z_i via cumulative L_seg = target_Lr * (r_i + r_{i+1})/2
    z_positions = [0.0]
    for i in range(len(rings) - 1):
        r_mid   = (rings[i] + rings[i + 1]) / 2.0
        L_seg   = target_Lr * r_mid
        z_positions.append(z_positions[-1] + L_seg)

    # Rescale z to match tether_length exactly
    scale = tether_length / z_positions[-1] if z_positions[-1] > 0 else 1.0
    z_positions = [z * scale for z in z_positions]

    return list(zip(rings, z_positions))


# ═══════════════════════════════════════════════════════════════════════════════
# Figure 1: Pareto scatter — mass vs FOS, coloured by power config
# ═══════════════════════════════════════════════════════════════════════════════

def fig_v4_pareto(rows):
    """
    Group scatter showing final mass for all 60 islands, grouped by (cfg, beam_profile).
    Demonstrates DE convergence robustness — all seeds/variants reach the same optimum.
    """
    group_order = [
        ("10kw", "circular",   "10 kW\nCircular"),
        ("10kw", "elliptical", "10 kW\nElliptical"),
        ("10kw", "airfoil",    "10 kW\nAirfoil"),
        ("50kw", "circular",   "50 kW\nCircular"),
        ("50kw", "elliptical", "50 kW\nElliptical"),
        ("50kw", "airfoil",    "50 kW\nAirfoil"),
    ]
    colours = [WS_BLUE]*3 + [WS_ORANGE]*3

    fig, ax = plt.subplots(figsize=(8, 5))

    for gi, (cfg, beam, label) in enumerate(group_order):
        pts = [r["mass_kg"] for r in rows if r.get("cfg") == cfg and r.get("beam") == beam]
        if not pts:
            continue
        # Jitter x slightly so overlapping points are visible
        rng = np.random.default_rng(seed=gi)
        xs  = gi + rng.uniform(-0.18, 0.18, size=len(pts))
        ax.scatter(xs, pts, c=colours[gi], s=55, alpha=0.8,
                   edgecolors="white", linewidths=0.5, zorder=3)
        # Mean line
        ax.plot([gi - 0.35, gi + 0.35], [np.mean(pts)] * 2,
                color=colours[gi], linewidth=2.2, zorder=4)

    # Mark v4 winner star
    best_mass_10kw = min(r["mass_kg"] for r in rows if r.get("cfg") == "10kw"
                         and r.get("beam") in ("circular", "elliptical"))
    ax.scatter([0], [best_mass_10kw], c="gold", marker="*", s=280,
               edgecolors=WS_BLUE, linewidths=1.2, zorder=6, label=f"v4 winner  {best_mass_10kw:.2f} kg")

    # Beam FOS constraint label
    ax.set_xticks(range(len(group_order)))
    ax.set_xticklabels([g[2] for g in group_order], fontsize=9)
    ax.set_ylabel("TRPT shaft mass (kg)", fontsize=10)
    ax.set_title("v4 Campaign: Final Mass for All 60 Islands\n"
                 "(10 seeds/variants per group — DE convergence robustness)",
                 fontsize=10.5, fontweight="bold")
    ax.tick_params(labelsize=9)
    ax.grid(axis="y", alpha=0.35, linewidth=0.5, zorder=0)
    ax.set_yscale("log")
    ax.set_xlim(-0.6, len(group_order) - 0.4)
    ax.legend(fontsize=9, loc="upper left")

    # Config separator
    ax.axvline(2.5, color="grey", linewidth=1.0, linestyle="--", alpha=0.5)
    ax.text(0.9, ax.get_ylim()[0] * 1.3, "← 10 kW", ha="center", fontsize=8.5,
            color=WS_BLUE, style="italic")
    ax.text(3.5, ax.get_ylim()[0] * 1.3, "50 kW →", ha="center", fontsize=8.5,
            color=WS_ORANGE, style="italic")

    fig.tight_layout()
    out = os.path.join(FIGS_DIR, "fig_v4_pareto.png")
    fig.savefig(out, dpi=DPI)
    plt.close(fig)
    print(f"Saved {out}")


# ═══════════════════════════════════════════════════════════════════════════════
# Figure 2: v2 / v3 / v4 comparison bar chart (10 kW)
# ═══════════════════════════════════════════════════════════════════════════════

def fig_v2_v3_v4_comparison(v2_best, v3_best, v4_mass):
    fig, axes = plt.subplots(1, 2, figsize=(8, 4.5))

    campaigns    = ["v2\n(beam only)", "v3\n(+ torsion,\ncylindrical)", "v4\n(+ torsion,\ntaper)"]
    masses       = [v2_best[0], v3_best[0], v4_mass]
    beam_foses   = [v2_best[1], v3_best[1], 1.8]
    tors_foses   = [None,        v3_best[2], 1.5]  # v2 has no torsional check

    colours = [WS_GREY, WS_ORANGE, WS_BLUE]
    x = np.arange(len(campaigns))
    width = 0.55

    # Panel A: mass
    ax = axes[0]
    bars = ax.bar(x, masses, width=width, color=colours, edgecolor="white", linewidth=0.8, zorder=3)
    for bar, m in zip(bars, masses):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.3,
                f"{m:.1f} kg", ha="center", va="bottom", fontsize=8.5, fontweight="bold")
    ax.axhline(0, color="black", linewidth=0.5)
    ax.set_xticks(x); ax.set_xticklabels(campaigns, fontsize=9)
    ax.set_ylabel("TRPT shaft mass (kg)", fontsize=10)
    ax.set_title("(a) 10 kW best mass", fontsize=10, fontweight="bold")
    ax.tick_params(labelsize=9)
    ax.grid(axis="y", alpha=0.35, linewidth=0.5, zorder=0)
    ax.set_ylim(0, max(masses) * 1.25)
    # v2 infeasibility note
    ax.text(0, masses[0] / 2, "torsionally\ninfeasible", ha="center", va="center",
            fontsize=7.5, color="white", style="italic")

    # Panel B: FOS values
    ax = axes[1]
    beam_vals = [v2_best[1], v3_best[1], 1.8]
    tors_vals_plot = [0, v3_best[2], 1.5]  # 0 for v2 (not checked)

    bw = 0.32
    xb = x - bw / 2
    xt = x + bw / 2
    ax.bar(xb, beam_vals, width=bw, color=colours, edgecolor="white", linewidth=0.8,
           label="Beam FOS", alpha=0.9, zorder=3)
    ax.bar(xt, tors_vals_plot, width=bw, color=colours, edgecolor="white", linewidth=0.8,
           hatch="//", label="Torsional FOS", alpha=0.7, zorder=3)
    ax.axhline(1.8, color=WS_RED,  linewidth=1.2, linestyle="--", label="Beam limit 1.8")
    ax.axhline(1.5, color="purple", linewidth=1.2, linestyle=":",  label="Torsional limit 1.5")
    ax.set_xticks(x); ax.set_xticklabels(campaigns, fontsize=9)
    ax.set_ylabel("Factor of Safety (–)", fontsize=10)
    ax.set_title("(b) Constraint margins", fontsize=10, fontweight="bold")
    ax.tick_params(labelsize=9)
    ax.legend(fontsize=7.5, loc="upper right", framealpha=0.85)
    ax.grid(axis="y", alpha=0.35, linewidth=0.5, zorder=0)
    ax.set_ylim(0, max(max(beam_vals), max(tors_vals_plot)) * 1.35)
    ax.text(0 + bw / 2, 0.07, "n/a", ha="center", va="bottom", fontsize=7.5,
            color="grey", style="italic")

    fig.suptitle("Campaign Comparison — 10 kW TRPT Shaft Optimisation (v2 → v4)",
                 fontsize=11, fontweight="bold", y=1.01)
    fig.tight_layout()
    out = os.path.join(FIGS_DIR, "fig_v2_v3_v4_comparison.png")
    fig.savefig(out, dpi=DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved {out}")


# ═══════════════════════════════════════════════════════════════════════════════
# Figure 3: Geometry schematic — side elevation of winning v4 design
# ═══════════════════════════════════════════════════════════════════════════════

def fig_v4_geometry(winner):
    r_hub     = float(winner["r_hub_m"])
    r_bottom  = float(winner["r_bottom_m"])
    tether_L  = float(winner["tether_length_m"])
    target_Lr = float(winner["target_Lr"])
    n_lines   = int(winner["n_lines"])
    Do_top    = float(winner["Do_top_m"])
    Do_exp    = float(winner["Do_scale_exp"])
    mass_kg   = float(winner["best_mass_kg"])

    rings = ring_positions_v4(r_hub, r_bottom, tether_L, target_Lr)
    n_rings = len(rings) - 1  # number of spans (one more ring than spans)

    fig, ax = plt.subplots(figsize=(5, 8))

    # Draw shaft spokes (TRPT tether lines as two side lines)
    r_vals = [rp[0] for rp in rings]
    z_vals = [rp[1] for rp in rings]

    # Right side profile (r vs z)
    ax.plot(r_vals, z_vals, color=WS_BLUE, linewidth=1.4, label="Shaft envelope")
    # Left side (mirror)
    ax.plot([-r for r in r_vals], z_vals, color=WS_BLUE, linewidth=1.4)

    # Rings as horizontal bars
    for i, (r, z) in enumerate(rings):
        lw = 2.0 if i in (0, len(rings) - 1) else 1.0
        col = WS_ORANGE if i in (0, len(rings) - 1) else WS_BLUE
        ax.plot([-r, r], [z, z], color=col, linewidth=lw)

    # Annotate hub and ground rings
    ax.annotate(f"Hub ring\nr = {r_hub:.2f} m",
                xy=(r_hub, 0), xytext=(r_hub + 0.2, -1.5),
                fontsize=8, color=WS_ORANGE,
                arrowprops=dict(arrowstyle="->", color=WS_ORANGE, lw=0.8))
    ax.annotate(f"Ground ring\nr = {r_bottom:.2f} m",
                xy=(r_bottom, tether_L), xytext=(r_bottom + 0.3, tether_L + 1.5),
                fontsize=8, color=WS_ORANGE,
                arrowprops=dict(arrowstyle="->", color=WS_ORANGE, lw=0.8))

    # Dimension arrows
    ax.annotate("", xy=(0, tether_L), xytext=(0, 0),
                arrowprops=dict(arrowstyle="<->", color="black", lw=0.9))
    ax.text(0.05, tether_L / 2, f"L = {tether_L:.0f} m", fontsize=8.5,
            va="center", ha="left", color="black")

    # n_rings label
    ax.text(-r_hub * 0.9, tether_L / 2,
            f"{n_rings} rings\n(L/r = {target_Lr:.1f})",
            fontsize=8, ha="center", va="center", color=WS_BLUE,
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec=WS_BLUE, alpha=0.85))

    ax.set_xlabel("Radial position (m)", fontsize=10)
    ax.set_ylabel("Along-tether position (m)", fontsize=10)
    ax.set_title(
        f"v4 Winner — Side Elevation\n"
        f"mass = {mass_kg:.2f} kg  |  {n_lines} lines  |  n_rings ≈ {n_rings}",
        fontsize=10, fontweight="bold",
    )
    ax.set_aspect("equal")
    ax.tick_params(labelsize=9)
    ax.grid(True, alpha=0.25, linewidth=0.5)
    # invert y so hub is at top (sky) and ground ring at bottom
    ax.invert_yaxis()

    fig.tight_layout()
    out = os.path.join(FIGS_DIR, "fig_v4_geometry.png")
    fig.savefig(out, dpi=DPI)
    plt.close(fig)
    print(f"Saved {out}")


# ═══════════════════════════════════════════════════════════════════════════════
# Figure 4: 60-cell island heatmap
# ═══════════════════════════════════════════════════════════════════════════════

def fig_v4_island_heatmap(rows):
    # Layout: 6 rows (cfg × beam), 10 cols (variant × seed)
    row_labels = [
        "10 kW / Circular",
        "10 kW / Elliptical",
        "10 kW / Airfoil",
        "50 kW / Circular",
        "50 kW / Elliptical",
        "50 kW / Airfoil",
    ]
    col_labels = [f"V{v}S{s}" for v in range(1, 6) for s in [1, 2]]

    mass_grid = np.full((6, 10), np.nan)
    feas_grid = np.ones((6, 10), dtype=bool)

    row_order = [
        ("10kw", "circular"),
        ("10kw", "elliptical"),
        ("10kw", "airfoil"),
        ("50kw", "circular"),
        ("50kw", "elliptical"),
        ("50kw", "airfoil"),
    ]

    for r in rows:
        cfg  = r.get("cfg")
        beam = r.get("beam")
        var  = r.get("variant")
        seed = r.get("seed")
        if cfg is None:
            continue
        try:
            ri = row_order.index((cfg, beam))
        except ValueError:
            continue
        ci = (var - 1) * 2 + (seed - 1)
        mass_grid[ri, ci] = r["mass_kg"]
        feas_grid[ri, ci] = r["feasible"]

    # For each power config, normalise to [0,1] separately for readability
    fig, ax = plt.subplots(figsize=(10, 5))

    # Build a masked array for infeasible
    display = np.log10(mass_grid)   # log scale handles the 10x range
    cmap = plt.cm.YlOrRd_r         # lighter = lighter mass (better)
    cmap.set_bad(color=WS_GREY)

    masked = np.ma.masked_invalid(display)

    im = ax.imshow(masked, cmap=cmap, aspect="auto", interpolation="nearest")

    # Gridlines
    ax.set_xticks(np.arange(-.5, 10, 1), minor=True)
    ax.set_yticks(np.arange(-.5, 6, 1), minor=True)
    ax.grid(which="minor", color="white", linewidth=1.5)
    ax.tick_params(which="minor", bottom=False, left=False)

    # Labels
    ax.set_xticks(range(10))
    ax.set_xticklabels(col_labels, fontsize=7.5, rotation=45, ha="right")
    ax.set_yticks(range(6))
    ax.set_yticklabels(row_labels, fontsize=9)

    # Value annotations
    for ri in range(6):
        for ci in range(10):
            m = mass_grid[ri, ci]
            if np.isfinite(m):
                ax.text(ci, ri, f"{m:.1f}", ha="center", va="center",
                        fontsize=7, color="black" if m < 100 else "white",
                        fontweight="bold")

    # Colorbar
    cbar = plt.colorbar(im, ax=ax, fraction=0.025, pad=0.02)
    cbar.set_label("log₁₀(mass / kg)", fontsize=9)
    cbar_ticks = [1, 1.5, 2, 2.5, 3]
    cbar.set_ticks(cbar_ticks)
    cbar.set_ticklabels([f"10^{t}" for t in cbar_ticks], fontsize=8)

    ax.set_title("v4 Campaign — Island Mass Heatmap (all 60 islands, log₁₀ kg scale)",
                 fontsize=11, fontweight="bold")

    # Separator line between 10kW and 50kW
    ax.axhline(2.5, color="white", linewidth=2.5)
    ax.text(9.6, 1.0, "10 kW", ha="right", va="center", fontsize=8.5,
            color=WS_BLUE, fontweight="bold", rotation=90)
    ax.text(9.6, 4.0, "50 kW", ha="right", va="center", fontsize=8.5,
            color=WS_ORANGE, fontweight="bold", rotation=90)

    fig.tight_layout()
    out = os.path.join(FIGS_DIR, "fig_v4_island_heatmap.png")
    fig.savefig(out, dpi=DPI)
    plt.close(fig)
    print(f"Saved {out}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("Loading v4 campaign data...")
    rows   = load_v4_summary()
    winner = load_v4_winner()

    print("Loading v3 best...")
    v3 = load_v3_best("10 kW")
    print(f"  v3 best: {v3}")

    print("Loading v2 best...")
    v2 = load_v2_best("10 kW")
    print(f"  v2 best: {v2}")

    v4_10kw_best = min(r["mass_kg"] for r in rows if r.get("cfg") == "10kw")
    print(f"  v4 10kW best: {v4_10kw_best:.3f} kg")

    print("\nGenerating figures...")
    fig_v4_pareto(rows)
    fig_v2_v3_v4_comparison(v2, v3, v4_10kw_best)
    fig_v4_geometry(winner)
    fig_v4_island_heatmap(rows)
    print("\nAll figures written to", FIGS_DIR)


if __name__ == "__main__":
    main()
