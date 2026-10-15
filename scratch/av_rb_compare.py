#!/usr/bin/env python3
# av_rb_compare.py — cross-checks for the rope-break gate placement receipt.
# 1) fixed-path run vs the committed condition run, same sampled grid
# 2) warm extracts: latch census + tail stats
# Read-only. Usage: python3 scratch/av_rb_compare.py
import statistics

REPO = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"


def load(path):
    rows = []
    with open(path) as f:
        for line in f:
            if line.startswith("#"):
                continue
            p = line.strip().split(",")
            if p[0] == "t":
                continue
            rows.append([float(x) for x in p])
    return rows


# 1) fixed path (direct) vs condition run (pre-fix flip), identical grid
place = load(f"{REPO}/scratch/av_rb_placement_island3.csv")
cond = load(f"{REPO}/docs/reporting/figures/eval-timeline-extract/extract-eval-timeline-warm-rulingmode.csv")
assert len(place) == len(cond), "row counts differ"
max_t = max_g = max_h = max_p = 0.0
for a, b in zip(place, cond):
    max_t = max(max_t, abs(a[0] - b[0]))
    max_g = max(max_g, abs(a[1] - b[1]))
    max_h = max(max_h, abs(a[2] - b[2]))
    max_p = max(max_p, abs(a[3] - b[3]))
print(f"1) placement vs condition: {len(place)} rows | max|dt|={max_t:.3e} max|dwg|={max_g:.3e} max|dwh|={max_h:.3e} max|dP|={max_p:.3e}")

wmask = [r for r in place if r[0] >= 10.0]
print(f"   fixed-path window means: wg={statistics.mean(r[1] for r in wmask):.9f} wh={statistics.mean(r[2] for r in wmask):.9f} P={statistics.mean(r[3] for r in wmask):.9f} kW")

# 2) warm extracts — no latch anywhere; tail stats
for k in (1, 2, 3):
    rows = load(f"{REPO}/scratch/av_rb_warm_extract/island_{k}_warm_10ms.csv")
    brk = sum(1 for r in rows if int(r[4]) != 0)
    tail = [r for r in rows if r[0] >= 45.0]
    print(f"2) island {k}: rows={len(rows)} any_broken={brk} | tail wg={statistics.mean(r[1] for r in tail):.6f} P={statistics.mean(r[3] for r in tail):.6f} kW")
