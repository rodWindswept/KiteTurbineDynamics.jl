#!/usr/bin/env python3
"""F9 — "The anchor": 29-Apr-2020 measured vs calibrated model.
Panel 1: P vs wind (model curve, measured binned mean±σ, controller
  ceiling, Betz-at-anemometer reference, model floor region).
Panel 2: ω vs wind (model ω_gnd vs measured controller rpm).
Prose: prose.md. Data: scripts/results/april29_model_curve.csv (model,
  2026-08-16 sweep, git-era anchor fix) and april29_anchor.csv (measured,
  1,206 rows from the merged workbook).
"""
import csv
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/docs/outreach/report-figures/f9-april29-anchor"
RES = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/scripts/results"

# --- data ---------------------------------------------------------------
model = list(csv.DictReader(open(f"{RES}/april29_model_curve.csv")))
mw = np.array([float(r["wind_ms"]) for r in model])
mp = np.array([float(r["P_model_W"]) for r in model])
mo = np.array([float(r["w_gnd_rads"]) for r in model])

rows = list(csv.DictReader(open(f"{RES}/april29_anchor.csv")))
wind = np.array([float(r["wind_ms"]) for r in rows])
powr = np.array([float(r["power_w"]) for r in rows])
rpm  = np.array([float(r["con_rpm"]) for r in rows])
ct   = np.array([float(r["con_time_days"]) for r in rows])

def bins_of(x, y):
    out = {}
    for xi, yi in zip(x, y):
        b = int(xi // 0.5) * 0.5 + 0.25
        out.setdefault(b, []).append(yi)
    bs = sorted(out)
    return (np.array(bs), np.array([np.mean(out[b]) for b in bs]),
            np.array([np.std(out[b]) for b in bs]),
            np.array([len(out[b]) for b in bs]))

def blocks_of(ct, x, y, sec=30):
    """Block means over fixed wall-clock windows (Rod: 30-s averages give
    the honest envelope; raw 1-2 s rows smear gust lulls with phase-lagged
    power)."""
    out = {}
    for t, xi, yi in zip(ct, x, y):
        b = int(t * 86400 // sec)
        out.setdefault(b, []).append((xi, yi))
    bs = sorted(out)
    res = []
    for b in bs:
        r = out[b]
        n = len(r)
        if n < 5:
            continue
        xs = [v[0] for v in r]; ys = [v[1] for v in r]
        res.append((np.mean(xs), np.mean(ys), np.std(ys), np.std(xs), n))
    return res

blocks = blocks_of(ct, wind, powr, 30)
bw = np.array([b[0] for b in blocks]); bp = np.array([b[1] for b in blocks])
bps = np.array([b[2] for b in blocks]); bws = np.array([b[3] for b in blocks])

# rpm blocks (same 30-s windows); measured points = STEADY blocks only
# (rpm mean > 60 — the 15:02-15:03 startup blocks, rpm 0-56, are not
# operating points; same filter as the tau(omega) table knots).
rblocks = blocks_of(ct, wind, rpm, 30)
br = np.array([b[1] for b in rblocks]) * 2 * np.pi / 60
brs = np.array([b[2] for b in rblocks]) * 2 * np.pi / 60
steady = np.array([b[1] for b in rblocks]) > 60
bw = bw[steady]; bp = bp[steady]; bps = bps[steady]; bws = bws[steady]
br = br[steady]; brs = brs[steady]

A = np.pi * 2.22**2
def betz(v):  # Betz limit at the RAW anemometer wind
    return 0.593 * 0.5 * 1.225 * v**3 * A

vv = np.linspace(3.0, 9.0, 60)

# --- figure -------------------------------------------------------------
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 6.4),
                               gridspec_kw={"width_ratios": [1.55, 1]})
fig.suptitle("The anchor: 29 April 2020 mast test vs calibrated model "
             "(thesis config 9, 6-blade TRPT-5)", y=0.98, fontsize=12)

# Panel 1 — power
ax1.plot(vv, betz(vv), ":", color="0.55", lw=1.2,
         label="Betz limit")
ax1.axhline(223, color="crimson", ls="--", lw=1.2,
            label="controller ceiling ≈ 220 W")
