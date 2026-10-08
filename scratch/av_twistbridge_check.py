#!/usr/bin/env python3
"""Twist-bridge content check — census cross-tab. Seat: aero-validator, 2026-10-08.

Reads the three island telemetry CSVs of the bankderate2 campaign (record read
only; runs no simulator) and verifies the reject_twist <-> twist_crossed mapping
across all 930 evaluations. Also reproduces the NR-002 status mix.
"""
import csv
import collections
import os

BASE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "scripts",
    "results",
    "v13_5kw_masslift_len18.8_rotorcount_bankderate2",
)


def rows(isl):
    with open(os.path.join(BASE, f"island_{isl}", "telemetry.csv")) as f:
        f.readline()  # provenance comment line
        yield from csv.DictReader(f)


combos = collections.Counter()
crossed = []
total = 0
status_mix = collections.Counter()
for isl in (1, 2, 3):
    for row in rows(isl):
        total += 1
        status_mix[row["status"]] += 1
        combos[(row["status"], row["twist_crossed"])] += 1
        if row["twist_crossed"] == "true":
            crossed.append(
                (isl, int(row["gen"]), int(row["idx"]), row["status"], float(row["twist_ratio"]))
            )

print("total rows:", total)
print("status mix:", dict(status_mix))
expected = {"ok": 508, "reject": 301, "clearance_reject": 110, "reject_twist": 11}
assert dict(status_mix) == expected, f"status mix moved: {dict(status_mix)}"
print("NR-002 status mix reproduced: 508 ok / 301 reject / 110 clearance_reject / 11 reject_twist")
print()
print("status x twist_crossed:")
for (s, tc), c in sorted(combos.items()):
    print(f"  status={s:18s} twist_crossed={tc:5s} -> {c}")
print()
print(f"rows with twist_crossed=true ({len(crossed)}):")
for r in crossed:
    print(" ", r)
assert all(r[3] == "reject_twist" for r in crossed), "crossed flag off the reject_twist channel"
assert all(r[4] > 1.0 for r in crossed), "a crossed row reads a ratio <= 1"
print()
print("PASS: twist_crossed=true appears only on reject_twist rows; all ratios > 1.")
