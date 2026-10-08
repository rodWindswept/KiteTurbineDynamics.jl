#!/usr/bin/env python3
# sv_p0_secondread_census.py — Phase 0 second read (science-validator).
# Independent re-derivation of the software-validator census, run from the
# committed bankderate2 telemetry CSVs only. Every check prints its verdict
# against the claim in docs/validation/2026-10-08-phase0-bankderate2-audit.md.
import math
from collections import Counter

RDIR = "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
ISL = [1, 2, 3]
COLS = ["island", "gen", "idx", "fitness", "status", "P_mean", "P_end", "T_lift",
        "FoS", "twist_crossed", "twist_ratio", "clearance", "n_lines", "rings",
        "n_active", "r_hub", "r_bot", "bank_top", "bank_bot", "blade_scale_top",
        "blade_scale_bottom", "tether", "x1", "x2", "x3", "x4", "x5", "x6", "x7",
        "x8", "x9", "x10"]

def rows_of(isl):
    out = []
    with open(f"{RDIR}/island_{isl}/telemetry.csv") as fh:
        for ln in fh:
            if ln.startswith("#") or ln.startswith("island,"):
                continue
            out.append(dict(zip(COLS, ln.rstrip("\n").split(","))))
    return out

def num(r, c):
    try:
        f = float(r[c])
        return f if math.isfinite(f) else None
    except ValueError:
        return None

def rng(vals):
    vals = [v for v in vals if v is not None]
    return (min(vals), max(vals), sum(vals) / len(vals), len(vals)) if vals else None

all_rows, per_isl = [], {}
for i in ISL:
    per_isl[i] = rows_of(i)
    all_rows += per_isl[i]

ok = [r for r in all_rows if r["status"] == "ok"]
rej = [r for r in all_rows if r["status"] != "ok"]

checks = []
def ck(tag, cond, detail=""):
    checks.append(f"[{'PASS' if cond else 'FAIL'}] {tag}{(' — ' + detail) if detail else ''}")

ck("C1 rows: 930 total, 310/island, 10 per (island,gen), gens 0..30",
   len(all_rows) == 930 and all(len(per_isl[i]) == 310 for i in ISL)
   and set(Counter((r["island"], r["gen"]) for r in all_rows).values()) == {10}
   and all(sorted({int(r["gen"]) for r in per_isl[i]}) == list(range(31)) for i in ISL),
   f"total={len(all_rows)}, per-island={ {i: len(per_isl[i]) for i in ISL} }")

mix = Counter(r["status"] for r in all_rows)
ck("C2 status mix {ok:508, reject:301, clearance_reject:110, reject_twist:11}, no other class",
   dict(mix) == {"ok": 508, "reject": 301, "clearance_reject": 110, "reject_twist": 11},
   str(dict(mix)))

g0 = [r for r in all_rows if r["gen"] == "0"]
g0ok = [r for r in g0 if r["status"] == "ok"]
seed_ids = sorted({tuple(r[c] for c in COLS if c != "island") for r in g0ok})
ck("C3 gen0: 30 rows, 3 ok (one per island), seed rows byte-identical across islands",
   len(g0) == 30 and len(g0ok) == 3 and len(seed_ids) == 1,
   f"seed: fit={g0ok[0]['fitness']} P_mean={g0ok[0]['P_mean']} FoS={g0ok[0]['FoS']} T_lift={g0ok[0]['T_lift']}")

ch = [r for r in all_rows if r["gen"] != "0"]
chok = [r for r in ch if r["status"] == "ok"]
ck("C5 children: 900 rows, 505 ok", len(ch) == 900 and len(chok) == 505,
   f"children rows={len(ch)} ok={len(chok)}")

pm_child = rng([num(r, "P_mean") for r in chok])
ck("C6 seed P_mean 5.85 inside child band 5.02-6.32",
   abs(pm_child[0] - 5.020) < 1e-9 and abs(pm_child[1] - 6.320) < 1e-9 and 5.02 <= 5.85 <= 6.32,
   f"child band {pm_child[0]}..{pm_child[1]} (n={pm_child[3]})")

for i in ISL:
    oki = [r for r in per_isl[i] if r["status"] == "ok"]
    pm = rng([num(r, "P_mean") for r in oki])
    print(f"  island {i}: ok={len(oki)}  P_mean {pm[0]:.3f}..{pm[1]:.3f} mean {pm[2]:.4f}")

okc = {i: len([r for r in per_isl[i] if r["status"] == "ok"]) for i in ISL}
ck("C7 island ok counts 152/162/194", okc == {1: 152, 2: 162, 3: 194}, str(okc))

pms = {i: rng([num(r, "P_mean") for r in per_isl[i] if r["status"] == "ok"]) for i in ISL}
ck("C7b P_mean ranges i1 5.02-6.26, i2 5.05-6.09, i3 5.02-6.32",
   abs(pms[1][0] - 5.020) < 1e-9 and abs(pms[1][1] - 6.260) < 1e-9
   and abs(pms[2][0] - 5.050) < 1e-9 and abs(pms[2][1] - 6.090) < 1e-9
   and abs(pms[3][0] - 5.020) < 1e-9 and abs(pms[3][1] - 6.320) < 1e-9)

