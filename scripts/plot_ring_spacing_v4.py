"""
scripts/plot_ring_spacing_v4.py
Publication-quality figures for the v4 constant-L/r ring spacing formulation.

Produces three figure files saved to figures/:
  fig_v4_ring_spacing_concept.png  — v3 (uniform) vs v4 (constant L/r) side-elevation
  fig_v4_Lr_sweep.png              — n_rings, beam mass, worst FoS vs target_Lr
  fig_v4_taper_heatmap.png         — total beam mass vs (r_bottom, target_Lr)

Run from the repository root:
  python scripts/plot_ring_spacing_v4.py
"""

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.collections import LineCollection
from pathlib import Path
import warnings

warnings.filterwarnings("ignore")
FIGURES_DIR = Path(__file__).parent.parent / "figures"
FIGURES_DIR.mkdir(exist_ok=True)

# ── Physical / optimiser constants (mirror src/ring_spacing.jl) ───────────────
RHO_AIR     = 1.225      # kg/m³
RHO_CFRP    = 1600.0     # kg/m³
E_CFRP      = 70e9       # Pa
T_MIN_WALL  = 5e-4       # m
V_PEAK      = 25.0       # m/s
CT_PEAK     = 1.0
DLF         = 1.2
KNUCKLE_KG  = 0.050      # kg per vertex

# 10 kW reference system
R_HUB       = 2.0        # m
TETHER_L    = 30.0       # m
R_ROTOR     = 5.0        # m
ELEV_ANGLE  = np.pi / 6
N_LINES     = 5
DO_TOP      = 0.040      # m  (reference beam OD at hub)
DO_SCALE    = 0.5        # Do(r) = Do_top * (r/r_hub)^exp
T_OVER_D    = 0.05


# ── Core geometry function ─────────────────────────────────────────────────────
def ring_spacing_v4(r_top, r_bottom, tether_length, target_Lr, max_rings=50):
    """Return (z_positions, radii) in ground-first order."""
    if (r_top - r_bottom) / r_top < 1e-9:
        # Cylindrical
        L_seg  = target_Lr * r_top
        n_segs = max(1, round(tether_length / L_seg))
        n_segs = min(n_segs, max_rings + 1)
        zs = np.linspace(0.0, tether_length, n_segs + 1)
        rs = np.full(n_segs + 1, r_top)
        return zs, rs

    alpha     = (r_top - r_bottom) / tether_length
    c         = target_Lr
    k_natural = (2.0 - alpha * c) / (2.0 + alpha * c)
    if k_natural <= 0:
        return np.array([0.0, tether_length]), np.array([r_bottom, r_top])

    n_natural = np.log(r_bottom / r_top) / np.log(k_natural)
    n_segs    = int(np.clip(round(n_natural), 1, max_rings + 1))
    k         = (r_bottom / r_top) ** (1.0 / n_segs)

    radii_down    = r_top * k ** np.arange(n_segs + 1)
    radii_down[-1] = r_bottom
    z_down          = (radii_down - r_bottom) / alpha
    z_down[0]       = tether_length
    z_down[-1]      = 0.0
    return z_down[::-1].copy(), radii_down[::-1].copy()


# ── Uniform spacing (v3 style) ─────────────────────────────────────────────────
def ring_spacing_v3(r_top, r_bottom, tether_length, n_segs):
    """Uniform axial spacing, linear taper in r — matches v2/v3 behaviour."""
    zs = np.linspace(0.0, tether_length, n_segs + 1)
    rs = r_bottom + (r_top - r_bottom) * zs / tether_length
    return zs, rs


# ── Beam cross-section (hollow circular) ──────────────────────────────────────
def beam_section(Do, t_over_D):
    t  = max(t_over_D * Do, T_MIN_WALL)
    Di = max(Do - 2 * t, 0.0)
    A  = np.pi / 4 * (Do**2 - Di**2)
    I  = np.pi / 64 * (Do**4 - Di**4)
    return A, I


def Do_at_r(r, r_hub=R_HUB, Do_top=DO_TOP, exp=DO_SCALE):
    return Do_top * (r / r_hub) ** exp


