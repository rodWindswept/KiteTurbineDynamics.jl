#!/usr/bin/env python3
# sv_p0_items256_census.py — Phase 0 items 2, 5, 6 census (software-validator seat)
# Reads the bankderate2 telemetry CSVs only; no derivation without recipe.
import csv, math, sys, os
from collections import Counter

R = "/home/rod/Documents/GitHub/ktd-aw-fire/scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
ISLANDS = [1, 2, 3]
GENES = ["x1","x2","x3","x4","x5","x6","x7","x8","x9","x10"]
GENE_NAMES = {"x1":"r_hub","x2":"r_bot","x3":"target_Lr","x4":"n_lines","x5":"density",
              "x6":"rotor_count","x7":"bank_top","x8":"bank_bot","x9":"blade_scale_top","x10":"blade_scale_bottom"}

def load(island):
    p = f"{R}/island_{island}/telemetry.csv"
    rows, comment, header = [], None, None
    with open(p) as fh:
        for line in fh:
            if line.startswith("#"):
                comment = line.strip(); continue
            if header is None:
                header = line.strip().split(","); continue
            parts = line.strip().split(",")
            rows.append(dict(zip(header, parts)))
    return comment, header, rows

def fnum(v):
    try:
        return float(v)
    except Exception:
        return None

def stats(vals):
    vals = [v for v in vals if v is not None and math.isfinite(v)]
    if not vals:
        return "n=0"
    return f"n={len(vals)} min={min(vals):.3f} mean={sum(vals)/len(vals):.3f} max={max(vals):.3f}"

out = []
def P(*a):
    s = " ".join(str(x) for x in a); out.append(s); print(s)

comment, header, _ = load(1)
P("== telemetry provenance header (island 1; identical across islands) ==")
P(comment)
P(",".join(header))
P()

all_rows = []
for isl in ISLANDS:
    c, h, rows = load(isl)
    for r in rows:
        r["island"] = str(isl)
    all_rows.extend(rows)

P("### ITEM 2: gen-0 (seed rows) vs gen-1+ (DE children) ###")
for label, sel in (("gen0", lambda r: r["gen"] == "0"), ("gen1+", lambda r: r["gen"] != "0")):
    rr = [r for r in all_rows if sel(r)]
    P(f"-- {label}: n={len(rr)}")
    P("   status mix:", dict(Counter(r["status"] for r in rr)))
    ok = [r for r in rr if r["status"] == "ok"]
    P(f"   ok rows: {len(ok)}")
    for col in ["P_mean", "fitness", "FoS", "T_lift"]:
        P(f"   ok {col}: ", stats([fnum(r[col]) for r in ok]))
P("-- per island gen0 detail:")
for isl in ISLANDS:
    g0 = [r for r in all_rows if r["island"] == str(isl) and r["gen"] == "0"]
    P(f"   island {isl} gen0: n={len(g0)} status={dict(Counter(r['status'] for r in g0))}")
    P(f"      gen0 ok P_mean: {[r['P_mean'] for r in g0 if r['status']=='ok']}")
    P(f"      gen0 ok FoS   : {[r['FoS'] for r in g0 if r['status']=='ok']}")
    P(f"      gen0 fitness  : {[r['fitness'] for r in g0]}")
P("-- per-gen mean P_mean among ok rows (island: gen=mean@count, ...):")
for isl in ISLANDS:
    series = []
    for g in range(31):
        ok = [fnum(r["P_mean"]) for r in all_rows if r["island"] == str(isl) and int(r["gen"]) == g and r["status"] == "ok"]
        ok = [v for v in ok if v is not None and math.isfinite(v)]
        if ok:
            series.append(f"{g}:{sum(ok)/len(ok):.2f}@{len(ok)}")
    P(f"   island {isl}: " + " ".join(series))
P()

P("### ITEM 5: cross-island overlap (ok rows) ###")
for isl in ISLANDS:
    ok = [r for r in all_rows if r["island"] == str(isl) and r["status"] == "ok"]
    P(f"-- island {isl}: ok n={len(ok)}")
    for col in ["P_mean", "fitness", "FoS", "T_lift", "clearance", "r_hub"]:
        P(f"   {col}: ", stats([fnum(r[col]) for r in ok]))

def rng(isl, col):
    ok = [fnum(r[col]) for r in all_rows if r["island"] == str(isl) and r["status"] == "ok"]
    ok = [v for v in ok if v is not None and math.isfinite(v)]
    return (min(ok), max(ok)) if ok else (float('nan'), float('nan'))

for col in ["P_mean", "fitness", "FoS"]:
    r1, r2, r3 = rng(1, col), rng(2, col), rng(3, col)
    P(f"-- {col} ranges: i1={r1[0]:.2f}..{r1[1]:.2f}  i2={r2[0]:.2f}..{r2[1]:.2f}  i3={r3[0]:.2f}..{r3[1]:.2f}")
    for a, b, ra, rb in ((1, 2, r1, r2), (1, 3, r1, r3), (2, 3, r2, r3)):
        lo = max(ra[0], rb[0]); hi = min(ra[1], rb[1])
        P(f"     overlap {a}-{b}: " + (f"[{lo:.2f}, {hi:.2f}]" if lo <= hi else "EMPTY"))
P("-- gene value coverage (ok rows; min..max per island):")
for g in GENES:
    parts = []
    for isl in ISLANDS:
        vals = [fnum(r[g]) for r in all_rows if r["island"] == str(isl) and r["status"] == "ok"]
        vals = [v for v in vals if v is not None and math.isfinite(v)]
        parts.append(f"i{isl}:{min(vals):.4g}..{max(vals):.4g}" if vals else f"i{isl}:none")
    P(f"   {GENE_NAMES[g]} ({g}): " + "  ".join(parts))
P()

P("### ITEM 6: FoS non-finite census (all 930 rows) ###")
for col in ["FoS", "P_mean", "P_end", "T_lift", "fitness", "twist_ratio", "clearance"]:
    nonfin = 0; inf = 0; nan = 0; bystatus = Counter()
    for r in all_rows:
        v = r[col].strip().lower()
        if v in ("", "inf", "+inf", "-inf", "infinity", "-infinity", "nan") or "inf" in v or "nan" in v:
            nonfin += 1; bystatus[r["status"]] += 1
            if "inf" in v: inf += 1
            if "nan" in v: nan += 1
    P(f"   {col}: non-finite={nonfin} (inf={inf}, nan={nan}) by status: {dict(bystatus)}")
for st in ["ok", "reject", "clearance_reject", "reject_twist"]:
    vals = [fnum(r["FoS"]) for r in all_rows if r["status"] == st]
    vals = [v for v in vals if v is not None and math.isfinite(v)]
    if vals:
        P(f"   FoS finite [{st}]: min={min(vals):.4g} max={max(vals):.4g} n={len(vals)}")
z = [r for r in all_rows if r["status"] == "ok" and fnum(r["FoS"]) == 0.0]
P(f"   ok rows with FoS exactly 0: {len(z)}")
big = [r for r in all_rows if r["status"] == "ok" and (fnum(r["FoS"]) or 0) > 1e4]
P(f"   ok rows with FoS > 1e4: {len(big)}")

fn = "/home/rod/.hermes/profiles/software-validator/cache/scratch/sv_p0_items256_census.txt"
open(fn, "w").write("\n".join(out) + "\n")
print("\nsaved:", fn)
