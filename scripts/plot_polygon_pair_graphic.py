#!/usr/bin/env python3
"""scripts/plot_polygon_pair_graphic.py
Phase C direction: clear visual of how polygon count (n_lines = n_polygon_sides
= n_blades) reshapes the TRPT ring geometry and buckling load sharing.

Produces a single figure `fig_polygon_family.png` under
scripts/results/trpt_opt_v2/ with:
  Row 1 — top-down polygon overlays for n=3..8 at equal r_hub
  Row 2 — per-n side length L_poly = 2 r sin(π/n) vs n
  Row 3 — per-n vertex compressive load factor 1/(2 tan(π/n)) vs n
  Row 4 — per-n buckling-load ratio at fixed Do, fixed ρ·A·L mass budget
"""
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

REPO = Path(__file__).resolve().parent.parent
OUT  = REPO / "scripts" / "results" / "trpt_opt_v2"
OUT.mkdir(parents=True, exist_ok=True)
plt.style.use("dark_background")

NS = np.arange(3, 9)
R_HUB = 1.0
DO = 0.01396         # representative CFRP outer diameter (m)
E_CFRP = 70e9
RHO_CFRP = 1600.0

colors = plt.get_cmap("viridis")(np.linspace(0.15, 0.90, len(NS)))

fig = plt.figure(figsize=(14, 13), dpi=130)
gs = fig.add_gridspec(4, 6, hspace=0.55, wspace=0.6)

# ── Row 1: polygon overlays ────────────────────────────────────────────────
for i, n in enumerate(NS):
    ax = fig.add_subplot(gs[0, i])
    theta = np.linspace(0, 2*np.pi, n+1)
    x = R_HUB * np.cos(theta)
    y = R_HUB * np.sin(theta)
    ax.plot(x, y, lw=2.0, color=colors[i])
    ax.scatter(x[:-1], y[:-1], s=40, color=colors[i], zorder=3)
    # label
    ax.set_title(f"n = {n}", color="white", fontsize=11)
    ax.set_aspect("equal")
    ax.set_xticks([]); ax.set_yticks([])
    for spine in ax.spines.values():
        spine.set_color("grey")
    # light inscribed circle
    phi = np.linspace(0, 2*np.pi, 128)
    ax.plot(R_HUB*np.cos(phi), R_HUB*np.sin(phi), ":", color="grey",
            lw=0.6, alpha=0.6)

# ── Row 2: side length ─────────────────────────────────────────────────────
ax_l = fig.add_subplot(gs[1, :])
L_poly = 2 * R_HUB * np.sin(np.pi / NS)
ax_l.plot(NS, L_poly, "o-", color="#3DCFFF", lw=2.2)
for i, n in enumerate(NS):
    ax_l.annotate(f"L = {L_poly[i]:.3f} r", (n, L_poly[i]),
                  textcoords="offset points", xytext=(8, 8),
                  color="white", fontsize=9)
ax_l.set_xlabel("n  (polygon sides = tether lines = blades)")
ax_l.set_ylabel(r"$L_{poly}\,/\,r$  (dimensionless)")
ax_l.set_title("Polygon side length (per ring) vs n",
               color="white", pad=8)
ax_l.grid(alpha=0.3)
ax_l.set_xticks(NS)

# ── Row 3: vertex load sharing ─────────────────────────────────────────────
ax_c = fig.add_subplot(gs[2, :])
factor = 1.0 / (2 * np.tan(np.pi / NS))
ax_c.plot(NS, factor, "o-", color="#FFB840", lw=2.2)
for i, n in enumerate(NS):
    ax_c.annotate(f"{factor[i]:.3f}×", (n, factor[i]),
                  textcoords="offset points", xytext=(8, 8),
                  color="white", fontsize=9)
ax_c.set_xlabel("n")
ax_c.set_ylabel(r"$N_{comp}\,/\,F_v\;=\;\dfrac{1}{2\tan(\pi/n)}$")
ax_c.set_title("Per-vertex compression amplification factor vs n",
               color="white", pad=8)
ax_c.grid(alpha=0.3)
ax_c.set_xticks(NS)

# ── Row 4: buckling load vs fixed MASS budget ──────────────────────────────
# Hold total ring mass constant by adjusting Do. Compare Euler buckling load.
# Total mass per ring = n * ρ * A * L_poly (A ≈ π·Do·t for thin wall, t=0.05Do)
# P_crit_per_beam = π² E I / L_poly², I = π Do³ t / 8
# What matters for system safety is the MINIMUM P_crit across sides
# (not summed), since the weakest beam governs.
ax_p = fig.add_subplot(gs[3, :])
# Target total mass constant at n=5 reference:
t_over_D = 0.05
def A_of_Do(Do): return np.pi * Do * (t_over_D * Do)  # thin wall area
def I_of_Do(Do): return np.pi * Do**3 * (t_over_D * Do) / 8.0

Do_ref = DO
M_ref  = 5 * RHO_CFRP * A_of_Do(Do_ref) * (2 * R_HUB * np.sin(np.pi/5))

Pcrits = []
Do_used = []
for n in NS:
    L = 2 * R_HUB * np.sin(np.pi / n)
    # Solve n * RHO * A(Do) * L = M_ref for Do
    # A = π · Do · t_over_D · Do = π t_over_D Do²
    # → Do = sqrt(M_ref / (n · π · t_over_D · L · RHO))
    Do_n = np.sqrt(M_ref / (n * np.pi * t_over_D * L * RHO_CFRP))
    I = I_of_Do(Do_n)
    P = np.pi**2 * E_CFRP * I / L**2
    Pcrits.append(P)
    Do_used.append(Do_n)
Pcrits = np.array(Pcrits)

ax_p.plot(NS, Pcrits / 1000.0, "o-", color="#C97AFF", lw=2.2,
          label="P_crit per beam (kN)")
for i, n in enumerate(NS):
    ax_p.annotate(f"{Pcrits[i]/1000:.1f} kN\nDo={Do_used[i]*1000:.2f} mm",
                  (n, Pcrits[i]/1000),
                  textcoords="offset points", xytext=(8, 8),
                  color="white", fontsize=8)
ax_p.set_xlabel("n")
ax_p.set_ylabel("Euler buckling load per beam (kN)")
ax_p.set_title("P_crit per beam holding TOTAL RING MASS constant — "
               "trade of side length vs cross-section size",
               color="white", pad=8)
ax_p.grid(alpha=0.3)
ax_p.set_xticks(NS)

fig.suptitle(
    "Phase C — polygon family at fixed r_hub\n"
    "(n = n_lines = n_polygon_sides = n_blades; higher n = shorter sides, "
    "but thinner beams under equal mass)",
    color="white", fontsize=13, y=0.995,
)

out = OUT / "fig_polygon_family.png"
fig.savefig(out, facecolor=fig.get_facecolor(), bbox_inches="tight")
plt.close(fig)
print(f"wrote {out}")
