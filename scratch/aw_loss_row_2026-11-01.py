#!/usr/bin/env python3
"""aero-worker 2026-11-01: the loss-exponent row and the two-dp tie rule.

Rebuilds the archive loss response on the 508 ok rows of the live campaign:

  torque balance  (1+f) x^2 + x - 2 = 0,   x = omega'/omega,  f = kappa/k
  power           P' = P x^3

with f taken from the three signed bridle-drag bounds at the archive k = 2.24,
and again at the measured k* bracket (f/k* ratio, RF-19).

The tie rule: P_end is recorded at two decimal places. A design whose printed
P_end sits on the derived floor is a boundary tie, not a survivor. Counts print
strict (clear of the floor by more than half a print step), tie, and inclusive,
so a reader can quote the robust ends and never the middle.
"""
import csv
import glob
import math

TELE = ("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl/scripts/results/"
        "v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_*/telemetry.csv")
P_WIN = 5281.0
FLOOR = 5.0
WINNER_FIT = 27.364
BOUNDS = [(547.0, "two bridles, low"), (684.0, "two bridles, high"),
          (932.0, "full line root-to-tip")]
K_ARCH = 2.24
K_RATIO = (3.7500, 3.9732)     # 8.4/2.24 and 8.9/2.24, the measured bracket
HALF_STEP = 0.005              # half of the 0.01 print step

rows = []
for path in sorted(glob.glob(TELE)):
    rows += list(csv.DictReader([l for l in open(path) if not l.startswith("#")]))
ok = [d for d in rows if d["status"] == "ok"]
P = sorted(float(d["P_end"]) for d in ok)
print("ok rows %d  P_end max %.2f kW  min %.2f kW" % (len(ok), P[-1], P[0]))
print("winner shaft basis %.3f kW  winner fitness %.3f kg-eq" % (P_WIN / 1000, WINNER_FIT))

# the quadratic has one positive root
def response(f):
    a = 1.0 + f
    x = (-1.0 + math.sqrt(1.0 + 8.0 * a)) / (2.0 * a)
    return x, x ** 3

def parabolic(f, a=0.1):
    lo, hi = 0.5, 1.0
    for _ in range(200):
        mid = 0.5 * (lo + hi)
        if (1.0 + f) * mid ** 3 > 1.0 - a * (mid - 1.0) ** 2:
            hi = mid
        else:
            lo = mid
    return 0.5 * (lo + hi)

print("\n%-22s %6s %8s %8s %8s %10s %8s" %
      ("basis", "f", "x", "x^3", "1-f", "(1+f)^-1.5", "parab"))
for W, label in BOUNDS:
    f = W / P_WIN
    x, rel = response(f)
    print("%-22s %6.4f %8.4f %8.4f %8.4f %10.4f %8.4f" %
          (label, f, x, rel, 1 - f, (1 + f) ** -1.5, parabolic(f)))

# same bases at the measured k* bracket: f falls by the k ratio (RF-19)
print("\n%-22s %8s %8s %8s %8s %10s %8s" %
      ("basis at k* 8.4-8.9", "f low", "f high", "x^3 low", "x^3 high",
       "P' low", "P' high"))
for W, label in BOUNDS:
    f0 = W / P_WIN
    fl = f0 / K_RATIO[1]     # larger k ratio -> smaller f
    fh = f0 / K_RATIO[0]
    xl, rl = response(fl)
    xh, rh = response(fh)
    print("%-22s %8.5f %8.5f %8.4f %8.4f %10.4f %8.4f" %
          (label, fl, fh, rl, rh, rl, rh))

print("\n%-22s %4s %10s %10s %6s %10s  %s" %
      ("basis", "eta", "floor kW", "strict", "tie", "inclusive", "lightest strict"))
for W, label in BOUNDS:
    f = W / P_WIN
    x, rel = response(f)
    for eta in (1.0, 0.94):
        floor = FLOOR / (rel * eta)
        clear = [d for d in ok if float(d["P_end"]) > floor + HALF_STEP]
        tie = [d for d in ok if abs(float(d["P_end"]) - floor) <= HALF_STEP]
        incl = [d for d in ok if float(d["P_end"]) >= floor - HALF_STEP]
        if clear:
            best = min(clear, key=lambda d: float(d["fitness"]))
            tail = "%.3f kg-eq (+%.2f) i%s g%s" % (
                float(best["fitness"]), float(best["fitness"]) - WINNER_FIT,
                best["island"], best["gen"])
        else:
            tail = "none"
        print("%-22s %4.2f %10.4f %10d %6d %10d  %s" %
              (label, eta, floor, len(clear), len(tie), len(incl), tail))

# the rows that sit on or next to the two hard floors, named
print("\nboundary rows within one print step of the two eta-0.94 floors:")
for W, label in [(547.0, "two bridles, low"), (932.0, "full line root-to-tip")]:
    f = W / P_WIN
    x, rel = response(f)
    floor = FLOOR / (rel * 0.94)
    near = sorted([d for d in ok if abs(float(d["P_end"]) - floor) <= 0.02],
                  key=lambda d: float(d["P_end"]))
    print("  %s  floor %.4f kW  rows within 0.02 kW:" % (label, floor))
    for d in near:
        print("    i%s g%s idx%s  P_end %s  fitness %s" %
              (d["island"], d["gen"], d["idx"], d["P_end"], d["fitness"]))
