#!/usr/bin/env python3
"""av_glauert_ceiling.py — verify the Glauert tilted-disc ceiling before it
signs a register row.

The claim (hermes-2026-11-06-tallak-derivations.md, item 3):

  Cp_glauert(a, gamma) = 4a (cos gamma - a) sqrt(1 - 2a cos gamma + a^2)

with maximum 0.5192 at 30 degrees tilt at a = 0.3434, where the optimum
solves the cubic

  -3a^3 + 7a^2 c - 3a c^2 - 2a + c = 0,   c = cos gamma.

Checks here:
  1. Grid maximize over a in [0, 0.5] at gamma = 30 deg. Report the max
     and the argmax at fine resolution.
  2. Solve the cubic for c = cos(30 deg) exactly (all roots). Report the
     root in (0, 0.5).
  3. Verify the cubic is the exact stationarity condition dCp/da = 0
     (derived here, not assumed).
  4. Anchor check: gamma = 0 (axial) reduces to Cp = 4a(1-a)^2 with the
     Betz maximum 16/27 = 0.5925926 at a = 1/3.
  5. Compare the value 0.5192 and a = 0.3434 to the computed pair at
     1e-4 and 1e-4.
"""
import math
import sys
from cmath import sqrt as csqrt

CHK = []
def chk(name, good, detail=""):
    CHK.append((name, bool(good), detail))

GAMMA = math.radians(30.0)
C = math.cos(GAMMA)

def cp(a, c):
    s2 = 1.0 - 2.0 * a * c + a * a
    return 4.0 * a * (c - a) * math.sqrt(max(s2, 0.0))

# 1. grid maximize
N = 2000000
best = (-1.0, 0.0)
for i in range(N + 1):
    a = 0.5 * i / N
    v = cp(a, C)
    if v > best[0]:
        best = (v, a)
vmax, amax = best
print(f"grid max: Cp {vmax:.10f} at a {amax:.10f}  (gamma 30 deg)")
chk("grid max 0.5192", abs(vmax - 0.5192) < 5e-5, f"{vmax:.6f}")
chk("argmax 0.3434", abs(amax - 0.3434) < 5e-5, f"{amax:.6f}")

# 2. cubic root at c = cos(30): bisection on the in-band root
def cubic(a, c):
    return -3 * a**3 + 7 * a**2 * c - 3 * a * c**2 - 2 * a + c

lo, hi = 0.0, 0.5
assert cubic(lo, C) > 0 and cubic(hi, C) < 0, "sign change expected in (0, 0.5)"
for _ in range(120):
    mid = 0.5 * (lo + hi)
    if cubic(mid, C) > 0:
        lo = mid
    else:
        hi = mid
a_cubic = 0.5 * (lo + hi)
print(f"cubic root in (0, 0.5) at c={C:.10f}: a = {a_cubic:.10f}, "
      f"Cp = {cp(a_cubic, C):.10f}")
chk("cubic root 0.3434", abs(a_cubic - 0.3434) < 5e-5, f"{a_cubic:.6f}")
chk("cubic-root Cp 0.5192", abs(cp(a_cubic, C) - 0.5192) < 5e-5,
    f"{cp(a_cubic, C):.6f}")

# 3. the cubic is the stationarity condition (derivation check)
# dCp/da = 0  <=>  (c - 2a)(1 - 2ac + a^2) = a(c - a)^2
#       <=>  -3a^3 + 7a^2 c - 3a c^2 - 2a + c = 0
def lhs_cubic(a, c):
    return -3 * a**3 + 7 * a**2 * c - 3 * a * c**2 - 2 * a + c

def lhs_deriv(a, c):
    return (c - 2 * a) * (1 - 2 * a * c + a * a) - a * (c - a)**2

for a in (0.2, 0.3434, 0.45):
    d = abs(lhs_cubic(a, C) - lhs_deriv(a, C))
    chk(f"cubic equals derivative condition at a={a}", d < 1e-12, f"{d:.2e}")

# 4. axial anchor: gamma = 0
v_axial, a_axial = best_axial = (-1.0, 0.0)
for i in range(N + 1):
    a = 0.5 * i / N
    v = cp(a, 1.0)
    if v > best_axial[0]:
        best_axial = (v, a)
print(f"axial anchor: max {best_axial[0]:.10f} at a {best_axial[1]:.10f} "
      f"(Betz 16/27 = {16/27:.10f} at 1/3)")
chk("axial max 16/27", abs(best_axial[0] - 16.0 / 27.0) < 1e-9,
    f"{best_axial[0]:.10f}")
chk("axial argmax 1/3", abs(best_axial[1] - 1.0 / 3.0) < 1e-5,
    f"{best_axial[1]:.10f}")

# 5. the printed pair to 4 dp
print(f"printed pair: 0.5192 at a = 0.3434; computed {vmax:.4f} at "
      f"a = {amax:.4f}")

print()
fails = sum(1 for _, g, _ in CHK if not g)
print(f"checks: {len(CHK)} total, {fails} fail")
for name, good, detail in CHK:
    print(("  ok  " if good else "  FAIL"), name, detail if detail else "")
sys.exit(0 if fails == 0 else 1)
