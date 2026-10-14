#!/usr/bin/env python3
"""NR-045 evidence census - island generation counts, v13 5 kW screen.

Source: scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/
island_{1,2,3}/telemetry.csv (data commit dd3cc6a, era
post-95c385d_wind-authority).

Checks per island: 310 data rows; gen set 0..30 (31 values); exactly 10
rows per generation, idx 0..9. Checks anchors: gen-0 best equals
36.10892711736875 (NR-006); the global best 27.3635412663488 sits at
gen 26 (NR-005). Prints the island-3 best-so-far around the winner.
"""
import csv, sys
from collections import Counter, defaultdict

D = "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
fails = []

def load(i):
    p = f"{D}/island_{i}/telemetry.csv"
    with open(p) as f:
        body = [l for l in f if not l.lstrip().startswith("#")]
    header = body[0].rstrip("\n").split(",")
    rows = [r.rstrip("\n").split(",") for r in body[1:]]
    return header, rows

total = 0
for i in (1, 2, 3):
    header, rows = load(i)
    gi, xi = header.index("gen"), header.index("idx")
    gens = Counter(r[gi] for r in rows)
    gset = sorted(int(g) for g in gens)
    n = len(rows); total += n
    per = defaultdict(set)
    for r in rows:
        per[int(r[gi])].add(int(r[xi]))
    print(f"island {i}: rows={n}, gens {gset[0]}..{gset[-1]} ({len(gset)} values), "
          f"rows per gen={sorted(set(gens.values()))}, idx per gen={sorted({len(v) for v in per.values()})}")
    if n != 310: fails.append(f"island {i}: rows {n} != 310")
    if len(gset) != 31: fails.append(f"island {i}: {len(gset)} gens != 31")
    if set(gens.values()) != {10}: fails.append(f"island {i}: per-gen counts {set(gens.values())} != 10")

print(f"TOTAL rows={total}")
if total != 930: fails.append(f"total {total} != 930")

header, rows = load(3)
gi, fi = header.index("gen"), header.index("fitness")
best = defaultdict(lambda: float("inf"))
for r in rows:
    g, v = int(r[gi]), float(r[fi])
    if v < best[g]: best[g] = v
sbf = {}
run = float("inf")
for g in sorted(best):
    run = min(run, best[g]); sbf[g] = run
seed0 = best[0]
gm = min(best, key=lambda g: best[g])
# The telemetry stores fitness at three decimals (NR-012 precision note).
# The convergence files carry the full-precision forms. Cross-read both.
conv = f"{D}/island_3/convergence.csv"
with open(conv) as f:
    cbody = [l for l in f if not l.lstrip().startswith("#")]
crows = [r.rstrip("\n").split(",") for r in cbody[1:]]
first_c, last_c = float(crows[0][2]), float(crows[-1][2])
print(f"convergence island 3: first {first_c!r} (iter {crows[0][1]}), last {last_c!r} (iter {crows[-1][1]})")
print(f"anchor NR-006: gen-0 best = {seed0!r} (stored)")
print(f"anchor NR-005: global best = {best[gm]!r} (stored) at gen {gm}")
print("island 3 best-so-far, gens 24..30: " + ", ".join(f"{g}:{sbf[g]!r}" for g in range(24, 31)))
print(f"step gen-25 -> gen-26: {sbf[25]!r} -> {sbf[26]!r}  (delta {sbf[25]-sbf[26]!r})")
if abs(seed0 - 36.109) > 1e-9: fails.append(f"seed stored {seed0!r} != 36.109")
if abs(best[gm] - 27.364) > 1e-9: fails.append(f"winner stored {best[gm]!r} != 27.364")
if round(first_c, 3) != seed0: fails.append(f"convergence first {first_c!r} -> 3dp != seed {seed0!r}")
if round(last_c, 3) != best[gm]: fails.append(f"convergence last {last_c!r} -> 3dp != winner {best[gm]!r}")
step = sbf[25] - sbf[26]
if abs(step - 0.951) > 1e-9: fails.append(f"step {step!r} != 0.951")

print("RESULT:", "FAIL: " + "; ".join(fails) if fails else "PASS (all checks)")
sys.exit(1 if fails else 0)