# ── Structural evaluation (simplified, circular hollow beam) ──────────────────
def evaluate(zs, rs, n_lines=N_LINES, r_rotor=R_ROTOR, elev=ELEV_ANGLE,
             omega=4.1 * V_PEAK / R_ROTOR):
    """
    Returns dict with: mass_beams_kg, fos_per_ring (finite only), min_fos.
    Mirrors evaluate_design() in ring_spacing.jl.
    """
    L_seg = np.diff(zs)
    n_tot = len(rs)
    n_seg = len(L_seg)

    T_peak       = 0.5 * RHO_AIR * V_PEAK**2 * np.pi * r_rotor**2 * CT_PEAK * np.cos(elev)**2
    T_line_axial = T_peak / n_lines

    mass_beams  = 0.0
    fos_finite  = []

    for i, r in enumerate(rs):
        Do  = Do_at_r(r)
        A, I = beam_section(Do, T_OVER_D)
        L_poly = 2 * r * np.sin(np.pi / n_lines)

        # Line tension
        LL_below = (np.sqrt(L_seg[i-1]**2 + (rs[i] - rs[i-1])**2)
                    if i > 0 else L_seg[0])
        LL_above = (np.sqrt(L_seg[i]**2   + (rs[i+1] - rs[i])**2)
                    if i < n_tot - 1 else L_seg[-1])
        Lseg_min = min(L_seg[max(i-1,0)], L_seg[min(i, n_seg-1)])
        T_line   = T_line_axial * max(LL_below, LL_above) / Lseg_min

        F_in   = DLF * T_line
        m_beam = RHO_CFRP * A * L_poly
        m_vtx  = KNUCKLE_KG + m_beam
        F_c    = m_vtx * omega**2 * r
        F_v    = max(F_in - F_c, 0.0)
        N_comp = F_v / (2 * np.tan(np.pi / n_lines))
        P_crit = np.pi**2 * E_CFRP * I / max(L_poly, 1e-12)**2

        # Intermediate rings only for FoS
        if 0 < i < n_tot - 1 and N_comp > 0:
            fos_finite.append(P_crit / N_comp)

        mass_beams += n_lines * RHO_CFRP * A * L_poly

    fos_arr = np.array(fos_finite) if fos_finite else np.array([np.inf])
    return {
        "mass_beams_kg": mass_beams,
        "fos_per_ring":  fos_arr,
        "min_fos":       fos_arr.min() if len(fos_arr) > 0 else np.inf,
        "n_segs":        n_seg,
    }


# ══════════════════════════════════════════════════════════════════════════════
# Figure 1 — Concept diagram: v3 (uniform) vs v4 (constant L/r)
# ══════════════════════════════════════════════════════════════════════════════
def fig_concept():
    r_top = R_HUB
    r_bot = 0.55
    L     = TETHER_L
    c_v4  = 1.0   # target_Lr for v4

    # Both cases use same ring count for the v3 case
    zs4, rs4 = ring_spacing_v4(r_top, r_bot, L, c_v4, max_rings=40)
    n_segs   = len(zs4) - 1
    zs3, rs3 = ring_spacing_v3(r_top, r_bot, L, n_segs)

    Lr4 = [(zs4[i+1]-zs4[i]) / ((rs4[i]+rs4[i+1])/2) for i in range(n_segs)]
    Lr3 = [(zs3[i+1]-zs3[i]) / ((rs3[i]+rs3[i+1])/2) for i in range(n_segs)]

    fig, axes = plt.subplots(1, 2, figsize=(11, 8))
    fig.patch.set_facecolor("white")

    cmap = plt.cm.RdYlGn
    Lr_min = min(min(Lr3), min(Lr4)) * 0.95
    Lr_max = max(max(Lr3), max(Lr4)) * 1.05

    def draw_trpt(ax, zs, rs, Lr_vals, title):
        ax.set_aspect("equal")
        ax.set_facecolor("white")
        n = len(zs)

        # Draw ring frames as horizontal ellipses
        for i, (z, r) in enumerate(zip(zs, rs)):
            ellipse = mpatches.Ellipse((z, 0), width=r*0.15, height=r*2,
                                        linewidth=1.5, edgecolor="#1a4e7a",
                                        facecolor="#d0e8f5", zorder=3)
            ax.add_patch(ellipse)

        # Colour each segment by L/r
        norm = plt.Normalize(Lr_min, Lr_max)
        for i in range(n - 1):
            colour = cmap(norm(Lr_vals[i]))
            z0, z1 = zs[i], zs[i+1]
            r0, r1 = rs[i], rs[i+1]
            # Upper and lower tether lines
            ax.plot([z0, z1], [ r0,  r1], color=colour, lw=3.5, zorder=2)
            ax.plot([z0, z1], [-r0, -r1], color=colour, lw=3.5, zorder=2)
            # Annotate with L/r value at segment midpoint
            z_mid = (z0 + z1) / 2
            r_mid = (r0 + r1) / 2
            ax.text(z_mid, r_mid + 0.18,
                    f"L/r={Lr_vals[i]:.2f}",
                    ha="center", va="bottom", fontsize=6.5, color="#333333", zorder=5)

        # Dimension annotations
        ax.annotate("", xy=(L, 0), xytext=(0, 0),
                    arrowprops=dict(arrowstyle="<->", color="#555555", lw=1.2))
        ax.text(L/2, -0.12, f"L = {L:.0f} m", ha="center", va="top",
                fontsize=9, color="#555555")
        ax.text(0,  rs[0] + 0.05, f"r_bot={rs[0]:.2f} m",
                ha="center", va="bottom", fontsize=8, color="#1a4e7a")
        ax.text(L, rs[-1] + 0.05, f"r_hub={rs[-1]:.2f} m",
                ha="center", va="bottom", fontsize=8, color="#1a4e7a")

        ax.set_xlim(-1, L + 1)
        ax.set_ylim(-r_top - 0.5, r_top + 0.6)
        ax.set_xlabel("Axial position z (m)", fontsize=10)
        ax.set_ylabel("Ring radius (m)", fontsize=10)
        ax.set_title(title, fontsize=11, fontweight="bold", pad=8)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

    draw_trpt(axes[0], zs3, rs3, Lr3,
              "v3 — Uniform axial spacing\n(L/r varies, thin rings over-stressed)")
    draw_trpt(axes[1], zs4, rs4, Lr4,
              "v4 — Constant L/r spacing\n(each segment equally loaded)")

    # Shared colourbar
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=plt.Normalize(Lr_min, Lr_max))
    sm.set_array([])
    cbar = fig.colorbar(sm, ax=axes, orientation="vertical",
                        fraction=0.025, pad=0.03)
    cbar.set_label("Segment L/r ratio", fontsize=10)

    fig.suptitle(
        "TRPT Ring Spacing: Uniform (v3) vs Constant L/r (v4)\n"
        "L/r ≈ constant → Euler buckling capacity uniform across all rings "
        "(Do ∝ r\u00b0\u22c5\u2075 scaling)",
        fontsize=11, y=1.01,
    )
    plt.tight_layout()
    out = FIGURES_DIR / "fig_v4_ring_spacing_concept.png"
    plt.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close()
    print(f"Saved {out}")


