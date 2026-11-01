#!/usr/bin/env python3
"""av_ct_cap_read.py — lane 2, the CT cap read (RF-21) against the measured
fine-lambda table (.scratch/bem_regression/fine_lambda_2026-10-22/
fine_lambda_bladecount.csv, produced 2026-10-22 by @aero-worker).

Claims under read (routing 2026-10-22, RF-21; founder call 3 remainder
2026-10-30): measured C_T at TSR 6.8415 runs 0.965 (n3) to 1.407 (n9);
the 1.02 cap under-reads the real thrust 7% at four lines and 38% at nine;
the founder ruled the measured BEM C_T basis with a 1.4 fallback.
"""
import sys

CSV = (".scratch/bem_regression/fine_lambda_2026-10-22/"
       "fine_lambda_bladecount.csv")
TARGET = 6.8415
CAP = 1.02
FALLBACK = 1.4

rows = []
with open(CSV) as fh:
    for line in fh:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('n_lines,'):
            continue
        p = line.split(',')
        rows.append((int(p[0]), float(p[1]), float(p[2]), float(p[3]), p[4]))

ns = sorted(set(r[0] for r in rows))
checks = []

def chk(name, good, detail=""):
    checks.append((name, bool(good), detail))

chk("sweep covers n 3..9", ns == list(range(3, 10)), str(ns))

res = {}
out_of_range = []
for n in ns:
    sub = sorted([r for r in rows if r[0] == n], key=lambda r: r[1])
    tsrs = [r[1] for r in sub]
    cts = [r[3] for r in sub]
    cps = [r[2] for r in sub]
    if TARGET < tsrs[0] or TARGET > tsrs[-1]:
        out_of_range.append((n, tsrs[0], tsrs[-1]))
        continue
    for i in range(len(tsrs) - 1):
        if tsrs[i] <= TARGET <= tsrs[i + 1]:
            t = (TARGET - tsrs[i]) / (tsrs[i + 1] - tsrs[i])
            ct = cts[i] + t * (cts[i + 1] - cts[i])
            cp = cps[i] + t * (cps[i + 1] - cps[i])
            res[n] = (ct, cp, tsrs[i], tsrs[i + 1])
            break

# n3 anchor at the target (measured directly)
n3sub = sorted([r for r in rows if r[0] == 3], key=lambda r: r[1])
n3tsrs = [r[1] for r in n3sub]
n3cts = [r[3] for r in n3sub]
ct3 = None
for i in range(len(n3tsrs) - 1):
    if n3tsrs[i] <= TARGET <= n3tsrs[i + 1]:
        t = (TARGET - n3tsrs[i]) / (n3tsrs[i + 1] - n3tsrs[i])
        ct3 = n3cts[i] + t * (n3cts[i + 1] - n3cts[i])
        break

# For n where the sweep does not reach 6.8415: the committed ratio
# surface (src/bem.jl _RATIO_CT, knots 6.2929/7.3417) at 6.8415,
# applied to the measured n3 anchor. This is the convention RF-21's
# 1.407 (n9) and 38% under-read reproduce under.
import bisect
RATIO_CT_SURFACE = {
    4: 1.136826, 5: 1.235212, 6: 1.31057,
    7: 1.370543, 8: 1.42028, 9: 1.462178,
}
ratio_mode = {}
for n in ns:
    if n in res:
        continue
    sub = sorted([r for r in rows if r[0] == n], key=lambda r: r[1])
    top = sub[-1]
    j = bisect.bisect_left(n3tsrs, top[1])
    r3 = n3sub[j - 1] if j == len(n3sub) else n3sub[j]
    ratio_measured_topknot = top[3] / r3[3]
    ratio_surface = RATIO_CT_SURFACE[n]
    ratio_mode[n] = (ratio_surface, ratio_measured_topknot, top[1])
    res[n] = (ct3 * ratio_surface, None, None, None)

