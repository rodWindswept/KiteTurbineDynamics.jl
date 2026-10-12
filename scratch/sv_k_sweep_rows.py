#!/usr/bin/env python3
# scratch/sv_k_sweep_rows.py — science-validator, 2026-10-12.
#
# Reads the committed honest-window k sweep (scripts/results/k_sweep_daisy_5kw.csv,
# blob d17d1377b191dde5b44df7f5534d0cdc4c48d0f3, landed adea1a3) and re-derives
# every value, quote form and boundary read the NR-041 row carries. Read-only.
#
# Run: python3 scratch/sv_k_sweep_rows.py
import csv
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "scripts/results/k_sweep_daisy_5kw.csv"

EXPECTED_K = ["0.5", "1.0", "1.5", "1.94", "2.24", "3.0", "4.0", "5.39", "7.0", "9.0"]
# quote forms at 2 dp, in k order (pinned from the stored digits)
EXPECTED_Q = ["3.49", "5.45", "6.78", "7.56", "8.00", "8.89", "8.95", "8.95", "8.95", "8.95"]

failures = []

def check(label, ok, info=""):
    tag = "OK " if ok else "FAIL"
    print(f"[{tag}] {label} {info}")
    if not ok:
        failures.append(label)

raw = CSV_PATH.read_bytes()
print(f"file: {CSV_PATH}")
print(f"sha256: {hashlib.sha256(raw).hexdigest()}")
print(f"bytes: {len(raw)}  newline_at_eof: {raw.endswith(b'\n')}")

rows = list(csv.reader(raw.decode().splitlines()))
header, data = rows[0], rows[1:]
print(f"column line: {header}")
print(f"data rows: {len(data)}")

check("header is the stored column line",
      header == ["k", "status", "P_mean", "P_end", "omega_eq", "omega_final", "FoS_min", "T_lift", "wall_s"])
check("ten data rows", len(data) == 10)
check("k column as stored", [r[0] for r in data] == EXPECTED_K)

# 1. quote forms and statuses
quotes = []
statuses = []
for r in data:
    pm = float(r[2])
    quotes.append(f"{pm:.2f}")
    statuses.append(r[1])
    print(f"k={r[0]:>4}  status={r[1]:>6}  P_mean={r[2]}  quote_2dp={pm:.2f}  P_end={r[3]}  FoS_min={r[6]}")
check("P_mean quote forms at 2 dp", quotes == EXPECTED_Q, str(quotes))

# 2. the light end: k=0.5 under the 5.0 kW floor, and it is the only reject
floor = 5.0
pm05 = float(data[0][2])
check("k=0.5 P_mean below the 5.0 kW floor", pm05 < floor, f"{pm05}")
check("k=0.5 is the only reject row", statuses == ["reject"] + ["ok"] * 9)

# 3. plateau at the heavy end
plateau = [float(r[2]) for r in data if r[0] in ("4.0", "5.39", "7.0", "9.0")]
print("plateau P_mean min/max over k 4.0..9.0: %.12f %.12f" % (min(plateau), max(plateau)))
check("plateau band 8.9475 to 8.9511", abs(min(plateau) - 8.947502018555182) < 1e-12 and abs(max(plateau) - 8.95105174397467) < 1e-12)

# 4. P_mean vs P_end agreement
diffs = [abs(float(r[2]) - float(r[3])) / float(r[3]) * 100.0 for r in data]
print("P_mean vs P_end relative difference, per cent: " + ", ".join(f"{d:.4f}" for d in diffs))
check("P_mean vs P_end below 0.5 per cent at every row", max(diffs) < 0.5, f"max {max(diffs):.4f} per cent")

# 5. clamp reads: tau_end = P_end(W) / omega_final on the plateau rows
print("tau_end = P_end*1000/omega_final on the plateau rows:")
for r in data:
    if r[0] in ("3.0", "4.0", "5.39", "7.0", "9.0"):
        tau = float(r[3]) * 1000.0 / float(r[5])
        print(f"  k={r[0]:>4}  tau_end={tau:.6f} N.m")
taus = [float(r[3]) * 1000.0 / float(r[5]) for r in data if r[0] in ("4.0", "5.39", "7.0", "9.0")]
check("plateau tau_end within 625 +/- 1 N.m", all(624.0 <= t <= 626.0 for t in taus))

# 6. era cap vs current cap
era_cap = 2500.0 * ((5000.0 / 10000.0) ** 2)
cur_cap = (22.65 / 300.0 ** 1.5) * 5000.0 ** 1.5
print(f"era cap (2500 x (P/10^4)^2 at 5 kW): {era_cap}")
print(f"current cap (D4 law at 5 kW): {cur_cap!r}")
check("era cap reads 625.0", era_cap == 625.0)
check("current cap reads 1541.137296501083", abs(cur_cap - 1541.137296501083) < 1e-9)

# 7. omega_eq column
oe = sorted(set(r[4] for r in data))
print("omega_eq column distinct values:", oe)
check("omega_eq reads 0.0 on all rows", oe == ["0.0"])

# 8. the omega_final swing (readable field)
wf = [float(r[5]) for r in data]
print("omega_final window-end ground ring: %.12f (k=0.5) to %.12f (k=1.0)" % (wf[0], wf[1]))
print(f"omega_final k=9.0: {wf[9]}")

print()
if failures:
    print(f"RESULT: FAIL ({len(failures)}): {failures}")
    sys.exit(1)
print("RESULT: all checks pass (rc=0)")
