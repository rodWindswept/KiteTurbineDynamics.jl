#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""sv_lever_set_sign.py: the science-validator check for register rows NR-074 to NR-077.

It recomputes the lever set from the campaign telemetry, not from the extract
tables, and then compares its own numbers to the committed extract. A pass
means the extract's transcription and the register's signed forms both hold
on the raw rows.

Sources: scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/
(island_1..3/telemetry.csv, data commit dd3cc6a, run a76c5e9) and the five
extract files in docs/reporting/figures/lever-statistics-extract/.

Run: /usr/bin/python3 scratch/sv_lever_set_sign.py > scratch/sv_lever_set_sign.log
"""
from __future__ import annotations

import csv
import sys
from bisect import bisect_left
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
RD = REPO / "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2"
EX = REPO / "docs/reporting/figures/lever-statistics-extract"
GENES = [("x1", "r_hub", "continuous"), ("x2", "r_bottom", "continuous"),
         ("x3", "target_Lr", "continuous"), ("x4", "n_lines", "integer"),
         ("x5", "density_profile", "continuous"), ("x6", "rotor_count", "integer"),
         ("x7", "bank_top", "continuous"), ("x8", "bank_bottom", "continuous"),
         ("x9", "blade_scale_top", "continuous"),
         ("x10", "blade_scale_bottom", "continuous")]
FAILS: list[str] = []
CHECKS = 0


def ck(name: str, good: bool, detail: str = "") -> None:
    global CHECKS
    CHECKS += 1
    print(f"{'PASS' if good else 'FAIL'}  {name}" + (f"  [{detail}]" if detail else ""))
    if not good:
        FAILS.append(name)


def rows(path: Path) -> list[dict]:
    lines = [l for l in path.read_text().splitlines()
             if not l.startswith("#") and l.strip()]
    return list(csv.DictReader(lines))


def ranks(v):
    order = sorted(range(len(v)), key=lambda i: v[i])
    out = [0.0] * len(v)
    i = 0
    while i < len(order):
        j = i
        while j + 1 < len(order) and v[order[j + 1]] == v[order[i]]:
            j += 1
        r = (i + j) / 2.0 + 1.0
        for k in range(i, j + 1):
            out[order[k]] = r
        i = j + 1
    return out


def spearman(x, y):
    rx, ry = ranks(x), ranks(y)
    n = len(x)
    mx, my = sum(rx) / n, sum(ry) / n
    sx = sum((a - mx) ** 2 for a in rx)
    sy = sum((b - my) ** 2 for b in ry)
    return sum((a - mx) * (b - my) for a, b in zip(rx, ry)) / (sx * sy) ** 0.5


def pctl(sv, q):
    if len(sv) == 1:
        return sv[0]
    pos = q * (len(sv) - 1)
    lo = int(pos)
    frac = pos - lo
    hi = min(lo + 1, len(sv) - 1)
    return sv[lo] + (sv[hi] - sv[lo]) * frac


def dec_n_lines(x):
    return int(round(min(max(float(x), 3.0), 16.0)))


def dec_rotor(x):
    return int(round(min(max(float(x), 1.0), 3.0)))


def gv(r, col, kind):
    x = float(r[col])
    if kind == "integer":
        return float(dec_n_lines(x) if col == "x4" else dec_rotor(x))
    return x


def bin_gene(col, kind, ok):
    pairs = [(gv(r, col, kind), float(r["fitness"])) for r in ok]
    if kind == "integer":
        vals = sorted({v for v, _ in pairs})
        return [(str(int(v)), [f for v_, f in pairs if v_ == v]) for v in vals]
    sv = sorted(v for v, _ in pairs)
    edges = [pctl(sv, q) for q in (0.2, 0.4, 0.6, 0.8)]
    buckets = {}
    for v, f in pairs:
        buckets.setdefault(bisect_left(edges, v), []).append((v, f))
    out = []
    for i, b in enumerate(sorted(buckets)):
        out.append((f"q{i + 1}", [f for _, f in buckets[b]]))
    return out


def close(a, b, tol=1e-9):
    return abs(a - b) <= tol * max(1.0, abs(b))


rows_all = []
for isl in (1, 2, 3):
    rows_all += rows(RD / f"island_{isl}/telemetry.csv")
ok = [r for r in rows_all if r["status"] == "ok"]
ck("930 rows / 508 ok", len(rows_all) == 930 and len(ok) == 508,
   f"{len(rows_all)} / {len(ok)}")
mix = Counter(r["status"] for r in rows_all)
ck("status mix 301 / 110 / 11",
   mix["reject"] == 301 and mix["clearance_reject"] == 110
   and mix["reject_twist"] == 11, str(dict(mix)))

# ---------------------------------------------------------------- NR-074
t1 = {r["gene"]: r for r in rows(EX / "extract-objective-vs-gene.csv")}
t2 = rows(EX / "extract-objective-by-gene-bins.csv")
fit = [float(r["fitness"]) for r in ok]
sens = []
for col, name, kind in GENES:
    rho = spearman([gv(r, col, kind) for r in ok], fit)
    bins = bin_gene(col, kind, ok)
    delta = pctl(sorted(bins[-1][1]), 0.5) - pctl(sorted(bins[0][1]), 0.5)
    sens.append((name, rho, delta, bins[0][0], bins[-1][0],
                 len(bins[0][1]), len(bins[-1][1])))
    ck(f"rho {name} matches extract", close(rho, float(t1[name]["spearman_rho"]), 1e-12),
       f"{rho:.16f}")
    ck(f"delta {name} matches extract", close(delta, float(t1[name]["delta_med_kg"]), 1e-12),
       f"{delta:.16f}")
order = [s[0] for s in sorted(sens, key=lambda s: -abs(s[1]))]
ck("rank order reads as the signed table",
   order == [r["gene"] for r in sorted(t1.values(), key=lambda r: int(r["rho_rank"]))],
   " ".join(order))
rank_of = {n: i for i, n in enumerate(order, 1)}
ck("rotor_count rank 7 of 10", rank_of["rotor_count"] == 7)
ck("n_lines rank 10 of 10", rank_of["n_lines"] == 10)
shift = sorted(sens, key=lambda s: -s[2])
ck("largest shift reads rotor_count", shift[0][0] == "rotor_count", f"{shift[0][2]:.3f}")
ck("second shift reads n_lines", shift[1][0] == "n_lines", f"{shift[1][2]:.3f}")
ck("the two largest shifts sit on the two thinnest top bins",
   shift[0][5] == 506 and shift[0][6] == 2 and shift[1][5] == 319 and shift[1][6] == 1,
   f"rotor 506->2, n_lines 319->1")
ck("r_hub and density_profile collide at two dp",
   round(sens[0][1], 2) == round(sens[4][1], 2) == 0.07,
   f"{sens[0][1]:.4f} / {sens[4][1]:.4f}")

# ---------------------------------------------------------------- NR-075
t5 = {(r["column"], r["value"]): r for r in rows(EX / "extract-failure-rates-by-value.csv")}
secs = {
    "n_lines": lambda r: dec_n_lines(float(r["x4"])),
    "rotor_count": lambda r: dec_rotor(float(r["x6"])),
    "n_active": lambda r: int(r["n_active"]),
}
census = {}
for cname, fn in secs.items():
    for v in sorted({fn(r) for r in rows_all}):
        grp = [r for r in rows_all if fn(r) == v]
        c = Counter(r["status"] for r in grp)
        census[(cname, str(v))] = (len(grp), c["ok"], c["reject"],
                                   c["clearance_reject"], c["reject_twist"])
        row = t5[(cname, str(v))]
        ck(f"census {cname} {v}",
           (len(grp), c["ok"], c["reject"], c["clearance_reject"], c["reject_twist"])
           == (int(row["n_total"]), int(row["ok"]), int(row["reject"]),
               int(row["clearance_reject"]), int(row["reject_twist"])),
           f"{len(grp)} {c['ok']} {c['reject']} {c['clearance_reject']} {c['reject_twist']}")
ck("every clearance rejection sits at two rotors or more",
   census[("rotor_count", "1")][3] == 0
   and census[("rotor_count", "2")][3] + census[("rotor_count", "3")][3] == 110,
   f"{census[('rotor_count','2')][3]} + {census[('rotor_count','3')][3]}")
ck("two-rotor clearance share reads 91 of 157",
   census[("rotor_count", "2")] == (157, 2, 62, 91, 2))
mis = [r for r in rows_all if dec_rotor(r["x6"]) != int(r["n_active"])]
ck("rotor_count and n_active differ on 10 rows, all clearance_reject",
   len(mis) == 10 and all(r["status"] == "clearance_reject" for r in mis),
   str(Counter(r["status"] for r in mis)))
ck("n_lines ok share collapse 43.6 at 5 then 4.8 at 6",
   t5[("n_lines", "5")]["ok_share_pct"] == "43.6"
   and t5[("n_lines", "6")]["ok_share_pct"] == "4.8")

# ---------------------------------------------------------------- NR-076
W_OV, W_UT, W_TW, P_CEIL, FOS = 5.0, 20.0, 1.0, 5.0, 2.5
ch = {"overpower": [], "utilisation": [], "twist": []}
for r in ok:
    pe, fo, tr = float(r["P_end"]), float(r["FoS"]), float(r["twist_ratio"])
    ch["overpower"].append(W_OV * max(pe - P_CEIL, 0.0) ** 2)
    ch["utilisation"].append(W_UT * (FOS / fo) ** 2)
    ch["twist"].append(0.0 if tr <= 0 else W_TW * (min(tr, 1.0) / max(1 - min(tr, 1.0), 1e-6)) ** 2)
tot = sum(sum(v) for v in ch.values())
ts = {r["channel"]: r for r in rows(EX / "extract-penalty-summary.csv")}
for key, csvname in (("overpower", "overpower"), ("utilisation", "utilisation"),
                     ("twist", "twist")):
    s = sum(ch[key])
    row = ts[csvname]
    ck(f"charge sum {key}", close(s, float(row["sum"]), 1e-9), f"{s:.6f}")
    ck(f"charge share {key}", close(100 * s / tot, float(row["share_pct"]), 1e-9),
       f"{100*s/tot:.6f}")
    ck(f"charge median {key}", close(pctl(sorted(ch[key]), 0.5), float(row["median"]), 1e-9))
    ck(f"charge max {key}", close(max(ch[key]), float(row["max"]), 1e-9))
    dom = sum(1 for i in range(len(ok))
              if ch[key][i] == max(ch["overpower"][i], ch["utilisation"][i], ch["twist"][i]))
    ck(f"dominance count {key}", dom == int(row["n_dominant"]), f"{dom}")
ck("total sum 2109.8081397328224", close(tot, 2109.8081397328224, 1e-12), f"{tot:.10f}")
ck("shares close to 100.00",
   round(sum(100 * sum(ch[k]) / tot for k in ch), 2) == 100.0)
ck("over-power fires on 507 of 508",
   sum(1 for v in ch["overpower"] if v > 0) == 507)
zero = [r for r in ok if float(r["P_end"]) == 5.0]
ck("the one zero over-power ok row sits at P_end 5.0",
   len(zero) == 1 and W_OV * max(float(zero[0]["P_end"]) - 5.0, 0.0) ** 2 == 0.0,
   f"island {zero[0]['island']} gen {zero[0]['gen']} idx {zero[0]['idx']}")

# ---------------------------------------------------------------- NR-077
ck("46 conditioned bins", len(t2) == 46, str(len(t2)))
ns = [int(r["n"]) for r in t2]
ck("bin counts run 1 to 506", min(ns) == 1 and max(ns) == 506, f"{min(ns)}..{max(ns)}")
above = [r for r in t2 if float(r["mean_fitness"]) > float(r["median_fitness"])]
below_equal = [r for r in t2 if float(r["mean_fitness"]) <= float(r["median_fitness"])]
ck("mean above median in 42 of 46", len(above) == 42 and len(below_equal) == 4)
fat = [r for r in t2 if int(r["n"]) >= 5]
fat_above = [r for r in fat if float(r["mean_fitness"]) > float(r["median_fitness"])]
ck("42 bins hold five or more designs", len(fat) == 42, str(len(fat)))
ck("mean above median in 41 of the 42 fat bins", len(fat_above) == 41,
   f"{len(fat_above)}/{len(fat)}")
ck("the fat exception is target_Lr q4",
   [r["gene"] + " " + r["bin"] for r in fat if r not in fat_above] == ["target_Lr q4"])
thin = [(r["gene"], r["bin"], int(r["n"])) for r in t2 if int(r["n"]) < 5]
ck("four bins sit under the floor", thin == [("n_lines", "6", 3), ("n_lines", "8", 1),
                                             ("n_lines", "9", 1), ("rotor_count", "2", 2)],
   str(thin))
ck("two bins hold one design each", sum(1 for _, _, n in thin if n == 1) == 2)
for gene, binlab, n in thin:
    col, kind = [(c, k) for c, g, k in GENES if g == gene][0]
    count = sum(1 for r in ok if gv(r, col, kind) == float(binlab))
    ck(f"thin bin {gene} {binlab} reads n={n}", count == n, f"{count}")

print()
print(f"SV_LEVER_SET_DONE checks={CHECKS} fails={len(FAILS)}")
if FAILS:
    print("FAILED: " + "; ".join(FAILS))
sys.exit(1 if FAILS else 0)
