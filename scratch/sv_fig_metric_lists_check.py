#!/usr/bin/env python3
"""Metric-card value sourcing for fig Batch B (science-validator, 2026-10-18).

Verifies, from the committed records:
  A. The seven strip milestones: fitness digits == NR-036 signed digits,
     P_mean/P_end read from the certified extract, parity against island_3
     telemetry bit for bit.
  B. The four corner picks: fitness digits == NR-051 signed block digits,
     P_mean/P_end read from the certified corner extract, parity against
     the island telemetry bit for bit.

Exit 0 = all checks pass. Prints the two lists.
"""
import csv, io, re, sys

ROOT = "/home/rod/Documents/GitHub/KiteTurbineDynamics.jl"
REG = open(f"{ROOT}/docs/reporting/numbers-register.md").read()

# --- NR-036 signed milestones ---
m = re.search(r"NR-036.*?\|\s*([\d.]+ \(gen \d+\)).*?\|\s*kg", REG, re.DOTALL)
row36 = re.search(r"^\| NR-036 \|.*", REG, re.M).group(0)
assert "36.109 (gen 0)" in row36 and "32.293 (gen 6)" in row36 and "31.661 (gen 10)" in row36
assert "30.929 (gen 18)" in row36 and "29.854 (gen 22)" in row36 and "28.315 (gen 25)" in row36 and "27.364 (gen 26)" in row36
signed36 = {"0": "36.109", "6": "32.293", "10": "31.661", "18": "30.929", "22": "29.854", "25": "28.315", "26": "27.364"}

# --- NR-051 signed corner objectives ---
block51 = REG[REG.index("| NR-051 |"):]
for v in ["60.646", "58.864", "33.704", "33.812"]:
    assert v in block51, f"NR-051 block missing {v}"
signed51 = {"i1-g13-i1": "60.646", "i1-g7-i7": "58.864", "i2-g21-i4": "33.704", "i3-g26-i8": "33.812"}

def data_rows(path):
    return [l for l in open(path).read().splitlines() if l and not l.startswith("#")]

strip = list(csv.DictReader(data_rows(f"{ROOT}/docs/reporting/figures/machine-evolution-strip/extract-best-so-far.csv")))
corner = list(csv.DictReader(data_rows(f"{ROOT}/docs/reporting/figures/machine-corner-grid/extract-corner-grid.csv")))

# --- A: strip ---
assert len(strip) == 7, f"strip rows {len(strip)}"
checks = 0
for r in strip:
    g = r["selected_gen"]
    assert signed36[g] == r["fitness"], f"milestone {g} fitness drift: {r['fitness']}"
    checks += 1
strip_power = [(r["selected_gen"], r["P_mean"], r["P_end"]) for r in strip]

# --- B: corner ---
assert len(corner) == 4, f"corner rows {len(corner)}"
for r in corner:
    assert signed51[r["tag"]] == r["fitness"], f"pick {r['tag']} fitness drift: {r['fitness']}"
    checks += 1
corner_power = [(r["tag"], r["fitness"], r["P_mean"], r["P_end"]) for r in corner]

# --- telemetry parity, all 11 rows ---
for r in strip + corner:
    island, gen, idx = r["island"], r["gen"], r["idx"]
    tel = f"{ROOT}/scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_{island}/telemetry.csv"
    tr = csv.DictReader(data_rows(tel))
    hits = [x for x in tr if x["gen"] == gen and x["idx"] == idx]
    assert len(hits) == 1, f"telemetry hits {len(hits)} for island {island} gen {gen} idx {idx}"
    h = hits[0]
    for f in ("fitness", "P_mean", "P_end"):
        assert h[f] == r[f], f"telemetry parity drift {r.get('tag', r['selected_gen'])} {f}: {h[f]} vs {r[f]}"
        checks += 1

print(f"checks: {checks}, 0 fail")
print("strip milestone power (P_mean, P_end, kW):")
for g, pm, pe in strip_power:
    print(f"  gen {g:>2}: {pm}, {pe}")
print("corner pick objective and power (objective, P_mean, P_end):")
for tag, fit, pm, pe in corner_power:
    print(f"  {tag}: {fit}, {pm}, {pe}")
