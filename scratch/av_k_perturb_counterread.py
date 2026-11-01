#!/usr/bin/env python3
"""av_k_perturb_counterread.py — counter-read the aero-worker's two-point k
static table (aero-worker-2026-11-01-k-perturbation.md) against the measured
fine-lambda n=3 curve (.scratch/bem_regression/fine_lambda_2026-10-22/
fine_lambda_n03c500.csv).

Checks:
  1. The curve peak: Cp 0.312928 at lambda 4.8246.
  2. The bracket straddle: k 8.4 -> lambda 4.8319 (right of the peak),
     k 8.9 -> lambda 4.7379 (left of the peak); k* 8.4387 sits inside.
  3. The Cp reads at the two lambdas: 0.31292 and 0.31256.
  4. The power and speed columns: P_arc x Cp/Cp_arc, omega_arc x
     lambda/lambda_arc at P_arc 5.310 kW, omega_arc 13.3852 rad/s,
     Cp_arc 0.23686 at lambda_arc 6.8415.
  5. The torque arithmetic and the two charges: x1.871 at 8.4 and
     x1.906 at 8.9 against the archive torque 396.71 N m.
  6. The two-point slopes: dP/dk -16.1 W per k unit, dtau/dk +27.7 N m
     per k unit.
"""
import csv

CSV_N3 = (".scratch/bem_regression/fine_lambda_2026-10-22/"
          "fine_lambda_n03c500.csv")

pts = []
with open(CSV_N3) as fh:
    for line in fh:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('TSR_meas,'):
            continue
        p = line.split(',')
        pts.append((float(p[0]), float(p[1]), float(p[2]), float(p[3]), float(p[4])))

pts.sort(key=lambda r: r[0])
tsrs = [r[0] for r in pts]
cps = [r[1] for r in pts]
cts = [r[2] for r in pts]

def interp(tsrs, vals, x):
    for i in range(len(tsrs) - 1):
        if tsrs[i] <= x <= tsrs[i + 1]:
            t = (x - tsrs[i]) / (tsrs[i + 1] - tsrs[i])
            return vals[i] + t * (vals[i + 1] - vals[i])
    return None

CHK = []
def chk(name, good, detail=""):
    CHK.append((name, bool(good), detail))

# 1. peak
ipeak = max(range(len(pts)), key=lambda i: cps[i])
chk("peak Cp 0.312928 at 4.8246",
    abs(cps[ipeak] - 0.312928) < 5e-5 and abs(tsrs[ipeak] - 4.8246) < 0.01,
    f"peak {cps[ipeak]:.6f} at {tsrs[ipeak]:.4f}")

# 2. the lambda->k mapping on the measured curve
P_ARC, OM_ARC, CP_ARC, LAM_ARC = 5310.0, 13.3852, 0.23686, 6.8415
K_ARC = 2.24

def k_from_lam(lam):
    cp = interp(tsrs, cps, lam)
    return K_ARC * (cp / lam**3) / (CP_ARC / LAM_ARC**3)

lam84 = interp(tsrs, tsrs, 4.8319) or 4.8319
lam89 = 4.7379
k84 = k_from_lam(lam84)
k89 = k_from_lam(lam89)
cp84 = interp(tsrs, cps, lam84)
cp89 = interp(tsrs, cps, lam89)
print(f"measured curve: k(4.8319) = {k84:.4f}  (expect 8.4), Cp {cp84:.6f} (expect 0.31292)")
print(f"measured curve: k(4.7379) = {k89:.4f}  (expect 8.9), Cp {cp89:.6f} (expect 0.31256)")
chk("k(4.8319) reads 8.4", abs(k84 - 8.4) < 0.05, f"{k84:.4f}")
chk("k(4.7379) reads 8.9", abs(k89 - 8.9) < 0.05, f"{k89:.4f}")
chk("Cp(4.8319) 0.31292", abs(cp84 - 0.31292) < 5e-4, f"{cp84:.6f}")
chk("Cp(4.7379) 0.31256", abs(cp89 - 0.31256) < 5e-4, f"{cp89:.6f}")

# peak straddle: peak lambda 4.8246 sits between 4.7379 and 4.8319
chk("peak lambda between the bracket lambdas", 4.7379 < 4.8246 < 4.8319)
kstar = K_ARC * (0.312928 / 4.8246**3) / (CP_ARC / LAM_ARC**3)
chk("k* 8.4387 straddled by 8.4..8.9", 8.4 < kstar < 8.9, f"{kstar:.4f}")

# 3-4. power and speed columns
P84 = P_ARC * cp84 / CP_ARC
P89 = P_ARC * cp89 / CP_ARC
W84 = OM_ARC * lam84 / LAM_ARC
W89 = OM_ARC * lam89 / LAM_ARC
chk("P at k 8.4 reads 7015.1 W", abs(P84 - 7015.1) < 2.0, f"{P84:.2f}")
chk("P at k 8.9 reads 7007.1 W", abs(P89 - 7007.1) < 2.0, f"{P89:.2f}")
chk("omega at k 8.4 reads 9.4535", abs(W84 - 9.4535) < 5e-3, f"{W84:.4f}")
chk("omega at k 8.9 reads 9.2696", abs(W89 - 9.2696) < 5e-3, f"{W89:.4f}")

# 5. torque
tau84 = P84 / W84
tau89 = P89 / W89
tau_arc = P_ARC / OM_ARC
chk("tau at k 8.4 reads 742.07 N m", abs(tau84 - 742.07) < 0.1, f"{tau84:.3f}")
chk("tau at k 8.9 reads 755.92 N m", abs(tau89 - 755.92) < 0.1, f"{tau89:.3f}")
chk("archive torque 396.71 N m", abs(tau_arc - 396.71) < 0.1, f"{tau_arc:.3f}")
chk("charge x1.871 at 8.4", abs(tau84 / tau_arc - 1.871) < 2e-3, f"{tau84/tau_arc:.4f}")
chk("charge x1.906 at 8.9", abs(tau89 / tau_arc - 1.906) < 2e-3, f"{tau89/tau_arc:.4f}")

# 6. slopes
dPdk = (P89 - P84) / 0.5
dtauk = (tau89 - tau84) / 0.5
chk("dP/dk -16.1 W per k", abs(dPdk + 16.1) < 0.5, f"{dPdk:.2f}")
chk("dtau/dk +27.7 N m per k", abs(dtauk - 27.7) < 0.5, f"{dtauk:.2f}")

print()
fails = sum(1 for _, g, _ in CHK if not g)
print(f"checks: {len(CHK)} total, {fails} fail")
for name, good, detail in CHK:
    print(("  ok  " if good else "  FAIL"), name, detail if detail else "")
