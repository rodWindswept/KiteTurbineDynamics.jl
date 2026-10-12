#!/usr/bin/env python3
"""Aero counter-read receipts for NR-040 — winner segment torque margins.

Recomputes torque_capacity / segment_torque for S1..S5 from the
pair-extract CSV segment block (own arithmetic, not the receipt chain),
and compares each ratio against the signed register strings bit for bit.
Also reads the has_limit flags and echoes the capture line from the
extract log.

Seat: aero-validator. Date: 2026-10-12. NR-040 signed at `166e48e`.
Run from the repo root:  python3 scratch/av_counter_nr040.py
"""
import sys

CSV = "docs/reporting/figures/pair-extract/extract-winner-operating-point.csv"
LOG = "docs/reporting/figures/pair-extract/extract-winner-operating-point.log"

# Signed register strings, NR-040 (science-validator, 2026-10-12).
REGISTER = {
    "S1": "2.0287970973051634",
    "S2": "2.036175280501402",
    "S3": "2.0435436991749936",
    "S4": "2.0509817379918016",
    "S5": "2.6938375915900292",
}

print("aero counter-read NR-040 / winner segment torque margins")
print(f"source csv: {CSV}")
print()

ok = True
ratios = {}
with open(CSV) as fh:
    for line in fh:
        if not line.startswith("segment,"):
            continue
        f = line.rstrip("\n").split(",")
        sid = f[1]
        has_limit = f[6]
        tau = float(f[10])  # segment_torque_Nm (demand)
        cap = float(f[11])  # torque_capacity_Nm
        ratio = cap / tau   # capacity over demand
        ratios[sid] = ratio
        want = REGISTER[sid]
        exact = ratio == float(want)
        ok &= exact
        print(f"{sid} | capacity {f[11]} / demand {f[10]}")
        print(f"    = {ratio!r}")
        print(f"    hex {ratio.hex()}")
        print(f"    register {want} -> {'BIT-EQUAL' if exact else 'MISMATCH'}   has_limit={has_limit}")

print()
least = min(ratios, key=lambda k: ratios[k])
print(f"least ratio: {least} = {ratios[least]!r}  (quote 2.03)")
print(f"band S1..S4: {ratios['S1']:.2f} to {ratios['S4']:.2f}")

with open(LOG) as fh:
    for line in fh:
        if line.startswith("capture:"):
            print("capture tie (extract log):", line.strip())

print()
print("verdict:", "no material discrepancy — row stands as signed" if ok else "DISCREPANCY — STOP")
sys.exit(0 if ok else 1)
