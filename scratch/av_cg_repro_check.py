#!/usr/bin/env python3
"""av corner-grid F-REPRO counter-check: the delivered set vs two fresh runs.

My runs (2026-10-15) ran the delivered script at the delivered extract in a
live tree at HEAD == origin; script-commit flag a4b4057. This check compares
the five location outputs byte-for-byte.

Run: /usr/bin/python3 scratch/av_cg_repro_check.py     (repo root)
"""
import hashlib
import sys
from pathlib import Path

kit = Path("docs/reporting/figures/machine-corner-grid")
runs = [Path("scratch/av_cg_run1"), Path("scratch/av_cg_run2")]
files = ["machine-corner-grid.png", "machine-corner-grid.svg",
         "machine-corner-grid.pdf", "manifest.json", "checks.log"]


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


print("corner-grid F-REPRO counter-check — delivered + two fresh runs (script commit a4b4057)")
n = fails = 0
for f in files:
    hs = {"delivered": sha(kit / f), "run1": sha(runs[0] / f), "run2": sha(runs[1] / f)}
    same = len(set(hs.values())) == 1
    n += 1
    if not same:
        fails += 1
    print(f"{f:30s} delivered={hs['delivered'][:16]} run1={hs['run1'][:16]} run2={hs['run2'][:16]}  {'OK' if same else 'DRIFT'}")
print("RESULT: all five outputs byte-identical across the delivered set and the two counter-runs"
      if not fails else "RESULT: DRIFT — see rows above")
print(f"checks: {n}, fail: {fails}")
sys.exit(0 if not fails else 1)
