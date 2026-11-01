#!/usr/bin/env python3
"""aero-worker 2026-11-01: the measured k* bracket off the fine-lambda table.

Reads the committed fine-lambda CSVs (aero seat, 2026-10-22) and solves the
MPPT condition C_P(lam)/lam^3 = k / (0.5 rho A R^3) on the measured n=3 curve.

Outputs: the measured peak, the k*/k ratio at the flown lambda, and the
operating point (lambda, omega, P, tau) at k = 2.24, 8.4, 8.9.
"""
import csv
import math

BASE = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"
N3 = BASE + "/.scratch/bem_regression/fine_lambda_2026-10-22/fine_lambda_n03c500.csv"
BC = BASE + "/.scratch/bem_regression/fine_lambda_2026-10-22/fine_lambda_bladecount.csv"

LAM_FLOWN = 6.8415   # NR-031 / RF-14
K_ARCH = 2.24


def load(path):
    rows = list(csv.DictReader([l for l in open(path) if not l.startswith("#")]))
    return [(float(r["TSR_meas"]), float(r["Cp"]), float(r["Ct_from_Fx"])) for r in rows]


n3 = sorted(load(N3))
print("n=3 points", len(n3), "lambda", n3[0][0], "to", n3[-1][0])

# parabolic peak on the three points around the max
i = max(range(len(n3)), key=lambda j: n3[j][1])
lam_pk, cp_pk = n3[i][0], n3[i][1]
print("grid peak Cp %.6f at lambda %.4f" % (cp_pk, lam_pk))
# 3-point parabolic refinement
(x1, y1, _), (x2, y2, _), (x3, y3, _) = n3[i - 1], n3[i], n3[i + 1]
den = (x1 - x2) * (x1 - x3) * (x2 - x3)
a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / den
b = (x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1) + x1 * x1 * (y2 - y3)) / den
lam_star = n3[i][0]          # the measured grid peak (RF-18 basis), not the fit
cp_star = n3[i][1]
print("peak used for k*: Cp %.6f at lambda %.4f (measured grid point)" % (cp_star, lam_star))


def cp_at(lam):
    """Linear interpolation on the measured n=3 curve."""
    if lam <= n3[0][0]:
        return n3[0][1]
    if lam >= n3[-1][0]:
        return n3[-1][1]
    for j in range(1, len(n3)):
        if lam <= n3[j][0]:
            (xa, ya, _), (xb, yb, _) = n3[j - 1], n3[j]
            return ya + (yb - ya) * (lam - xa) / (xb - xa)
    return n3[-1][1]


kf = lambda lam: cp_at(lam) / lam ** 3
ratio_star = kf(lam_star) / kf(LAM_FLOWN)
print("\nk*/k at flown lambda %.4f: %.6f" % (LAM_FLOWN, ratio_star))
print("k* = %.4f" % (ratio_star * K_ARCH))
print("bracket 8.4/2.24 = %.4f   8.9/2.24 = %.4f" % (8.4 / K_ARCH, 8.9 / K_ARCH))

# invert kf for a target k, in the window around the peak
def lam_for_k(k):
    target = k / K_ARCH * kf(LAM_FLOWN)
    lo, hi = n3[0][0], n3[-1][0]
    # kf is unimodal in the table window: bracket the root nearest the peak
    # scan for the crossing on each side, take the one closest to lambda_star
    cands = []
    for j in range(1, len(n3)):
        fa = kf(n3[j - 1][0]) - target
        fb = kf(n3[j][0]) - target
        if fa == 0:
            cands.append(n3[j - 1][0])
        elif fa * fb < 0:
            xa, xb = n3[j - 1][0], n3[j][0]
            for _ in range(80):
                xm = 0.5 * (xa + xb)
                if (kf(xa) - target) * (kf(xm) - target) <= 0:
                    xb = xm
                else:
                    xa = xm
            cands.append(0.5 * (xa + xb))
    if not cands:
        return None
    return min(cands, key=lambda l: abs(l - lam_star))


print("\n%-6s %10s %10s %10s %12s %12s" %
      ("k", "lambda", "Cp", "Ct", "tau/tau0", "P/P0"))
base = None
for k in (K_ARCH, 8.4, 8.9):
    lam = lam_for_k(k)
    if lam is None:
        print("%-6.2f  no root" % k)
        continue
    cp = cp_at(lam)
    ct = None
    for j in range(1, len(n3)):
        if lam <= n3[j][0]:
            (xa, _, ca), (xb, _, cb) = n3[j - 1], n3[j]
            ct = ca + (cb - ca) * (lam - xa) / (xb - xa)
            break
    # P and tau in coefficient form; ratios cancel 0.5 rho A V^3
    P = cp
    tau = cp / lam
    if base is None:
        base = (P, tau)
    print("%-6.2f %10.4f %10.5f %10.4f %12.4f %12.4f" %
          (k, lam, cp, ct, tau / base[1], P / base[0]))

# numeric derivatives across the bracket, coefficient form
l84, l89 = lam_for_k(8.4), lam_for_k(8.9)
p84, p89 = cp_at(l84), cp_at(l89)
t84, t89 = p84 / l84, p89 / l89
print("\ncoefficient-form (0.5 rho A V^3 = P / Cp):")
print("dP/dk   = %.6f Cp per k unit" % ((p89 - p84) / (8.9 - 8.4)))
print("dtau/dk = %.6f (Cp/lam) per k unit" % ((t89 - t84) / (8.9 - 8.4)))
print("relative: d lnP/dk = %.6f per k unit" % ((math.log(p89 / p84)) / 0.5))
print("relative: d lntau/dk = %.6f per k unit" % ((math.log(t89 / t84)) / 0.5))

# blade-count table: measured peak per n, for the row context
rows = list(csv.DictReader([l for l in open(BC) if not l.startswith("#")]))
byn = {}
for r in rows:
    byn.setdefault(int(r["n_lines"]), []).append((float(r["TSR_meas"]), float(r["Cp"])))
print("\nblade-count peaks:")
for n in sorted(byn):
    pts = sorted(byn[n])
    im = max(range(len(pts)), key=lambda j: pts[j][1])
    print("  n=%d  grid peak Cp %.5f at lambda %.4f  (%d points)" %
          (n, pts[im][1], pts[im][0], len(pts)))