# ══════════════════════════════════════════════════════════════════════════════
# Figure 2 — L/r sweep: n_rings, mass, worst FoS vs target_Lr
# ══════════════════════════════════════════════════════════════════════════════
def fig_Lr_sweep():
    target_Lr_vals = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    colours        = plt.cm.viridis(np.linspace(0.15, 0.85, len(target_Lr_vals)))

    r_top = R_HUB
    r_bot = 0.6

    n_rings_list  = []
    mass_list     = []
    min_fos_list  = []
    Lr_actual_list = []

    for c in target_Lr_vals:
        zs, rs = ring_spacing_v4(r_top, r_bot, TETHER_L, c, max_rings=60)
        ev = evaluate(zs, rs)
        n_rings_list.append(len(zs) - 2)   # intermediate only
        mass_list.append(ev["mass_beams_kg"])
        min_fos_list.append(ev["min_fos"])
        n_s = len(zs) - 1
        Lr_segs = [(zs[i+1]-zs[i]) / ((rs[i]+rs[i+1])/2) for i in range(n_s)]
        Lr_actual_list.append(np.mean(Lr_segs))

    fig, axes = plt.subplots(1, 3, figsize=(13, 4.5))
    fig.patch.set_facecolor("white")

    markers = ["o", "s", "^", "D", "v", "P"]

    def add_panel(ax, yvals, ylabel, title):
        ax.set_facecolor("white")
        for i, (c, y, col, mk) in enumerate(
                zip(target_Lr_vals, yvals, colours, markers)):
            ax.plot(c, y, marker=mk, ms=9, color=col, zorder=4,
                    label=f"target_Lr={c:.2f}")
        ax.plot(target_Lr_vals, yvals, lw=1.5, color="#888888", zorder=2)
        ax.set_xlabel("Target L/r", fontsize=10)
        ax.set_ylabel(ylabel, fontsize=10)
        ax.set_title(title, fontsize=10, fontweight="bold")
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        ax.grid(axis="y", alpha=0.3)

    add_panel(axes[0], n_rings_list,
              "Intermediate ring count",
              "Fewer rings at larger L/r\n(wider spacing, more mass per segment)")
    add_panel(axes[1], mass_list,
              "Beam mass (kg)",
              "Mass vs L/r\n(lower L/r = more rings = more material)")
    add_panel(axes[2], min_fos_list,
              "Minimum FoS (worst ring)",
              "Structural safety vs L/r\n(lower L/r = stockier segments = higher FoS)")

    # Overlay actual vs target Lr on panel 1
    ax2 = axes[0].twinx()
    ax2.plot(target_Lr_vals, Lr_actual_list, "k--", lw=1.2, alpha=0.5,
             label="Actual L/r (after rounding)")
    ax2.set_ylabel("Actual L/r (dashed)", fontsize=8, color="0.5")
    ax2.tick_params(colors="0.5")
    ax2.spines["right"].set_color("0.5")

    fig.suptitle(
        "v4 L/r Sweep — r_top=2.0 m, r_bottom=0.6 m, L=30 m, 10 kW load case\n"
        "n_rings is an output of ring_spacing_v4; target_Lr trades ring count against mass",
        fontsize=10, y=1.03,
    )
    plt.tight_layout()
    out = FIGURES_DIR / "fig_v4_Lr_sweep.png"
    plt.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close()
    print(f"Saved {out}")


