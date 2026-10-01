#!/usr/bin/env python3
"""Figure for the AeroDyn precone sweep.

One claim: a 20 deg bank costs about 15 per cent of rotor Cp at the power peak,
which is close to the cos^3(beta) rule the repo already carries and 5.8x smaller
than the loss the banked expansion model produced.
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
CSV = os.path.join(WORK, "results", "sweep.csv")
OUT = os.path.join(WORK, "results", "precone_sweep.png")

TSRS = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
ANGLES = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0]

rows = []
with open(CSV) as fh:
    # The CSV carries a provenance block as leading '#' lines.
    body = [ln for ln in fh if not ln.lstrip().startswith("#")]
for r in csv.DictReader(body):
    r["angle_deg"] = float(r["angle_deg"])
    r["tsr_set"] = float(r["tsr_set"])
    r["Cp"] = float(r["Cp"])
    rows.append(r)


def get(kind, ang, tsr, value="Cp"):
    hit = [r for r in rows if r["kind"] == kind and r["angle_deg"] == ang
           and r["tsr_set"] == tsr]
    return hit[0][value] if hit else None


fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13.5, 5.4))

# --- Panel A: the Cp curves, absolute values --------------------------------
cmap = plt.get_cmap("viridis")
for i, a in enumerate(ANGLES):
    ys = [get("precone", a, t) for t in TSRS]
    xs = [t for t, y in zip(TSRS, ys) if y is not None]
    yy = [y for y in ys if y is not None]
    ax1.plot(xs, yy, "o-", color=cmap(i / (len(ANGLES) - 1)), ms=5,
             lw=1.8, label=f"{a:g}\u00b0 precone")

ax1.axhline(0, color="0.6", lw=0.8, ls=":")
ax1.set_xlabel("commanded tip-speed ratio  $\\lambda$  (-)")
ax1.set_ylabel("rotor power coefficient  $C_P$  (-)")
ax1.set_title("A. Bank shifts and lowers the whole $C_P$ curve", fontsize=11)
ax1.grid(alpha=0.25)
ax1.legend(fontsize=8.5, title="bank angle", title_fontsize=8.5)
ax1.annotate("peak $C_P$ = 0.264 at $\\lambda$ = 4.0",
             xy=(3.95, 0.264), xytext=(2.05, 0.245),
             arrowprops=dict(arrowstyle="->", color="0.35"),
             fontsize=8.5, color="0.25")

# --- Panel B: the ratio at the peak, precone vs yaw vs cos^3 ----------------
ang_pos = [a for a in ANGLES if a > 0]
pc = [get("precone", a, 4.0) / get("precone", 0.0, 4.0) for a in ANGLES]
yw = [get("yaw", a, 4.0) / get("yaw", 0.0, 4.0) for a in ANGLES]
c3 = [math.cos(math.radians(a)) ** 3 for a in ANGLES]
c265 = [math.cos(math.radians(a)) ** 2.65 for a in ANGLES]

ax2.plot(ANGLES, pc, "o-", color="#1f6fb4", lw=2.0, ms=6,
         label="precone (bank) \u2014 measured")
ax2.plot(ANGLES, yw, "s-", color="#c0504d", lw=2.0, ms=6,
         label="yaw \u2014 measured")
ax2.plot(ANGLES, c265, "-", color="#2e8b57", lw=2.2,
         label="$\\cos^{2.65}\\beta$ \u2014 the repo's existing exponent")
ax2.plot(ANGLES, c3, "--", color="0.35", lw=1.6,
         label="$\\cos^3\\beta$ rule (Tulloch eq. 4.1)")
ax2.axhline(0.147, color="#7f7f7f", lw=1.6, ls="-.")
ax2.annotate("the banked expansion model\nretained only 0.147",
             xy=(17, 0.147), xytext=(12.2, 0.34),
             arrowprops=dict(arrowstyle="->", color="#7f7f7f"),
             fontsize=8.5, color="#666666")
ax2.axhline(1.0, color="0.8", lw=0.8)
ax2.set_xlabel("bank angle, or yaw angle  (deg)")
ax2.set_ylabel("$C_P$(angle) / $C_P$(0)  at $\\lambda$ = 4.0  (-)")
ax2.set_title("B. A 20\u00b0 bank costs 15%, and yaw is not the same thing",
              fontsize=11)
ax2.grid(alpha=0.25)
ax2.legend(fontsize=8.5, loc="lower left")
ax2.set_ylim(-0.02, 1.12)
ax2.annotate(f"20\u00b0: {pc[4]:.3f}", xy=(20, pc[4]), xytext=(20.4, 0.90),
             fontsize=9, color="#1f6fb4", fontweight="bold")

fig.suptitle(
    "A 20\u00b0 bank costs about 15 per cent of rotor $C_P$ at the power peak",
    fontsize=13.5, fontweight="bold", y=0.995,
)
fig.text(
    0.5, 0.005,
    "State and budget: AeroDyn v5.0.0 driver, rotor = Daisy MVP (3 blades, R 4.0 m, uniform chord 0.500 m, zero twist, "
    "NACA 4412 Re 250k); BEMT with SkewMod=2 (Pitt/Peters) so the skewed inflow is modelled, not imposed; "
    "AFAeroMod=2 unsteady; wind 8.0 m/s, ShftTilt=0 (pure bank, no elevation); 5.0 s per case at dT=2.31e-3 s, "
    "last timestep taken; 84 cases; worst |dCp| over the final 200 steps = 3.4e-3. "
    "Aligned on commanded \u03bb because AeroDyn's RtTSR uses an angle-dependent reference length. "
    "Blue line: precone sweep. Red line: yaw sweep on the same rotor. Green line: the repo's own "
    "cos^2.65 exponent, which matches the measured bank retention to 0.7 per cent at 20 deg. "
    "Grey dashed: Tulloch eq. 4.1, cos^3. Grey dash-dot: the ratio the banked expansion model produced "
    "(0.80 kW against 5.46 kW), 5.8x below the measurement.",
    ha="center", va="bottom", fontsize=7.2, color="0.3", wrap=True,
)

fig.tight_layout(rect=(0, 0.115, 1, 0.965))
fig.savefig(OUT, dpi=155)
print("wrote", OUT)

print("\npeak-lambda table (lambda = 4.0):")
print(f"{'angle':>6} {'precone':>9} {'yaw':>8} {'cos^3':>8}")
for a, p, y, c in zip(ANGLES, pc, yw, c3):
    print(f"{a:>6.0f} {p:>9.3f} {y:>8.3f} {c:>8.3f}")
