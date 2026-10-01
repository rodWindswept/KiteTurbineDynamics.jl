#!/usr/bin/env python3
"""Figure for the blade-count sweep.

One claim: the measured bank derate barely depends on blade count. A six-blade
rotor at matched solidity retains 0.876 at the Cp peak against the three-blade
0.854.
"""

import csv
import math
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
# Moved here 2026-10-01 from .scratch/bem_regression/precone_sweep (gitignored).
# In scripts/aerodyn_sweep/ the repo root is two levels up, not three.
REPO_ROOT = os.path.dirname(os.path.dirname(HERE))
# Working directory holding deck/ (generated AeroDyn inputs, ~94 MB) and results/.
# Defaults to the historical location so the existing sweep data still resolves.
# Override to reproduce the sweep somewhere else:
#     AERODYN_SWEEP_WORK=/tmp/sweep python3 scripts/aerodyn_sweep/run_sweep.py
WORK = os.environ.get(
    "AERODYN_SWEEP_WORK",
    os.path.join(REPO_ROOT, ".scratch", "bem_regression", "precone_sweep"),
)
BC = os.path.join(WORK, "results", "bladecount.csv")
BASE = os.path.join(REPO_ROOT, "docs", "validation",
                    "trpt-reference", "10-precone-sweep.csv")
OUT = os.path.join(WORK, "results", "blade_count_sweep.png")

TSRS = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]


def load(path, variant=None, kind=None):
    out = {}
    with open(path) as fh:
        body = [ln for ln in fh if not ln.lstrip().startswith("#")]
    for r in csv.DictReader(body):
        if variant and r.get("variant") != variant:
            continue
        if kind and r.get("kind") != kind:
            continue
        out[(float(r["angle_deg"]), float(r["tsr_set"]))] = float(r["Cp"])
    return out


base3 = load(BASE, kind="precone")
b6s = load(BC, variant="b6c050")
b6f = load(BC, variant="b6c100")

SERIES = [
    ("3 blades, chord 0.500 m", base3, "#1f6fb4", "o", "-"),
    ("6 blades, chord 0.250 m (matched solidity)", b6s, "#2e8b57", "s", "-"),
    ("6 blades, chord 0.500 m (doubled solidity)", b6f, "#c0504d", "^", "--"),
]

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13.5, 5.4))

# --- Panel A: the Cp curves at zero bank ------------------------------------
for label, d, col, mk, ls in SERIES:
    xs = [t for t in TSRS if (0.0, t) in d]
    ys = [d[(0.0, t)] for t in xs]
    ax1.plot(xs, ys, marker=mk, ls=ls, color=col, ms=5.5, lw=1.8, label=label)
    pk = max(xs, key=lambda t: d[(0.0, t)])
    ax1.annotate(f"peak {d[(0.0, pk)]:.3f}\nat $\\lambda$={pk:.0f}",
                 xy=(pk, d[(0.0, pk)]), xytext=(pk + 0.15, d[(0.0, pk)] + 0.045),
                 fontsize=8, color=col)

ax1.axhline(0, color="0.6", lw=0.8, ls=":")
ax1.set_xlabel("commanded tip-speed ratio  $\\lambda$  (-)")
ax1.set_ylabel("rotor power coefficient  $C_P$  (-)")
ax1.set_title("A. Blade count and solidity move the $C_P$ curve, and its peak",
              fontsize=11)
ax1.grid(alpha=0.25)
ax1.legend(fontsize=8, loc="lower left")

# --- Panel B: the 20 deg retention, each against its own curve --------------
for label, d, col, mk, ls in SERIES:
    xs, ys = [], []
    for t in TSRS:
        z, v = d.get((0.0, t)), d.get((20.0, t))
        if z and z > 0 and v is not None:
            xs.append(t)
            ys.append(v / z)
    ax2.plot(xs, ys, marker=mk, ls=ls, color=col, ms=5.5, lw=1.8, label=label)

lam = [2 + 0.05 * i for i in range(0, 101)]
ax2.plot(lam, [math.cos(math.radians(20)) ** 2.65 for _ in lam], ":",
         color="0.25", lw=2.0, label="$\\cos^{2.65}(20°)$ = 0.848, the rule")

ax2.set_xlabel("commanded tip-speed ratio  $\\lambda$  (-)")
ax2.set_ylabel("$C_P$(20° bank) / $C_P$(0°)  (-)")
ax2.set_title("B. At 20° bank the three curves agree near the peak", fontsize=11)
ax2.grid(alpha=0.25)
ax2.legend(fontsize=8, loc="lower left")
ax2.set_ylim(-0.05, 1.12)
LABEL_OFFSET = {
    "3 blades, chord 0.500 m": (0.22, -0.075),
    "6 blades, chord 0.250 m (matched solidity)": (0.22, 0.030),
    "6 blades, chord 0.500 m (doubled solidity)": (0.22, -0.075),
}
for label, d, col, mk, ls in SERIES:
    lam0 = [t for t in TSRS if (0.0, t) in d and d[(0.0, t)] > 0]
    if not lam0:
        continue
    pk = max(lam0, key=lambda t: d[(0.0, t)])
    y = d[(20.0, pk)] / d[(0.0, pk)]
    dx, dy = LABEL_OFFSET[label]
    ax2.annotate(f"{y:.3f}", xy=(pk, y), xytext=(pk + dx, y + dy),
                 fontsize=9, color=col, fontweight="bold")

fig.suptitle(
    "The bank derate barely depends on blade count",
    fontsize=13.5, fontweight="bold", y=0.995,
)
fig.text(
    0.5, 0.005,
    "State and budget: AeroDyn v5.0.0 driver, `Precone` sweep, rotor = Daisy MVP (R 4.0 m, zero twist, "
    "NACA 4412 Re 250k); BEMT with SkewMod=2 (Pitt/Peters) so the skewed inflow is modelled, not imposed; "
    "AFAeroMod=2 unsteady; wind 8.0 m/s, ShftTilt=0 (pure bank, no elevation); 5.0 s per case at dT=2.31e-3 s, "
    "last timestep; 84 cases for the 3-blade set and 84 for the two 6-blade sets; worst |dCp| over the final "
    "200 steps = 3.4e-3. Solidity = N·c/(πR). Each curve in B is divided by its OWN 0° case, and each rotor is "
    "read at its own peak, because doubling the solidity moves the peak from λ=4.0 to λ=3.0. Off the peak the "
    "curves separate: at λ=6.0 the 3-blade and matched-6-blade retentions differ by 21.5 percentage points, "
    "because Cp is small there and the whole curve shifts.",
    ha="center", va="bottom", fontsize=7.2, color="0.3", wrap=True,
)

fig.tight_layout(rect=(0, 0.125, 1, 0.965))
fig.savefig(OUT, dpi=155)
print("wrote", OUT)

print("\n20 deg retention at each rotor's own peak:")
for label, d, _, _, _ in SERIES:
    lam0 = [t for t in TSRS if (0.0, t) in d and d[(0.0, t)] > 0]
    pk = max(lam0, key=lambda t: d[(0.0, t)])
    print(f"  {label:44s} peak lam {pk:.1f}  retains {d[(20.0, pk)] / d[(0.0, pk)]:.3f}")
