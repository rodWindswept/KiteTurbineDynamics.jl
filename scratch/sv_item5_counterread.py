#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""sv_item5_counterread.py - counter-read of the item-5 lever-statistics extract.

Science-validator seat, 2026-10-14.  Second-seat counter-read of the kit at
docs/reporting/figures/lever-statistics-extract/ (landed 96adbf8).

This instrument does not import or call the builder.  It re-reads the three
raw telemetry files of the bankderate2 campaign, recomputes every quantity
in the seven extract tables from the stated recipes, and compares at stored
precision.  It also re-reads the NR-039 register strings, re-checks the
source recipes (runner decoders, objective seam, campaign config), verifies
the git pins and the telemetry byte-stability, and re-runs the builder to a
private outdir for the byte-identity check.

Run:
  cd ~/Documents/GitHub/KiteTurbineDynamics.jl
  /usr/bin/python3 scratch/sv_item5_counterread.py

Stdlib only.  Token SV_ITEM5_COUNTERREAD_DONE on success.
"""
from __future__ import annotations

import csv
import hashlib
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KIT = ROOT / "docs" / "reporting" / "figures" / "lever-statistics-extract"
RD = ROOT / "scripts" / "results" / "v13_5kw_masslift_len18.8_rotorcount_bankderate2"
REG = ROOT / "docs" / "reporting" / "numbers-register.md"
RUNNER = ROOT / "scripts" / "run_v13_5kw_masslift.jl"
OBJ = ROOT / "src" / "objective_v12.jl"
PY = "/usr/bin/python3"
SC = "51ffc0d8db9aea3beef01f15a2feb9e83ae195a4"
RERUN = (Path.home() / ".hermes" / "profiles" / "science-validator"
         / "cache" / "scratch" / "sv_item5_rerun")
TELE_GIT = "a76c5e927252118abf2b2ff6bd988395583d5113"
REG_OV = "0.49333696413175443"
REG_UT = "0.5576509889014662"
REG_TW = "0.6140850570787014"

GENES = [
    ("x1", "r_hub", "continuous"),
    ("x2", "r_bottom", "continuous"),
    ("x3", "target_Lr", "continuous"),
    ("x4", "n_lines", "integer"),
    ("x5", "density_profile", "continuous"),
    ("x6", "rotor_count", "integer"),
    ("x7", "bank_top", "continuous"),
    ("x8", "bank_bottom", "continuous"),
    ("x9", "blade_scale_top", "continuous"),
    ("x10", "blade_scale_bottom", "continuous"),
]
STATUSES = ("ok", "reject", "clearance_reject", "reject_twist")
FILES8 = [f"extract-{n}.csv" for n in
          ("objective-vs-gene", "objective-by-gene-bins", "gate-failures-by-gene",
           "failure-discrimination", "failure-rates-by-value",
           "penalty-contributions", "penalty-summary")] + ["checks.log"]

CHECKS: list[tuple[str, bool, str]] = []


def check(name: str, good: bool, detail: str = "") -> None:
    CHECKS.append((name, bool(good), detail))
    tail = f"  [{detail}]" if detail else ""
    print(("OK  " if good else "FAIL") + "  " + name + tail)


def load_csv_rows(p: Path) -> list[dict]:
    lines = [ln for ln in p.read_text().splitlines()
             if not ln.startswith("#") and ln.strip()]
    return list(csv.DictReader(lines))


def git(*args: str) -> str:
    r = subprocess.run(["git", *args], capture_output=True, text=True, cwd=str(ROOT))
    return r.stdout.strip()


# --------------------------------------------------------------- statistics
def ranks(vals: list[float]) -> list[float]:
    idx = sorted(range(len(vals)), key=lambda i: vals[i])
    out = [0.0] * len(vals)
    i = 0
    while i < len(idx):
        j = i
        while j + 1 < len(idx) and vals[idx[j + 1]] == vals[idx[i]]:
            j += 1
        r = (i + j) / 2.0 + 1.0
        for k in range(i, j + 1):
            out[idx[k]] = r
        i = j + 1
    return out


def spearman(a: list[float], b: list[float]) -> float:
    ra, rb = ranks(a), ranks(b)
    n = len(a)
    ma, mb = sum(ra) / n, sum(rb) / n
    sa = sum((x - ma) ** 2 for x in ra)
    sb = sum((y - mb) ** 2 for y in rb)
    if sa == 0.0 or sb == 0.0:
        return float("nan")
    cab = sum((x - ma) * (y - mb) for x, y in zip(ra, rb))
    return cab / (sa * sb) ** 0.5


def auc(pos: list[float], neg: list[float]) -> float:
    n1, n2 = len(pos), len(neg)
    if n1 == 0 or n2 == 0:
        return float("nan")
    r = ranks(list(pos) + list(neg))
    u = sum(r[:n1]) - n1 * (n1 + 1) / 2.0
    return u / (n1 * n2)


def qtl(sv: list[float], q: float) -> float:
    if len(sv) == 1:
        return sv[0]
    pos = q * (len(sv) - 1)
    lo = int(pos)
    frac = pos - lo
    hi = min(lo + 1, len(sv) - 1)
    return sv[lo] + (sv[hi] - sv[lo]) * frac


def dec_n_lines(x: float) -> int:
    return int(round(min(max(x, 3.0), 16.0)))


def dec_rotor(x: float) -> int:
    return int(round(min(max(x, 1.0), 3.0)))


def gval(r: dict, slot: str, kind: str) -> float:
    v = float(r[slot])
    if kind == "integer":
        return float(dec_n_lines(v) if slot == "x4" else dec_rotor(v))
    return v


def charge_ov(p: float) -> float:
    return 5.0 * max(p - 5.0, 0.0) ** 2


def charge_ut(f: float) -> float:
    return 20.0 * (2.5 / f) ** 2


def charge_tw(t: float) -> float:
    if t <= 0.0:
        return 0.0
    r = min(t, 1.0)
    return 1.0 * (r / max(1.0 - r, 1e-6)) ** 2


def bins_of(slot: str, kind: str, rows: list[dict]):
    pairs = [(gval(r, slot, kind), float(r["fitness"])) for r in rows]
    if kind == "integer":
        vals = sorted({v for v, _ in pairs})
        return [(str(int(v)), [f for vv, f in pairs if vv == v]) for v in vals]
    sv = sorted(v for v, _ in pairs)
    edges = [qtl(sv, q) for q in (0.2, 0.4, 0.6, 0.8)]
    buckets: dict[int, list[tuple[float, float]]] = {}
    for v, f in pairs:
        b = sum(1 for e in edges if e < v)  # bisect_left(edges, v)
        buckets.setdefault(b, []).append((v, f))
    out = []
    for i, b in enumerate(sorted(buckets)):
        vs = [v for v, _ in buckets[b]]
        out.append((f"q{i + 1}", [f for _, f in buckets[b]]))
    return out


def decs(s: str) -> int:
    return len(s.split(".")[1]) if "." in s and not s.endswith(".") else 0


def disp3(v: float) -> str:
    return f"{v:.3f}".rstrip("0").rstrip(".")


# -------------------------------------------------------------------- load
tele: list[dict] = []
for isl in (1, 2, 3):
    tele += load_csv_rows(RD / f"island_{isl}" / "telemetry.csv")
okrows = [r for r in tele if r["status"] == "ok"]

print("sv_item5_counterread | independent recompute from the raw telemetry")
print(f"read at HEAD {git('rev-parse', 'HEAD')}")

# ================================================================ A. inputs
check("telemetry rows read 930", len(tele) == 930, str(len(tele)))
per_isl = Counter(r["island"] for r in tele)
check("island counts read 310 each",
      all(per_isl[str(i)] == 310 for i in (1, 2, 3)), str(dict(per_isl)))
mix = Counter(r["status"] for r in tele)
check("status mix reads 508 / 301 / 110 / 11",
      mix["ok"] == 508 and mix["reject"] == 301
      and mix["clearance_reject"] == 110 and mix["reject_twist"] == 11,
      str(dict(mix)))
for isl in (1, 2, 3):
    head = (RD / f"island_{isl}" / "telemetry.csv").read_text().splitlines()[0]
    check(f"island {isl} header pins era and git run",
          "era=post-95c385d_wind-authority" in head and f"git={TELE_GIT}" in head)
cols = set(tele[0].keys())
need = ({"island", "gen", "idx", "fitness", "status", "P_mean", "P_end", "T_lift",
         "FoS", "twist_crossed", "twist_ratio", "clearance", "n_lines", "rings",
         "n_active", "r_hub", "r_bot", "bank_top", "bank_bot", "blade_scale_top",
         "blade_scale_bottom", "tether"} | {f"x{i}" for i in range(1, 11)})
check("columns match the recorded set (no P_range, no stationary, no mass)",
      cols == need, str(sorted(cols ^ need)))
check("ok set reads 508 finite rows",
      len(okrows) == 508 and all(float(r["fitness"]) < 1e6 for r in okrows))
check("ok P_end at or above the 5.0 kW floor",
      min(float(r["P_end"]) for r in okrows) >= 5.0 - 1e-9)
check("ok FoS at or above the 2.5 floor",
      min(float(r["FoS"]) for r in okrows) >= 2.5 - 1e-9)
check("ok twist_ratio inside [0, 1)",
      0.0 <= max(float(r["twist_ratio"]) for r in okrows) < 1.0)
check("decoded n_lines equals the recorded column on all rows",
      all(dec_n_lines(float(r["x4"])) == int(r["n_lines"]) for r in tele))
xtab = Counter((dec_rotor(float(r["x6"])), int(r["n_active"])) for r in tele)
check("decoded rotor_count x n_active cross-tab reads as recorded",
      xtab[(1, 1)] == 739 and xtab[(2, 2)] == 157 and xtab[(3, 2)] == 10
      and xtab[(3, 3)] == 24, str(dict(xtab)))

# ======================================================= B. objective-vs-gene
t1 = load_csv_rows(KIT / "extract-objective-vs-gene.csv")
t1_by = {r["gene"]: r for r in t1}
check("objective table reads the 10 genes",
      len(t1) == 10 and set(t1_by) == {n for _, n, _ in GENES})
my_rho: dict[str, float] = {}
my_delta: dict[str, float] = {}
for slot, name, kind in GENES:
    gv = [gval(r, slot, kind) for r in okrows]
    fit = [float(r["fitness"]) for r in okrows]
    rho = spearman(gv, fit)
    my_rho[name] = rho
    bns = bins_of(slot, kind, okrows)
    b0, bN = sorted(bns[0][1]), sorted(bns[-1][1])
    delta = qtl(bN, 0.5) - qtl(b0, 0.5)
    my_delta[name] = delta
    st = t1_by[name]
    d1 = abs(rho - float(st["spearman_rho"]))
    d2 = abs(delta - float(st["delta_med_kg"]))
    check(f"rho recomputes, {name}", d1 <= 5e-13, f"delta {d1:g}")
    check(f"delta_med recomputes, {name}", d2 <= 1e-9, f"delta {d2:g}")
order = [n for _, n, _ in sorted(GENES, key=lambda g: -abs(my_rho[g[1]]))]
rank_map = {name: i + 1 for i, name in enumerate(order)}
check("rho_rank column matches the recomputed rank order",
      all(int(t1_by[n]["rho_rank"]) == rank_map[n] for _, n, _ in GENES))
forms4 = {"target_Lr": "-0.5832", "blade_scale_top": "0.5042",
          "bank_bottom": "-0.4033", "r_bottom": "-0.2764"}
check("headline rho forms round to the receipt quad",
      all(f"{my_rho[k]:.4f}" == v for k, v in forms4.items()))
forms_d = {"target_Lr": "-3.892", "blade_scale_top": "2.759", "bank_bottom": "-2.896",
           "r_bottom": "-1.801", "blade_scale_bottom": "1.356", "bank_top": "0.669",
           "rotor_count": "26.592", "r_hub": "1.071", "density_profile": "-0.212",
           "n_lines": "22.54"}
check("delta_med display forms read as the receipt list",
      all(disp3(my_delta[k]) == v for k, v in forms_d.items()),
      str({k: disp3(my_delta[k]) for k in forms_d}))
raw_rho6 = spearman([float(r["x6"]) for r in okrows],
                    [float(r["fitness"]) for r in okrows])
raw_rho4 = spearman([float(r["x4"]) for r in okrows],
                    [float(r["fitness"]) for r in okrows])
frac4 = sum(1 for r in tele if float(r["x4"]) != int(float(r["x4"])))
frac4_ok = sum(1 for r in okrows if float(r["x4"]) != int(float(r["x4"])))
frac6 = sum(1 for r in tele if float(r["x6"]) != int(float(r["x6"])))
check("stored draw fractionality reads as recorded (x4 27 of 930, none in ok; x6 780 of 930)",
      frac4 == 27 and frac4_ok == 0 and frac6 == 780,
      f"x4 {frac4} (ok {frac4_ok}) x6 {frac6}")
check("rotor_count rho: the decoder form is material on the ok set (raw reads 0.031729)",
      abs(raw_rho6 - my_rho["rotor_count"]) > 0.01,
      f"decoded {my_rho['rotor_count']:.6f} raw {raw_rho6:.6f}")
check("n_lines rho: the ok set sits on the decoder grid, raw reads identical",
      abs(raw_rho4 - my_rho["n_lines"]) <= 5e-13,
      f"decoded {my_rho['n_lines']:.6f} raw {raw_rho4:.6f}")

# ======================================================== C. bins table
t2 = load_csv_rows(KIT / "extract-objective-by-gene-bins.csv")
check("bins table reads 46 rows", len(t2) == 46, str(len(t2)))
t2_by: dict[str, list[dict]] = {}
for r in t2:
    t2_by.setdefault(r["gene"], []).append(r)
for slot, name, kind in GENES:
    mine = bins_of(slot, kind, okrows)
    stored = t2_by.get(name, [])
    good = len(stored) == len(mine)
    worst = 0.0
    if good:
        for srow, (lab, fs) in zip(stored, mine):
            sf = sorted(fs)
            if int(srow["n"]) != len(sf):
                good = False
                break
            for key, val in (("median_fitness", qtl(sf, 0.5)),
                             ("mean_fitness", sum(sf) / len(sf)),
                             ("p25_fitness", qtl(sf, 0.25)),
                             ("p75_fitness", qtl(sf, 0.75))):
                worst = max(worst, abs(float(srow[key]) - val))
        good = good and worst <= 1e-9
    check(f"bins recompute, {name} ({len(mine)} bins)", good, f"worst {worst:g}")
check("bin sets read as recorded (blade_scale_top 3, blade_scale_bottom 4)",
      len(bins_of("x9", "continuous", okrows)) == 3
      and len(bins_of("x10", "continuous", okrows)) == 4)
check("every gene's stored bins sum 508",
      all(sum(int(r["n"]) for r in t2_by[name]) == 508 for _, name, _ in GENES))

# ======================================================== D. gate failures
t3 = load_csv_rows(KIT / "extract-gate-failures-by-gene.csv")
check("gate-failures table reads 40 rows", len(t3) == 40, str(len(t3)))
t3_map = {(r["gene"], r["status"]): r for r in t3}
for slot, name, kind in GENES:
    for st in STATUSES:
        vs = sorted(gval(r, slot, kind) for r in tele if r["status"] == st)
        srow = t3_map.get((name, st))
        good = srow is not None and len(vs) > 0
        if good:
            good = (int(srow["n"]) == len(vs)
                    and abs(float(srow["median"]) - qtl(vs, 0.5)) <= 1e-9
                    and abs(float(srow["p25"]) - qtl(vs, 0.25)) <= 1e-9
                    and abs(float(srow["p75"]) - qtl(vs, 0.75)) <= 1e-9
                    and abs(float(srow["min"]) - vs[0]) <= 1e-9
                    and abs(float(srow["max"]) - vs[-1]) <= 1e-9)
        check(f"gate-failure dist recomputes, {name} x {st}", good)

# ======================================================== E. discrimination
t4 = load_csv_rows(KIT / "extract-failure-discrimination.csv")
t4_map = {r["gene"]: r for r in t4}
for slot, name, kind in GENES:
    ov = [gval(r, slot, kind) for r in okrows]
    row = t4_map[name]
    good = (int(row["n_ok"]) == len(ov)
            and abs(float(row["med_ok"]) - qtl(sorted(ov), 0.5)) <= 1e-9)
    for st, pref in (("reject", "reject"), ("clearance_reject", "clearance"),
                     ("reject_twist", "twist")):
        fv = [gval(r, slot, kind) for r in tele if r["status"] == st]
        good = (good and int(row[f"n_{pref}"]) == len(fv)
                and abs(float(row[f"med_{pref}"]) - qtl(sorted(fv), 0.5)) <= 1e-9
                and abs(float(row[f"auc_{pref}"]) - auc(ov, fv)) <= 5e-13)
    check(f"discrimination recomputes, {name}", good)
check("AUC forms read as the receipt states (0.7417, 0.3261; 0.7495, 0.0016)",
      f"{float(t4_map['target_Lr']['auc_reject']):.4f}" == "0.7417"
      and f"{float(t4_map['n_lines']['auc_reject']):.4f}" == "0.3261"
      and f"{float(t4_map['blade_scale_top']['auc_clearance']):.4f}" == "0.7495"
      and f"{float(t4_map['rotor_count']['auc_clearance']):.4f}" == "0.0016")

# ======================================================== F. failure rates
t5 = load_csv_rows(KIT / "extract-failure-rates-by-value.csv")
check("failure-rates table reads 13 rows", len(t5) == 13, str(len(t5)))


def group_of(cname: str):
    if cname == "n_lines":
        return lambda r: dec_n_lines(float(r["x4"]))
    if cname == "rotor_count":
        return lambda r: dec_rotor(float(r["x6"]))
    return lambda r: int(r["n_active"])


for r5 in t5:
    fn = group_of(r5["column"])
    v = int(r5["value"])
    grp = [r for r in tele if fn(r) == v]
    c = Counter(r["status"] for r in grp)
    good = (int(r5["n_total"]) == len(grp) and int(r5["ok"]) == c["ok"]
            and int(r5["reject"]) == c["reject"]
            and int(r5["clearance_reject"]) == c["clearance_reject"]
            and int(r5["reject_twist"]) == c["reject_twist"]
            and r5["ok_share_pct"] == f"{100.0 * c['ok'] / len(grp):.1f}")
    check(f"failure rates recompute, {r5['column']}={v}", good, r5["ok_share_pct"])
for sec in ("n_lines", "rotor_count", "n_active"):
    sub = [r for r in t5 if r["column"] == sec]
    check(f"failure-rates section {sec} totals 930 / 508",
          sum(int(r["n_total"]) for r in sub) == 930
          and sum(int(r["ok"]) for r in sub) == 508)

# ======================================================== G. penalty rows
t6 = load_csv_rows(KIT / "extract-penalty-contributions.csv")
check("penalty table reads 508 rows", len(t6) == 508, str(len(t6)))
tele_ok_sorted = sorted(okrows, key=lambda r: (int(r["island"]), int(r["gen"]), int(r["idx"])))
check("penalty rows key and sort as the ok set",
      [(r["island"], r["gen"], r["idx"]) for r in t6]
      == [(r["island"], r["gen"], r["idx"]) for r in tele_ok_sorted])
check("penalty rows carry the recorded columns verbatim",
      all(all(t6[i][k] == tele_ok_sorted[i][k]
              for k in ("fitness", "P_end", "FoS", "twist_ratio"))
          for i in range(508)))
worst6 = 0.0
exact: Counter = Counter()
for i in range(508):
    r = tele_ok_sorted[i]
    s = t6[i]
    cov, cut, ctw = (charge_ov(float(r["P_end"])), charge_ut(float(r["FoS"])),
                     charge_tw(float(r["twist_ratio"])))
    pen = cov + cut + ctw
    fit = float(r["fitness"])
    vals = (("charge_overpower", cov), ("charge_utilisation", cut),
            ("charge_twist", ctw), ("penalty_total", pen),
            ("remainder_kg", fit - pen), ("penalty_share_pct", 100.0 * pen / fit))
    for key, val in vals:
        d = abs(float(s[key]) - val)
        worst6 = max(worst6, d)
        if repr(float(s[key])) == repr(val):
            exact[key] += 1
check("508 penalty rows recompute within 1e-9", worst6 <= 1e-9, f"worst {worst6:g}")
print("note  exact repr matches over 508 rows:", dict(exact))

# ======================================================== H. penalty summary
t7 = load_csv_rows(KIT / "extract-penalty-summary.csv")
t7_map = {r["channel"]: r for r in t7}
trips = [(charge_ov(float(r["P_end"])), charge_ut(float(r["FoS"])),
          charge_tw(float(r["twist_ratio"]))) for r in okrows]
total_sum = sum(sum(t) for t in trips)
dom = [0, 0, 0]
for t in trips:
    mx = max(t)
    if t.count(mx) == 1:
        dom[t.index(mx)] += 1
for ci, nm in enumerate(("overpower", "utilisation", "twist")):
    vals = [t[ci] for t in trips]
    sv = sorted(vals)
    srow = t7_map[nm]
    good = (int(srow["n_rows"]) == 508
            and int(srow["n_fired"]) == sum(1 for v in vals if v > 0.0)
            and abs(float(srow["min"]) - sv[0]) <= 1e-9
            and abs(float(srow["median"]) - qtl(sv, 0.5)) <= 1e-9
            and abs(float(srow["p75"]) - qtl(sv, 0.75)) <= 1e-9
            and abs(float(srow["max"]) - sv[-1]) <= 1e-9
            and abs(float(srow["sum"]) - sum(vals)) <= 1e-7
            and abs(float(srow["share_pct"]) - 100.0 * sum(vals) / total_sum) <= 1e-9
            and int(srow["n_dominant"]) == dom[ci])
    check(f"penalty summary recomputes, {nm}", good)
st = sorted(sum(t) for t in trips)
srow = t7_map["total"]
check("penalty summary recomputes, total row",
      abs(float(srow["min"]) - st[0]) <= 1e-9
      and abs(float(srow["median"]) - qtl(st, 0.5)) <= 1e-9
      and abs(float(srow["p75"]) - qtl(st, 0.75)) <= 1e-9
      and abs(float(srow["max"]) - st[-1]) <= 1e-9
      and abs(float(srow["sum"]) - sum(st)) <= 1e-7)
ov, ut, tw = t7_map["overpower"], t7_map["utilisation"], t7_map["twist"]
check("over-power forms read as the receipt states (507 of 508; 2.81; 8.84; 69.3; 453)",
      int(ov["n_fired"]) == 507 and f"{float(ov['median']):.2f}" == "2.81"
      and f"{float(ov['max']):.2f}" == "8.84"
      and f"{float(ov['share_pct']):.1f}" == "69.3"
      and f"{float(ov['sum']):.2f}" == "1462.32" and int(ov["n_dominant"]) == 453)
check("utilisation forms read (508; 0.72; 12.36; 24.0; 506.36; 46)",
      int(ut["n_fired"]) == 508 and f"{float(ut['median']):.2f}" == "0.72"
      and f"{float(ut['max']):.2f}" == "12.36"
      and f"{float(ut['share_pct']):.1f}" == "24.0"
      and f"{float(ut['sum']):.2f}" == "506.36" and int(ut["n_dominant"]) == 46)
check("twist forms read (508; 0.16; 8.29; 6.7; 141.13; 9)",
      int(tw["n_fired"]) == 508 and f"{float(tw['median']):.2f}" == "0.16"
      and f"{float(tw['max']):.2f}" == "8.29"
      and f"{float(tw['share_pct']):.1f}" == "6.7"
      and f"{float(tw['sum']):.2f}" == "141.13" and int(tw["n_dominant"]) == 9)
tot = t7_map["total"]
check("total row forms read (0.68; 3.96; 15.14; 2109.81)",
      f"{float(tot['min']):.2f}" == "0.68" and f"{float(tot['median']):.2f}" == "3.96"
      and f"{float(tot['max']):.2f}" == "15.14"
      and f"{float(tot['sum']):.2f}" == "2109.81")

# ======================================================== I. NR-039 cross-check
reg = REG.read_text()
for tag, val in (("over-power", REG_OV), ("utilisation", REG_UT), ("twist", REG_TW)):
    check(f"register carries the NR-039 {tag} string", val in reg)
wrow = [r for r in tele if r["island"] == "3" and r["gen"] == "26" and r["idx"] == "9"]
check("winner row unique (island 3, gen 26, idx 9)", len(wrow) == 1)
w = wrow[0]
check("winner fitness string reads 27.364", w["fitness"] == "27.364", w["fitness"])
p, f, t = float(w["P_end"]), float(w["FoS"]), float(w["twist_ratio"])
cov, cut, ctw = charge_ov(p), charge_ut(f), charge_tw(t)
d_ov = abs(cov - float(REG_OV))
b_ov = charge_ov(p + 0.005) - charge_ov(p - 0.005)
d_ut = abs(cut - float(REG_UT))
b_ut = 125.0 * (1.0 / (f - 0.005) ** 2 - 1.0 / (f + 0.005) ** 2)
d_tw = abs(ctw - float(REG_TW))
check("winner over-power recompute inside the CSV rounding bound",
      d_ov <= b_ov, f"delta {d_ov:g} bound {b_ov:g}")
check("winner utilisation recompute inside the CSV rounding bound",
      d_ut <= b_ut, f"delta {d_ut:g} bound {b_ut:g}")
check("winner twist recompute exact (full-precision column)",
      d_tw <= 1e-12, f"delta {d_tw:g}")
check("winner forms read as the receipt states (0.4805 / 0.49334 / 0.0128 / 0.031 / 0.00013)",
      f"{cov:.4f}" == "0.4805" and f"{float(REG_OV):.5f}" == "0.49334"
      and f"{d_ov:.4f}" == "0.0128" and f"{b_ov:.3f}" == "0.031"
      and f"{d_ut:.5f}" == "0.00013")

# ======================================================== J. headline claims
order_fig = ["target_Lr", "blade_scale_top", "bank_bottom", "r_bottom",
             "blade_scale_bottom", "bank_top", "rotor_count", "r_hub",
             "density_profile", "n_lines"]
check("rho effect-size order matches the receipt list", order == order_fig)
r5m = {(r["column"], int(r["value"])): r for r in t5}
rc1, rc2, rc3 = r5m[("rotor_count", 1)], r5m[("rotor_count", 2)], r5m[("rotor_count", 3)]
check("rotor_count count 1 reads 506 of 739 ok, 68.5 per cent",
      int(rc1["ok"]) == 506 and int(rc1["n_total"]) == 739
      and rc1["ok_share_pct"] == "68.5")
check("rotor_count count 2 reads 2 of 157, 1.3 per cent",
      int(rc2["ok"]) == 2 and int(rc2["n_total"]) == 157
      and rc2["ok_share_pct"] == "1.3")
check("rotor_count count 3 reads 0 of 34",
      int(rc3["ok"]) == 0 and int(rc3["n_total"]) == 34)
cdec = Counter(dec_rotor(float(r["x6"])) for r in tele if r["status"] == "clearance_reject")
check("every clearance reject carries rotor_count >= 2 (split 91 / 19)",
      min(cdec) >= 2 and cdec[2] == 91 and cdec[3] == 19, str(dict(cdec)))
surv = [(r["island"], r["gen"], r["fitness"]) for r in okrows
        if dec_rotor(float(r["x6"])) == 2]
check("the two count-2 survivors sit at island 1, gen 7 and 13, fitness 58.864 / 60.646",
      sorted(r[0] for r in surv) == ["1", "1"]
      and sorted(r[1] for r in surv) == ["13", "7"]
      and sorted(r[2] for r in surv) == ["58.864", "60.646"], str(sorted(surv)))
check("the count-2 survivors are the two heaviest ok designs",
      max(float(r["fitness"]) for r in okrows) == 60.646)
nl = {int(v): r for (c, v), r in r5m.items() if c == "n_lines"}
check("n_lines shares read 66.9 / 68.9 / 43.6 / 4.8 for values 3 to 6",
      nl[3]["ok_share_pct"] == "66.9" and nl[4]["ok_share_pct"] == "68.9"
      and nl[5]["ok_share_pct"] == "43.6" and nl[6]["ok_share_pct"] == "4.8")
check("n_lines survival falls away above 5 (11.3 / 5.9 / 2.9 at 7 to 9)",
      all(float(nl[v]["ok_share_pct"]) < 20.0 for v in (6, 7, 8, 9))
      and nl[7]["ok_share_pct"] == "11.3" and nl[8]["ok_share_pct"] == "5.9"
      and nl[9]["ok_share_pct"] == "2.9")
okrot = Counter(dec_rotor(float(r["x6"])) for r in okrows)
check("ok set decodes rotor_count {1: 506, 2: 2}",
      okrot[1] == 506 and okrot[2] == 2 and okrot.get(3, 0) == 0)
check("ok fitness range reads 27.364 to 60.646",
      min(float(r["fitness"]) for r in okrows) == 27.364
      and max(float(r["fitness"]) for r in okrows) == 60.646)
check("ok FoS min reads 3.18 and twist max reads 0.7421662474493615",
      min(float(r["FoS"]) for r in okrows) == 3.18
      and max(float(r["twist_ratio"]) for r in okrows) == 0.7421662474493615)
p5 = [r for r in okrows if float(r["P_end"]) == 5.0]
check("one ok design reads P_end 5.0 and carries no over-power charge",
      len(p5) == 1 and charge_ov(5.0) == 0.0)

# ======================================================== K. recorded precision
check("P_end and FoS record at two decimals or fewer",
      max(decs(r["P_end"]) for r in okrows) <= 2
      and max(decs(r["FoS"]) for r in okrows) <= 2)
check("fitness records at three decimals or fewer",
      max(decs(r["fitness"]) for r in okrows) <= 3)
worst_ov = max(charge_ov(float(r["P_end"]) + 0.005) - charge_ov(float(r["P_end"]) - 0.005)
               for r in okrows)
worst_ut = max(125.0 * (1.0 / (float(r["FoS"]) - 0.005) ** 2
                        - 1.0 / (float(r["FoS"]) + 0.005) ** 2) for r in okrows)
check("worst-case rounding spans read 0.133 and 0.078",
      f"{worst_ov:.3f}" == "0.133" and f"{worst_ut:.3f}" == "0.078",
      f"{worst_ov:g} / {worst_ut:g}")

# ======================================================== L. provenance lines
csv_files = [f for f in FILES8 if f.endswith(".csv")]
provs = [(KIT / n).read_text().splitlines()[0] for n in csv_files]
check("every table carries the provenance pins (data, run, era, script commit)",
      all(("data commit dd3cc6a" in p and "run a76c5e9" in p
           and "era post-95c385d_wind-authority" in p
           and f"script commit {SC}" in p) for p in provs))
clog = (KIT / "checks.log").read_text()
check("checks.log reads 18 ok / 0 fail and the done token",
      "checks: 18 ok / 0 fail" in clog and "FIG_LEVER_EXTRACT_DONE" in clog)

# ======================================================== M. builder rerun
RERUN.mkdir(parents=True, exist_ok=True)
r = subprocess.run([PY, str(KIT / "build-extract.py"), "--script-commit", SC,
                    "--outdir", str(RERUN)],
                   capture_output=True, text=True, cwd=str(ROOT))
check("builder rerun exits 0", r.returncode == 0, f"rc {r.returncode}")
(RERUN / "builder_run.log").write_text(r.stdout + r.stderr)
diffs = [n for n in FILES8
         if hashlib.sha256((KIT / n).read_bytes()).hexdigest()
         != hashlib.sha256((RERUN / n).read_bytes()).hexdigest()]
check("builder rerun byte-identical across the seven tables and checks.log",
      not diffs, str(diffs))
print("note  kit outputs (sha256):")
for n in FILES8:
    print("   ", hashlib.sha256((KIT / n).read_bytes()).hexdigest(), n)

# ======================================================== N. git pins
for sha, label in (("dd3cc6a", "data commit"), ("a76c5e9", "run"),
                   (SC, "script commit")):
    check(f"git pin ({label}) {sha} resolves to a commit",
          git("cat-file", "-t", sha) == "commit")
full = git("rev-parse", "dd3cc6a")
check("data commit full sha reads dd3cc6ad0245286046f3b9e0a2c21dfcc95a6b26",
      full == "dd3cc6ad0245286046f3b9e0a2c21dfcc95a6b26", full)
sub = git("show", "-s", "--format=%s", "dd3cc6a")
check("data commit subject reads the bankderate2 winner line",
      "bankderate2 5kW masslift results" in sub and "winner island 3 (27.364)" in sub,
      sub[:80])
nm = git("diff", "--name-only", "dd3cc6a", "HEAD", "--",
         "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_1/telemetry.csv",
         "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_2/telemetry.csv",
         "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/telemetry.csv")
check("telemetry byte-stable from dd3cc6a to HEAD", nm == "", nm)
dstat = git("diff", "--name-status", "dd3cc6a", "HEAD", "--",
            "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/")
dlines = [l for l in dstat.splitlines() if l.strip()]
check("dataset delta dd3cc6a..HEAD reads additions-only, no telemetry touched",
      all(l.startswith("A\t") for l in dlines)
      and not any("telemetry" in l for l in dlines), f"{len(dlines)} additions")

# ======================================================== O. source recipes
rtxt = re.sub(r"\s+", " ", RUNNER.read_text())
check("runner decoder sites read the stated forms",
      "xr[4] = Float64(round(Int, clamp(xr[4], 3, 16)))" in rtxt
      and "xr[6] = Float64(round(Int, clamp(xr[6], 1, 3)))" in rtxt)
check("runner config pins p_floor 5.0, p_ceiling 5.0, fos_hard 2.5",
      "p_floor_kw = 5.0, p_ceiling_kw = 5.0," in rtxt
      and "fos_target = 2.5, fos_hard = 2.5," in rtxt)
otxt = re.sub(r"\s+", " ", OBJ.read_text())
check("objective seam carries the NR-046 forms and weights",
      all(s in otxt for s in (
          "const W_OVERPOWER_KG_PER_KW2 = 5.0",
          "const W_TWIST_KG = 1.0",
          "const W_UTILISATION_KG = 20.0",
          "excess_kw = max(P_mean - cfg.p_ceiling_kw, 0.0)",
          "penalty_overpower = W_OVERPOWER_KG_PER_KW2 * excess_kw^2",
          "margin = max(1.0 - r, 1e-6)",
          "penalty_twist = W_TWIST_KG * (r / margin)^2",
          "penalty_util = W_UTILISATION_KG * (cfg.fos_hard / FoS_min)^2",
          "return mass + penalty_overpower + penalty_twist + penalty_util")))

# ======================================================== summary
failed = [c for c in CHECKS if not c[1]]
print(f"checks: {len(CHECKS) - len(failed)} ok / {len(failed)} fail")
if failed:
    for name, _good, detail in failed:
        print("FAILED:", name, detail)
    print("SV_ITEM5_COUNTERREAD_FAIL")
    sys.exit(1)
print("SV_ITEM5_COUNTERREAD_DONE")
sys.exit(0)
