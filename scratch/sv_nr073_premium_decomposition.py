#!/usr/bin/env python3
"""NR-073 receipt: the charge decomposition across the power-curve sweep.

Reads the record-contract CSV and recomputes the campaign objective from its
columns alone, at every ok wind. The four charge forms read NR-046:

    f = mass + 5.0*max(P_score-5.0,0)^2 + 20.0*(2.5/FoS)^2
             + 1.0*(tr/(1-tr))^2 + 10.0*max(0, P_range/P_mean - 0.20)

The CSV carries P_end, FoS_min, twist_ratio, mass_kg and fitness_kg_eq, but
no P_range, so the stationarity term is bounded rather than read: the residual
against the recorded score bounds any charge. Six-decimal inputs cap the
recomputation's own noise, and that cap is reported per wind.
"""
import hashlib
import sys

CSV = "scratch/av_power_curve_sweep.csv"
MD5 = "a4e535af18da220a473db963c45ceb76"
P_FLOOR = 5.0
W_OVERPOWER = 5.0      # objective_v12.jl:114
W_TWIST = 1.0          # :115
W_UTIL = 20.0          # :116
FOS_HARD = 2.5         # run_v13_5kw_masslift.jl:155
W_STAT = 10.0          # objective_evaluator.jl:90
STAT_SWING = 0.20      # :91
ROUND = 0.5e-6         # half of the CSV's last printed digit
fails = []


def check(name, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {name}{('  ' + detail) if detail else ''}")
    if not ok:
        fails.append(name)


raw = open(CSV, "rb").read()
check("csv md5", hashlib.md5(raw).hexdigest() == MD5, hashlib.md5(raw).hexdigest())

rows = [r.rstrip("\n").split(",") for r in raw.decode().splitlines() if not r.startswith("#")]
head = rows[0]
data = [dict(zip(head, r)) for r in rows[1:] if r and r[0]]
check("18 data rows", len(data) == 18, str(len(data)))
winds = sorted({float(d["wind_mps"]) for d in data})
check("16 unique winds", len(winds) == 16, str(len(winds)))
check("one machine", {d["mass_kg"] for d in data} == {"25.698468"})
check("one rating and gain", {d["v_rated"] for d in data} == {"11.000000"}
      and {d["k_mppt"] for d in data} == {"2.240000"})

ok_rows = [d for d in data if d["status"] == "ok" and d["rep"] == "1"]
check("7 scoring winds", len(ok_rows) == 7, str(len(ok_rows)))

print("\nwind      P_end      FoS        twist   | over-power  utilisation  twist     stat  "
      "| recomputed    recorded     residual   input cap")
worst = 0.0
for d in ok_rows:
    P = float(d["P_end_kW"]); fos = float(d["FoS_min"]); tr = float(d["twist_ratio"])
    m = float(d["mass_kg"]); rec = float(d["fitness_kg_eq"])
    op = W_OVERPOWER * max(P - P_FLOOR, 0.0) ** 2
    ut = W_UTIL * (FOS_HARD / fos) ** 2
    tw = W_TWIST * (tr / max(1.0 - tr, 1e-6)) ** 2
    tot = m + op + ut + tw
    resid = rec - tot
    # sensitivity of the recomputation to the CSV's last printed digit
    cap = (2 * W_OVERPOWER * max(P - P_FLOOR, 0.0) * ROUND
           + 2 * W_UTIL * FOS_HARD ** 2 / fos ** 3 * ROUND
           + 2 * tw / (tr * (1 - tr)) * ROUND)
    worst = max(worst, abs(resid))
    print(f"{d['wind_mps']:>7}  {P:9.6f}  {fos:9.6f}  {tr:7.6f} | {op:10.6f}  {ut:10.6f}  "
          f"{tw:8.6f}  {0.0:5.1f} | {tot:12.6f}  {rec:12.6f}  {resid:+10.7f}  {cap:9.7f}")

check("every residual inside the six-decimal input cap", worst < 2.4e-5, f"worst {worst:.2e}")

# The stationarity term: any live charge would be 10*excess, so the smallest
# charge the residual could hide is 10*(worst/10), i.e. swing beyond 0.20 + worst/10.
check("no stationarity charge at any scoring wind", worst / W_STAT < 2.4e-6,
      f"swing ceiling {STAT_SWING + worst / W_STAT:.7f}")

# P_score is P_end, not P_mean: the identity row separates them by 1.7e-2.
idr = next(d for d in ok_rows if abs(float(d["wind_mps"]) - 11.009694) < 1e-9)
for label, key in (("P_end", "P_end_kW"), ("P_mean", "P_mean_kW")):
    P = float(idr[key]); fos = float(idr["FoS_min"]); tr = float(idr["twist_ratio"])
    tot = 25.698468 + 5.0 * (P - 5.0) ** 2 + 20.0 * (2.5 / fos) ** 2 + (tr / (1 - tr)) ** 2
    resid = float(idr["fitness_kg_eq"]) - tot
    print(f"identity, {label} charged: residual {resid:+.7f}")
    if label == "P_end":
        check("the seam charges the window end", abs(resid) < 2.4e-5, f"{resid:+.2e}")
    else:
        check("the window mean does not close", abs(resid) > 1e-2, f"{resid:+.2e}")

top = next(d for d in ok_rows if d["wind_mps"] == "13.500000")
P = float(top["P_end_kW"]); fos = float(top["FoS_min"]); tr = float(top["twist_ratio"])
op = 5.0 * (P - 5.0) ** 2
ut = 20.0 * (2.5 / fos) ** 2
tw = (tr / (1 - tr)) ** 2
prem = op + ut + tw
print(f"\n13.5 m/s premium {prem:.6f} kg = over-power {op:.6f} "
      f"({100 * op / prem:.2f} %) + utilisation {ut:.6f} + twist {tw:.6f}")
print(f"mass {float(top['mass_kg']):.6f} constant; total {float(top['mass_kg']) + prem:.6f} "
      f"against recorded {float(top['fitness_kg_eq']):.6f}")

print(f"\n{len(fails)} failure(s)")
sys.exit(1 if fails else 0)
