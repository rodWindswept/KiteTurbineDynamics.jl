#!/usr/bin/env python3
"""aero-worker 2026-11-01: the 0.837 m bow asymptote, derived and bounded.

Sign-off basis for the register row. Reads the pinned NR-059 probe log
(scratch/av_bow_probe.log, sha256 eacc0ce3...) and rebuilds the geometric-tail
read from the phase-4 extension series.

The claim is conditional and says so: the remaining bow is the geometric tail
of the measured 5 s increments. The ratio is taken at its largest value over
the last ten steps, so the tail is an upper bound while the ratio does not rise.
A margin case at r = 0.95 prints beside it.
"""
import hashlib
import re

LOG = "scratch/av_bow_probe.log"
PIN_LOG = "eacc0ce3acbcdeb66b6dd9db975b177ceb401a2929bee2c40fd258e22f2bf987"

text = open(LOG).read()
sha = hashlib.sha256(open(LOG, "rb").read()).hexdigest()
print("log sha256", sha)
print("pin holds  ", sha == PIN_LOG)

rows = re.findall(r"^\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([-\+][\d.]+)$", text, re.M)
print("extension rows", len(rows))
t = [float(r[0]) for r in rows]
hub = [float(r[2]) for r in rows]
mid = [float(r[3]) for r in rows]
# the raw t=200 station closes the series (it sits outside the 5 s table)
m200 = re.search(r"raw: hub at t=200 = .*? perp = ([\d.]+)", text)
t.append(200.0)
hub.append(float(m200.group(1)))
mid.append(float(re.findall(r"mid-span ([\d.]+) m", text)[-1]))
print("t range", t[0], "to", t[-1], " sites", len(t))

inc = [hub[i] - hub[i - 1] for i in range(1, len(hub))]
print("\nincrements per 5 s (m):")
for i, v in enumerate(inc):
    print("  %3.0f -> %3.0f   %.6f" % (t[i], t[i + 1], v))

ratios = [inc[i] / inc[i - 1] for i in range(1, len(inc))]
print("\nratios:")
print("  " + " ".join("%.4f" % r for r in ratios))

last10 = ratios[-10:]
r_mean = sum(last10) / len(last10)
r_max = max(last10)
r_min = min(last10)
print("\nlast-10 ratios: mean %.6f  max %.6f  min %.6f" % (r_mean, r_max, r_min))
print("ratio sequence non-increasing:", all(ratios[i] <= ratios[i - 1] for i in range(1, len(ratios))))

hub195 = hub[-2]
hub200 = hub[-1]
tail_mean = inc[-1] * r_mean / (1 - r_mean)
tail_max = inc[-1] * r_max / (1 - r_max)
tail_chk = inc[-2] * r_mean / (1 - r_mean)   # the check-log construction
print("\nlast increment %.6f m (195->200)" % inc[-1])
print("tail, mean ratio  %.6f m" % tail_mean)
print("tail, max ratio   %.6f m  (upper bound while r <= %.4f)" % (tail_max, r_max))
asym_mean = hub200 + tail_mean
asym_max = hub200 + tail_max
print("asymptote, mean   %.6f m   margin %.6f m" % (asym_mean, 1.5 - asym_mean))
print("asymptote, max    %.6f m   margin %.6f m" % (asym_max, 1.5 - asym_max))
print("check-log construction (195 station + 190->195 increment): %.6f m"
      % (hub195 + tail_chk))

# robustness: what ratio would put the asymptote on the 1.5 m line?
# hub195 + inc*r/(1-r) = 1.5
rhs = 1.5 - hub195
r_crit = rhs / (rhs + inc[-1])
print("\nratio that reaches 1.5 m: %.4f  (last-10 max %.4f)" % (r_crit, r_max))

# midpoint ring, same construction
inc_m = [mid[i] - mid[i - 1] for i in range(1, len(mid))]
rm = [inc_m[i] / inc_m[i - 1] for i in range(1, len(inc_m))]
rm_mean = sum(rm[-10:]) / 10
rm_max = max(rm[-10:])
am_mean = mid[-1] + inc_m[-1] * rm_mean / (1 - rm_mean)
am_max = mid[-1] + inc_m[-1] * rm_max / (1 - rm_max)
print("\nmidpoint: last inc %.6f  ratio mean %.6f max %.6f" % (inc_m[-1], rm_mean, rm_max))
print("midpoint asymptote mean %.6f  max %.6f  margin(max) %.6f" % (am_mean, am_max, 1.5 - am_max))

# the terminal raw point at t=200 is a sample, not a fifth station
m = re.search(r"raw: hub at t=200 = .*? perp = ([\d.]+)", text)
print("\nraw hub at t=200 (perp) %.6f ; bound uses the %.0f s station plus the tail"
      % (float(m.group(1)), t[-1]))

print("\nREADING: bow asymptote %.4f m on the hub station, margin %.4f m to the"
      % (asym_mean, 1.5 - asym_mean))
print("1.5 m line. Upper bound on the same geometric basis %.4f m, margin %.4f m."
      % (asym_max, 1.5 - asym_max))
