#!/usr/bin/env python3
"""Fine-cadence forensics for the Item 4 re-gate runs (scratch/analyze_item4_fine.py).

Reads the fine-capture CSVs (0.05 s) and reports, per run:
- top autocorrelation peaks (period in s, r) for hub_e1, T_cyan, T_bridle, omega_gnd
- coupling lags at 0.05 s resolution: hub excursion vs omega, vs cyan deficit,
  vs bridle-slack indicator (positive lag = the second series matches LATER)
- duty fractions: time with T_cyan < 50 N, time with T_bridle < 5 N

Usage: /usr/bin/python3 scratch/analyze_item4_fine.py [tag=csv ...]
Default: the three wg_isl*_fine runs (missing files are skipped).
"""
import csv
import math
import os
import sys

DT = 0.05
LOGDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".julia_depot", "logs")
DEFAULT = [
    ("isl1_ld0.00_fine", "wg_isl1_ld0.00_fine.csv"),
    ("isl1_ld0.05_fine", "wg_isl1_ld0.05_fine.csv"),
    ("isl3_ld0.00_fine", "wg_isl3_ld0.00_fine.csv"),
]


def load(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            rows.append({k: float(v) for k, v in r.items()})
    return rows


def demean(v):
    m = sum(v) / len(v)
    return [a - m for a in v]


def ac_peaks(v, lo_s=0.3, hi_s=15.0, min_r=0.25, top=3):
    x = demean(v)
    den = sum(a * a for a in x)
    if den <= 0:
        return []
    lo = max(6, int(lo_s / DT))
    hi = min(len(x) // 2, int(hi_s / DT))
    r = [0.0] * (hi + 2)
    for lag in range(lo, hi + 1):
        num = sum(x[i] * x[i + lag] for i in range(len(x) - lag))
        r[lag] = num / den
    peaks = []
    for lag in range(lo + 1, hi):
        if r[lag] > r[lag - 1] and r[lag] >= r[lag + 1] and r[lag] > min_r:
            peaks.append((r[lag], lag * DT))
    peaks.sort(reverse=True)
    return peaks[:top]


def xpeak(a, b, max_lag_s=20.0):
    xa = demean(a)
    xb = demean(b)
    sa = math.sqrt(sum(u * u for u in xa))
    sb = math.sqrt(sum(u * u for u in xb))
    if sa <= 0 or sb <= 0:
        return 0.0, 0.0
    ml = int(max_lag_s / DT)
    best = (0.0, 0)
    for lag in range(-ml, ml + 1):
        num = 0.0
        for i in range(len(xa)):
            j = i + lag
            if 0 <= j < len(xa):
                num += xa[i] * xb[j]
        r = num / (sa * sb)
        if abs(r) > abs(best[0]):
            best = (r, lag)
    return best[0], best[1] * DT


def fmt_peaks(peaks):
    if not peaks:
        return "none"
    return "  ".join(f"{p:5.2f}s(r={r:.2f})" for r, p in peaks)


def run_one(label, path):
    d = load(path)
    hub = [r["hub_e1"] for r in d]
    hub2 = [r["hub_e2"] for r in d]
    om = [r["omega_gnd"] for r in d]
    cy = [r["T_cyan"] for r in d]
    br = [r["T_bridle"] for r in d]
    n = len(d)
    m = sum(hub) / n
    hd = [abs(a - m) for a in hub]
    cy_def = [max(0.0, 150.0 - t) for t in cy]
    br_sl = [1.0 if t < 5.0 else 0.0 for t in br]

    print(f"════ {label}  (n={n}, {n * DT:.0f} s) ════")
    print(f"  hub_e1  peaks: {fmt_peaks(ac_peaks(hub))}")
    print(f"  hub_e2  peaks: {fmt_peaks(ac_peaks(hub2))}")
    print(f"  omega   peaks: {fmt_peaks(ac_peaks(om))}")
    print(f"  cyan    peaks: {fmt_peaks(ac_peaks(cy))}")
    r1, t1 = xpeak(hd, om)
    r2, t2 = xpeak(hd, cy_def)
    r3, t3 = xpeak(hd, br_sl)
    print(f"  coupling: hub-excursion ~ omega   |r|={abs(r1):.2f}  lag={t1:+.2f}s")
    print(f"            hub-excursion ~ cyan-deficit |r|={abs(r2):.2f}  lag={t2:+.2f}s")
    print(f"            hub-excursion ~ bridle-slack |r|={abs(r3):.2f}  lag={t3:+.2f}s")
    cy_duty = 100.0 * sum(1 for t in cy if t < 50.0) / n
    br_duty = 100.0 * sum(1 for t in br if t < 5.0) / n
    print(f"  duty: cyan<50N {cy_duty:.0f}%   bridle<5N {br_duty:.0f}%")
    print()


def main():
    if len(sys.argv) > 1:
        runs = [a.split("=", 1) for a in sys.argv[1:]]
    else:
        runs = DEFAULT
    for label, fn in runs:
        p = fn if os.path.isabs(fn) else os.path.join(LOGDIR, fn)
        if not os.path.exists(p):
            print(f"missing: {p}")
            continue
        run_one(label, p)


if __name__ == "__main__":
    main()