ax1.fill_between([3.0, 4.5], 0, 430, color="0.92",
                 label="model floor (no regen)")
ax1.errorbar(bw, bp, xerr=bws, yerr=bps, fmt="o", ms=5, capsize=3, color="crimson",
             lw=1.2, label="measured 29-Apr-2020 (30-s means)")
ax1.plot(mw, mp, "-o", ms=5, color="#1f77b4", lw=2, label="model curve")
ax1.annotate("model 234 W  vs  measured 223 ± 79 W\n"
             "Cp_sys ≈ 0.16 both (Oliver: 0.166)",
             xy=(6.25, 234), xytext=(6.4, 345), ha="center", fontsize=8.5,
             bbox=dict(boxstyle="round,pad=0.25", fc="white", ec="none", alpha=1.0))
ax1.annotate("test band\n5.5–7.0 m/s",
             xy=(6.2, 6), ha="center", fontsize=8, color="0.35")
ax1.set_xlabel("wind at 5 m anemometer (m/s)")
ax1.set_ylabel("power (W)")
ax1.set_xlim(3.0, 9.0)
ax1.set_ylim(0, 430)
ax1.grid(alpha=0.3)
for b, n in zip(bw, [len(blocks)] * len(bw)):
    pass

# Panel 2 — speed
ax2.plot(mw, mo, "-o", ms=5, color="#1f77b4", lw=2, label="model ω_gnd")
ax2.errorbar(bw, br, yerr=brs, fmt="s", ms=4, capsize=2,
             color="crimson", lw=1, label="measured (controller rpm)")
ax2.axhline(11.3, color="0.5", ls=":", lw=1.2)
ax2.annotate("field held ω ≈ 9.8–12.9 rad/s\n(TSR set 5.5, actual 4.35)",
             xy=(6.25, 11.3), xytext=(7.8, 4), ha="center", fontsize=8.5,
             bbox=dict(boxstyle="round,pad=0.25", fc="white", ec="none", alpha=0.9))
ax2.annotate("model parks at AeroDyn peak λ ≈ 7.6 —\nthe thesis's flagged 6-blade modelling gap",
             xy=(7.25, 22.5), xytext=(5.4, 31.4), ha="center", va="top", fontsize=8.5,
             bbox=dict(boxstyle="round,pad=0.25", fc="white", ec="none", alpha=0.9))
ax2.set_xlabel("wind at 5 m anemometer (m/s)")
ax2.set_ylabel("ω (rad/s)")
ax2.set_xlim(3.0, 9.0)
ax2.set_ylim(0, 34)
ax2.grid(alpha=0.3)

# shared legend + caption below the figure (panel-1 series only)
fig.legend(loc="lower center", ncol=5, fontsize=7.5, frameon=False,
           bbox_to_anchor=(0.5, 0.14),
           handles=ax1.get_legend_handles_labels()[0],
           labels=ax1.get_legend_handles_labels()[1])
CAPTION = ("The 29-Apr-2020 mast test (thesis config 9) vs the calibrated model — measured points are 30-s means; the test ran "
           "15:03\u201315:09 at\n5.5\u20137.0 m/s (raw 2\u20134 s lulls reach 3\u20139 m/s with phase-lagged power — transients, not operating "
           "points). The model lands on the\nmeasured band: 234 W vs 223 \u00b1 79 W at 6.25 m/s, Cp_sys \u2248 0.16 both (Oliver: 0.166). "
           "Power varied with the controller's ramping more than wind;\nbelow ~4.5 m/s the model is on its no-regen floor (outside "
           "the test band); above 6.5 m/s it out-runs the field (torque table never observed\npast 12.9 rad/s). The \u03c9 panel shows "
           "the gap — model parks at the AeroDyn peak \u03bb\u22487.6 while the field held 9.8\u201312.9 rad/s (TSR set 5.5, actual 4.35).")
fig.text(0.5, 0.005, CAPTION, ha="center", va="bottom", fontsize=7.5, color="#333333")

fig.tight_layout(rect=(0, 0.16, 1, 0.94))
fig.savefig(f"{HERE}/figure.png", dpi=150)
print("wrote", f"{HERE}/figure.png")