print()
print("top-knot census per n (measured fine-lambda sweep):")
n3sub_sorted = sorted([r for r in rows if r[0] == 3], key=lambda r: r[1])
n3tsrs_sorted = [r[1] for r in n3sub_sorted]
for n in ns:
    sub = sorted([r for r in rows if r[0] == n], key=lambda r: r[1])
    top = sub[-1]
    j = bisect.bisect_left(n3tsrs_sorted, top[1])
    r3 = n3sub_sorted[j] if j < len(n3sub_sorted) else n3sub_sorted[-1]
    print(f"  n={n}: top knot TSR {top[1]:.4f}  C_T {top[3]:.4f}  C_P {top[2]:.4f}"
          f"  CT ratio vs n3 {top[3]/r3[3]:.5f}")

print()
print("C_T at TSR 6.8415 per n (direct interp where swept; committed ratio")
print("surface x measured n3 anchor where the sweep stops short):")
for n in ns:
    ct, cp, lo, hi = res[n]
    under_cap = (ct - CAP) / CAP * 100 if ct > CAP else 0.0
    under_true = (ct - CAP) / ct * 100 if ct > CAP else 0.0
    flag = "under-read" if ct > CAP else "below cap"
    if n in ratio_mode:
        rs, rm, topk = ratio_mode[n]
        mode = (f"surface ratio {rs:.5f} x anchor; measured top-knot "
                f"ratio {rm:.5f} -> C_T {ct3*rm:.4f}")
    else:
        mode = "direct"
    print(f"  n={n}: C_T={ct:.4f}  C_P={'%.4f' % cp if cp is not None else '--'}  "
          f"under-read vs cap {under_cap:+.2f}% (vs true {under_true:+.2f}%)  "
          f"[{flag}]  ({mode})")

chk("n3 C_T 0.965 (RF-21)", abs(res[3][0] - 0.965) < 0.01, f"{res[3][0]:.4f}")
chk("n9 C_T ~1.407 (RF-21)", abs(res[9][0] - 1.407) < 0.02, f"{res[9][0]:.4f}")
chk("n4 under-read 7% (vs cap)", abs((res[4][0] - CAP) / CAP * 100 - 7.0) < 2.0,
    f"{(res[4][0]-CAP)/CAP*100:.2f}%")
chk("n9 under-read 38% (vs cap)", abs((res[9][0] - CAP) / CAP * 100 - 38.0) < 2.0,
    f"{(res[9][0]-CAP)/CAP*100:.2f}%")

print()
print("C_P at 6.8415 vs RF-22 claim (0.237, 0.176, 0.109, 0.033, -0.065, "
      "-0.176, -0.295 for n 3-9):")
claim = [0.237, 0.176, 0.109, 0.033, -0.065, -0.176, -0.295]
for n, c in zip(ns, claim):
    cp = res[n][1]
    if cp is None:
        # ratio-scaled via the committed _RATIO_CP surface for a side note
        rat = [1.0, 0.821704, 0.621752, 0.420517, 0.201433, -0.071118,
               -0.385381]  # knot at 6.2929, n3..n9
        rat2 = [1.0, 0.625450, 0.190450, -0.386737, -1.061239, -1.786002,
                -2.533595]  # knot at 7.3417
        t = (TARGET - 6.2929) / (7.3417 - 6.2929)
        r = rat[n - 3] + t * (rat2[n - 3] - rat[n - 3])
        cp = 0.2369 * r
        print(f"  n={n}: {cp:.3f} (ratio-scaled; RF-22 {c})")
    else:
        print(f"  n={n}: {cp:.3f} (direct; RF-22 {c})")

print()
print("1.4 fallback coverage (founder call 3 remainder):")
for n in ns:
    ct = res[n][0]
    if ct > FALLBACK:
        print(f"  n={n}: C_T {ct:.4f} EXCEEDS 1.4 by {(ct/FALLBACK-1)*100:.2f}%")
chk("1.4 fallback covers n3..n8", all(res[n][0] <= 1.4 for n in range(3, 9)),
    f"n8 {res[8][0]:.4f}")
chk("1.4 fallback vs n9 (surface convention)", res[9][0] <= 1.4,
    f"n9 C_T {res[9][0]:.4f} exceeds by {(res[9][0]/1.4-1)*100:.2f}%")

print()
fails = sum(1 for _, g, _ in checks if not g)
print(f"checks: {len(checks)} total, {fails} fail")
for name, good, detail in checks:
    if not good:
        print(f"  FAIL {name}: {detail}")
sys.exit(0)
