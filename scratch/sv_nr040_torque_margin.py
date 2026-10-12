#!/usr/bin/env python3
# sv_nr040_torque_margin.py — NR-040 winner segment torque margins (science-validator, 2026-10-12)
# Derives the row: capacity over demand, segment by segment, at the declared pair capture.
# Inputs (full precision): the NR-023 register strings and the raw extract segment block.
# Each input is cross-checked against the raw artifact before the arithmetic runs. Stdlib only.
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def read(rel):
    with open(os.path.join(ROOT, rel)) as f:
        return f.read()

reg = read("docs/reporting/numbers-register.md")
csvtext = read("docs/reporting/figures/pair-extract/extract-winner-operating-point.csv")
review = read("docs/reporting/feedback/2026-10-10-harris-review.md")

# ---------------------------------------------------------------------------
# Inputs: the NR-023 register strings
# ---------------------------------------------------------------------------
row = [l for l in reg.splitlines() if l.startswith("| NR-023 |")][0]
m = re.search(r"segment_torque: (.*?)\. torque_capacity: (.*?) \|", row)
torq_reg = {mm.group(1): mm.group(2) for mm in re.finditer(r"(S\d) ([0-9.eE+-]+)", m.group(1))}
cap_reg = {mm.group(1): mm.group(2) for mm in re.finditer(r"(S\d) ([0-9.eE+-]+)", m.group(2))}

# ---------------------------------------------------------------------------
# Raw artifact: the extract segment block (columns 10, 11)
# ---------------------------------------------------------------------------
seg = {}
for line in csvtext.splitlines():
    if line.startswith("segment,"):
        f = line.split(",")
        seg[f[1]] = (f[10], f[11])  # segment_torque_Nm, torque_capacity_Nm

ok = True
print("-- self-checks: NR-023 strings against the raw extract, bit for bit --")
for s in ("S1", "S2", "S3", "S4", "S5"):
    good = (float(torq_reg[s]) == float(seg[s][0])) and (float(cap_reg[s]) == float(seg[s][1]))
    print(("OK  " if good else "FAIL") + "  %s torque %s  capacity %s" % (s, torq_reg[s], cap_reg[s]))
    ok = ok and good

# ---------------------------------------------------------------------------
# The row: capacity over demand, segment by segment
# ---------------------------------------------------------------------------
print("-- recomputation (Float64, capacity over demand) --")
ratios = {}
for s in ("S1", "S2", "S3", "S4", "S5"):
    r = float(cap_reg[s]) / float(torq_reg[s])
    ratios[s] = r
    print("%s  %r  %.17g" % (s, r, r))

least = min(ratios, key=ratios.get)
band_ok = (least == "S1") and (round(ratios["S1"], 2) == 2.03) and (round(ratios["S4"], 2) == 2.05)
print("least:", least)
print("S1 recipe:", repr(float(cap_reg["S1"]) / float(torq_reg["S1"])))
print("quote forms: S1 %.2f; band S1 to S4 %.2f to %.2f; S5 %.2f"
      % (ratios["S1"], ratios["S1"], ratios["S4"], ratios["S5"]))
ok = ok and band_ok

# ---------------------------------------------------------------------------
# Cross-read: the Harris review band (2026-10-10)
# ---------------------------------------------------------------------------
print("-- cross-read: Harris review band (2026-10-10) --")
rev_ok = bool(re.search(r"S1.S4 are 2\.03.2\.05", review)) and (round(ratios["S5"], 2) == 2.69)
print(("OK  " if rev_ok else "FAIL") + "  review reads the S1 to S4 band as 2.03 to 2.05")
ok = ok and rev_ok

if not ok or least != "S1":
    print("SV_NR040_FAIL")
    sys.exit(1)
print("SV_NR040_DONE  (S1 governs at 2.0287970973051634; band confirmed)")
