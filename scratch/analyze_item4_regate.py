#!/usr/bin/env python3
"""Item 4 re-gate pattern analysis (scratch/analyze_item4_regate.py).

Reads the six re-gate CSVs (3 islands x {ld0.00, ld0.05}) and reports:
- window stats for hub_lat, omega_gnd, T_cyan, T_back, T_bridle, fos_min
- the dominant slow period of hub_lat (autocorrelation peak, 2..40 s lags)
- the onset time of large hub motion (first 10 s bin with |hub-dev| > 0.25 m)
- the peak |cross-correlation| and its lag between hub_e1 and omega_gnd, and
  between hub_e1 and T_cyan (lead/lag in seconds)
- a growth profile of |hub-dev| in 10 s bins for the envelope runs

Usage: /usr/bin/python3 scratch/analyze_item4_regate.py
"""
import csv
import math
import os

LOGDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".julia_depot", "logs")
RUNS = [
    ("isl1_ld0.00", "wg_isl1_ld0.00_dtf1.csv"),
    ("isl1_ld0.05", "wg_isl1_ld0.05_dtf1.csv"),
    ("isl2_ld0.00", "wg_isl2_ld0.00_dtf1.csv"),
    ("isl2_ld0.05", "wg_isl2_ld0.05_dtf1.csv"),
    ("isl3_ld0.00", "wg_isl3_ld0.00_dtf1.csv"),
    ("isl3_ld0.05", "wg_isl3_ld0.05_dtf1.csv"),
]


def load(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            rows.append({k: float(v) for k, v in r.items()})
    return rows


def p2p(v):
    return max(v) - min(v)


def ac_period(v, dt=0.5, lo=4, hi=80):
    """Dominant oscillation period by autocorrelation peak over lags (lo..hi)."""
    m = sum(v) / len(v)
    x = [a - m for a in v]
    den = sum(a * a for a in x)
    if den <= 0:
        return float("nan"), 0.0
    best = (float("nan"), -2.0)
    for lag in range(lo, min(len(x) // 2, hi)):
        num = sum(x[i] * x[i + lag] for i in range(len(x) - lag))
        r = num / den
        if r > best[1]:
            best = (lag * dt, r)
    return best


def onset(v, thr=0.25, dt=0.5, bin_s=10.0):
    """First 10 s bin whose peak |deviation| exceeds thr."""
    m = sum(v) / len(v)
    n = int(bin_s / dt)
    for b in range(0, len(v), n):
        seg = v[b:b + n]
        if seg and max(abs(a - m) for a in seg) > thr:
            return b * dt
    return None


def xpeak(a, b, dt=0.5, max_lag=60):
    """Peak |cross-correlation| and lag (a vs b). Positive lag: b matches a shifted later."""
    ma = sum(a) / len(a)
    mb = sum(b) / len(b)
    xa = [u - ma for u in a]
    xb = [u - mb for u in b]
    sa = math.sqrt(sum(u * u for u in xa))
    sb = math.sqrt(sum(u * u for u in xb))
    if sa <= 0 or sb <= 0:
        return 0.0, 0, 0.0
    best = (0.0, 0)
    for lag in range(-max_lag, max_lag + 1):
        num = 0.0
        for i in range(len(xa)):
            j = i + lag
            if 0 <= j < len(xa):
                num += xa[i] * xb[j]
        r = num / (sa * sb)
        if abs(r) > abs(best[0]):
            best = (r, lag)
    return best[0], best[1], best[1] * dt


def profile(v, dt=0.5, bin_s=10.0):
    m = sum(v) / len(v)
    n = int(bin_s / dt)
    out = []
    for b in range(0, len(v), n):
        seg = v[b:b + n]
        if seg:
            out.append(max(abs(a - m) for a in seg))
    return out


def main():
    data = {}
    for name, fn in RUNS:
        p = os.path.join(LOGDIR, fn)
        if not os.path.exists(p):
            print(f"missing: {p}")
            continue
        data[name] = load(p)

    print("run          hub_p2p  hub_devmax  om_p2p  cy_p2p   bk_p2p  br_mean  fos_trough  ac_T_s  ac_r  onset_s")
    for name, _ in RUNS:
        if name not in data:
            continue
        d = data[name]
        hub = [r["hub_lat"] for r in d]
        om = [r["omega_gnd"] for r in d]
        cy = [r["T_cyan"] for r in d]
        bk = [r["T_back"] for r in d]
        br = [r["T_bridle"] for r in d]
        fos = [r["fos_min"] for r in d]
        m = sum(hub) / len(hub)
        dev = max(abs(a - m) for a in hub)
        T, rr = ac_period(hub)
        on = onset(hub)
        print(f"{name:12s} {p2p(hub):7.4f}  {dev:8.4f}   {p2p(om):6.2f}  {p2p(cy):7.1f}  {p2p(bk):7.1f}"
              f"  {sum(br) / len(br):7.2f}  {min(fos):8.3f}   {T:6.1f} {rr:5.2f}  {str(on):>7s}")

    print()
    print("cross-correlation peaks (envelope runs; lag in s, +ve = second series matches later):")
    for name in ("isl1_ld0.00", "isl2_ld0.00", "isl3_ld0.00"):
        if name not in data:
            continue
        d = data[name]
        hub = [r["hub_e1"] for r in d]
        om = [r["omega_gnd"] for r in d]
        cy = [r["T_cyan"] for r in d]
        r1, _, t1 = xpeak(hub, om)
        r2, _, t2 = xpeak(hub, cy)
        print(f"{name:12s} hub~omega |r|={abs(r1):.2f} lag={t1:+.1f}s    hub~cyan |r|={abs(r2):.2f} lag={t2:+.1f}s")

    print()
    print("hub |dev| growth profile, 10 s bins (envelope runs):")
    for name in ("isl1_ld0.00", "isl2_ld0.00", "isl3_ld0.00"):
        if name not in data:
            continue
        hub = [r["hub_lat"] for r in data[name]]
        prof = profile(hub)
        print(f"{name:12s} " + " ".join(f"{v:5.3f}" for v in prof))


if __name__ == "__main__":
    main()
