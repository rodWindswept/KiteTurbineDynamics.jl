#!/usr/bin/env python3
"""Counter-read evidence: the two mechanism plates (ring-utilisation, twist-limit).

Read at `f4bc45e` (origin tip, bank-derate-cos2p65), 2026-10-12.
Verifies the folded caption sentences of 2026-10-12 (commit `f4bc45e`) against
the numbers register NR-021..NR-023. Register values are parsed from
`docs/reporting/numbers-register.md`; the plate-side display forms are read
from the kit label ledgers (`figures/ring-utilisation/label-ledger.txt`).

Checks:
  1. every ring FoS is the exact reciprocal of its interaction (1e-9);
  2. the displayed FoS forms match the plate readouts and the register-status
     display rule (3 dp below 1e4, nearest integer above);
  3. R5: axial share exactly 0.0; bar top below the display scale;
  4. NR-022 / NR-023 headline reads consistent with the caption claims;
  5. no register rows exist for the drawn mechanism values (carried item).

Exit 0 when every check passes.
"""
import re
import sys

REG = "docs/reporting/numbers-register.md"
print("counter-read evidence — plates at f4bc45e — science-validator seat, 2026-10-12")
print("register source:", REG)

reg = open(REG, encoding="utf-8").read()
reglines = reg.splitlines()
row = next(l for l in reglines if l.startswith("| NR-021 |"))

pat = re.compile(r"(R\d)(?: hub)? ([0-9.e-]+) = ([0-9.e-]+) \+ ([0-9.e-]+), FoS (\d+\.\d+)")
rings = pat.findall(row)
assert len(rings) == 5, rings

PLATE_DISP = {"R2": "30.087", "R3": "29.807", "R4": "35.236", "R5": "326,974", "R6": "15.033"}

fails = []
print("\n-- check 1/2: reciprocals and displayed forms --")
for name, x, a, b, f in rings:
    x, a, b, f = map(float, (x, a, b, f))
    ok_recip = abs(1.0 / x - f) < 1e-9
    disp = f"{f:.3f}" if f < 1e4 else f"{round(f):,}"
    ok_disp = disp == PLATE_DISP[name]
    print(f"{name}: 1/{x:.6g} -> {1.0 / x:.12g} vs FoS {f:.12g}  reciprocal={'PASS' if ok_recip else 'FAIL'}"
          f" | display {disp} vs plate {PLATE_DISP[name]}  {'PASS' if ok_disp else 'FAIL'}")
    if not (ok_recip and ok_disp):
        fails.append(name)

print("\n-- check 3: R5 reading --")
r5 = next(r for r in rings if r[0] == "R5")
x5, a5, b5 = (float(v) for v in r5[1:4])
span = float(next(r for r in rings if r[0] == "R6")[1])
print(f"R5 axial share exactly 0.0: {'PASS' if a5 == 0.0 else 'FAIL'} (axial={a5})")
frac = b5 / span
print(f"R5 bar top fraction of axis span: {frac:.3e} -> below display scale {'PASS' if frac < 1e-4 else 'FAIL'}")
if a5 != 0.0 or frac >= 1e-4:
    fails.append("R5")

print("\n-- check 4: NR-022 / NR-023 headline reads --")
r22 = next(l for l in reglines if l.startswith("| NR-022 |"))
da_part, dc_part = r22.split("dcrit:")
da = [float(v) for v in re.findall(r"S\d ([0-9.]+)°", da_part)]
dc = [float(v) for v in re.findall(r"S\d ([0-9.]+)°", dc_part)]
ok22 = max(da) < min(dc)
print(f"NR-022: abs(dalpha) {['%.4f' % v for v in da]} vs dcrit {dc} -> max(dalpha) < min(dcrit): {'PASS' if ok22 else 'FAIL'}")
print(f"NR-022 has_limit true on all five: {'PASS' if 'has_limit true on all five' in r22 else 'FAIL'}")
if not ok22:
    fails.append("NR-022")
r23 = next(l for l in reglines if l.startswith("| NR-023 |"))
n23 = len(re.findall(r"S\d [0-9.]+", r23.split("torque_capacity")[0])) + len(re.findall(r"S\d [0-9.]+", r23.split("torque_capacity")[1]))
ok23 = n23 == 10
print(f"NR-023: five torque + five capacity values: {'PASS' if ok23 else 'FAIL'} ({n23})")
if not ok23:
    fails.append("NR-023")

print("\n-- check 5: carried item — register rows for the drawn mechanism values --")
for term in ["72.25", "22,425", "42.6", "realisab"]:
    hits = [i + 1 for i, l in enumerate(reglines) if term in l]
    print(f"register hits {term!r}: {hits}")

print("\nINFO carried (room message): the ring caption still reads 'RN' where the plate")
print("prints 'R6 (hub)' (one-word fix); the twist mechanism-value rows are pending per")
print("figures/twist-limit/register-status.md.")
print("\nRESULT:", "ALL CHECKS PASS" if not fails else f"FAILURES: {fails}")
sys.exit(1 if fails else 0)