for a, b in ((1, 2), (1, 3), (2, 3)):
    lo, hi = max(pms[a][0], pms[b][0]), min(pms[a][1], pms[b][1])
    ck(f"C8 P_mean overlap {a}-{b} non-empty", lo <= hi, f"[{lo:.2f},{hi:.2f}]")

pspread = (max(pms[i][2] for i in ISL) - min(pms[i][2] for i in ISL)) / (sum(pms[i][2] for i in ISL) / 3)
fts = {i: rng([num(r, "fitness") for r in per_isl[i] if r["status"] == "ok"]) for i in ISL}
fspread = (max(fts[i][2] for i in ISL) - min(fts[i][2] for i in ISL)) / (sum(fts[i][2] for i in ISL) / 3)
print(f"  cross-island mean spread: P_mean {pspread*100:.2f}%  fitness {fspread*100:.2f}%")

nonfin, ninf, nnan = Counter(), 0, 0
for r in all_rows:
    v = r["FoS"].strip().lower()
    if v in ("inf", "+inf", "nan", "-inf"):
        nonfin[r["status"]] += 1
        ninf += "inf" in v
        nnan += "nan" in v
okf = [num(r, "FoS") for r in ok]
ck("C9 FoS non-finite: 322 total (inf 212, nan 110) by status {reject:201, clearance_reject:110, reject_twist:11}; none on ok rows",
   sum(nonfin.values()) == 322 and dict(nonfin) == {"reject": 201, "clearance_reject": 110, "reject_twist": 11}
   and ninf == 212 and nnan == 110 and all(v is not None for v in okf),
   f"non-finite={sum(nonfin.values())} inf={ninf} nan={nnan} ok-finite={sum(v is not None for v in okf)}/508")
ck("C9b ok FoS finite 3.18-15.32, none zero, none > 1e4",
   min(okf) == 3.180 and max(okf) == 15.320 and all(0.0 < v < 1e4 for v in okf),
   f"min={min(okf)} max={max(okf)}")

sent = [r for r in rej if r["fitness"] == "1.0e9"]
ok_big = [r for r in ok if r["fitness"] == "1.0e9"]
ck("C10 all 422 non-ok rows carry sentinel fitness 1.0e9; no ok row does",
   len(sent) == len(rej) == 422 and not ok_big, f"sentinel={len(sent)}/{len(rej)} non-ok")

w = [r for r in per_isl[3] if r["gen"] == "26" and r["idx"] == "9"][0]
bv = open(f"{RDIR}/best_vector.csv").read().strip().split(",")
bv_match = all(abs(float(bv[k]) - float(w[f"x{k+1}"])) < 6e-7 for k in range(10))
ck("C11 winner row island3 gen26 idx9: fit 27.364, P_mean 5.31, T_lift 324.13, FoS 14.97, twist_ratio exact, clearance 5.47, genes = best_vector",
   w["fitness"] == "27.364" and w["P_mean"] == "5.31" and w["P_end"] == "5.31"
   and w["T_lift"] == "324.13" and w["FoS"] == "14.97"
   and w["twist_ratio"] == "0.4393474253185575" and w["clearance"] == "5.47"
   and bv_match, f"gene-prefix-match={bv_match}")

gmeta = open(f"{RDIR}/global_best_meta.txt").read().strip()
ck("C11b global_best_meta: full fitness 27.3635412663488, island=3",
   "27.3635412663488" in gmeta and "island=3" in gmeta, gmeta)

bt2 = rng([num(r, "bank_top") for r in per_isl[2]])
ck("C12 island 2 never drew bank_top below 10.26 (all rows)", bt2[0] >= 10.26, f"min={bt2[0]}")

two_rot = [r for r in ok if abs(float(r["x6"]) - 1.0) > 0.5]
ck("C13 surviving 2-rotor-decoded (x6 rounds to 2) rows: exactly 2, all island 1",
   len(two_rot) == 2 and {r["island"] for r in two_rot} == {"1"},
   str([(r["island"], r["gen"], r["idx"], r["r_hub"], r["x6"]) for r in two_rot]))

firsts = {}
for i in ISL:
    gens_ok = Counter(int(r["gen"]) for r in per_isl[i] if r["status"] == "ok")
    firsts[i] = (min(g for g in gens_ok if g != 0), min(g for g, n in gens_ok.items() if n == 10))
ck("C14 first ok child: i1=6, i2=2, i3=1; first full (10-ok) gen: i1=19, i2=19, i3=16",
   firsts == {1: (6, 19), 2: (2, 19), 3: (1, 16)}, str(firsts))

print()
for line in checks:
    print(line)
print(f"\nTOTAL: {sum('PASS' in l for l in checks)} pass / {sum('FAIL' in l for l in checks)} fail of {len(checks)} checks")
print("SV_SECONDREAD_CENSUS_DONE")