# ══════════════════════════════════════════════════════════════════════════════
# Figure 3 — Taper heatmap: beam mass vs (r_bottom, target_Lr)
# ══════════════════════════════════════════════════════════════════════════════
def fig_taper_heatmap():
    r_bot_vals = np.linspace(0.30, 1.50, 30)
    Lr_vals    = np.linspace(0.40, 2.00, 28)

    mass_grid    = np.full((len(Lr_vals), len(r_bot_vals)), np.nan)
    min_fos_grid = np.full_like(mass_grid, np.nan)

    for j, c in enumerate(Lr_vals):
        for i, r_bot in enumerate(r_bot_vals):
            if r_bot >= R_HUB:
                continue
            zs, rs = ring_spacing_v4(R_HUB, r_bot, TETHER_L, c, max_rings=60)
            ev = evaluate(zs, rs)
            mass_grid[j, i]    = ev["mass_beams_kg"]
            min_fos_grid[j, i] = ev["min_fos"]

    fig, axes = plt.subplots(1, 2, figsize=(13, 5))
    fig.patch.set_facecolor("white")

    def heatmap(ax, data, cmap, label, title, vmin=None, vmax=None):
        ax.set_facecolor("white")
        im = ax.imshow(
            data,
            aspect="auto",
            origin="lower",
            extent=[r_bot_vals[0], r_bot_vals[-1], Lr_vals[0], Lr_vals[-1]],
            cmap=cmap,
            vmin=vmin, vmax=vmax,
        )
        cbar = fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
        cbar.set_label(label, fontsize=9)
        ax.set_xlabel("Ground ring radius r_bottom (m)", fontsize=10)
        ax.set_ylabel("Target L/r", fontsize=10)
        ax.set_title(title, fontsize=10, fontweight="bold")
        return im

    heatmap(axes[0], mass_grid, "plasma_r",
            "Beam mass (kg)",
            "Beam mass vs (r_bottom, target_Lr)\n"
            "Mass ∝ r² → small ground ring, moderate L/r minimises mass")

    # Mask regions with min_fos < 1.0 (infeasible) for visual clarity
    fos_display = np.where(min_fos_grid < 0.5, np.nan, min_fos_grid)
    heatmap(axes[1], fos_display, "RdYlGn",
            "Min FoS (worst ring)",
            "Structural FoS vs (r_bottom, target_Lr)\n"
            "FoS < 1.8 (red) → infeasible; optimiser finds mass-minimum in green region",
            vmin=0.5, vmax=6.0)

    # FoS = 1.8 contour
    axes[1].contour(r_bot_vals, Lr_vals, min_fos_grid,
                    levels=[1.8], colors=["#000000"], linewidths=1.5,
                    linestyles=["--"])
    axes[1].text(0.75, 1.7, "FoS = 1.8\n(sizing limit)", fontsize=8,
                 color="black", ha="center")

    fig.suptitle(
        "v4 Design Space: r_top=2.0 m (10 kW hub), tether=30 m, circular beam, Do∝r⁰·⁵\n"
        "Constant L/r frees r_bottom and target_Lr as independent design variables",
        fontsize=10, y=1.02,
    )
    plt.tight_layout()
    out = FIGURES_DIR / "fig_v4_taper_heatmap.png"
    plt.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close()
    print(f"Saved {out}")


# ── Main ───────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Generating v4 ring spacing figures...")
    fig_concept()
    fig_Lr_sweep()
    fig_taper_heatmap()
    print("Done — all figures saved to figures/")
