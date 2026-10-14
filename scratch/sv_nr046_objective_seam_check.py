#!/usr/bin/env python3
# sv_nr046_objective_seam_check.py — NR-046 objective-seam source row (science-validator, 2026-10-14)
#
# The feedback round 4 ask: sign the three penalty forms (weights, thresholds, units)
# and the reject placement. This checker:
#   A. pins 30 line-numbered source sites across the three files,
#   B. proves blob identity launch a76c5e9 == HEAD == origin,
#   C. closes the winner arithmetic on the source forms (diff 0.0 vs the record),
#   D. censuses the reject stamp (1.0e9) over all 930 telemetry rows.
# Stdlib only. Token SV_NR046_DONE on success, SV_NR046_FAIL otherwise.
import os
import re
import subprocess
import sys
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ok = True


def read(rel):
    with open(os.path.join(ROOT, rel)) as f:
        return f.read()


def check(name, good, extra=""):
    global ok
    tail = "" if good else ("  [" + extra + "]")
    print(("OK  " if good else "FAIL") + "  " + name + tail)
    ok = ok and good


def git(*args):
    return subprocess.run(["git", "-C", ROOT] + list(args), capture_output=True, text=True).stdout.strip()


print("sv_nr046_objective_seam_check — read at HEAD", git("rev-parse", "--short", "HEAD"),
      "| origin", git("rev-parse", "--short", "origin/bank-derate-cos2p65"))

# ── A. source pins (line numbers at HEAD; every substring must appear) ───
obj = read("src/objective_v12.jl").splitlines()
ev = read("src/objective_evaluator.jl").splitlines()
run = read("scripts/run_v13_5kw_masslift.jl").splitlines()

pins = [
    ("objective_v12.jl", obj, 114, ["const W_OVERPOWER_KG_PER_KW2 = 5.0"]),
    ("objective_v12.jl", obj, 115, ["const W_TWIST_KG", "1.0"]),
    ("objective_v12.jl", obj, 116, ["const W_UTILISATION_KG", "20.0"]),
    ("objective_v12.jl", obj, 149, ["!isfinite(FoS_min) || FoS_min < cfg.fos_hard", "return Inf"]),
    ("objective_v12.jl", obj, 150, ["P_mean < cfg.p_floor_kw", "return Inf"]),
    ("objective_v12.jl", obj, 153, ["excess_kw = max(P_mean - cfg.p_ceiling_kw, 0.0)"]),
    ("objective_v12.jl", obj, 154, ["penalty_overpower = W_OVERPOWER_KG_PER_KW2 * excess_kw^2"]),
    ("objective_v12.jl", obj, 161, ["penalty_twist = W_TWIST_KG * (r / margin)^2"]),
    ("objective_v12.jl", obj, 165, ["penalty_util = W_UTILISATION_KG * (cfg.fos_hard / FoS_min)^2"]),
    ("objective_v12.jl", obj, 167, ["return mass + penalty_overpower + penalty_twist + penalty_util"]),
    ("objective_evaluator.jl", ev, 90, ["const STATIONARITY_LAMBDA = 10.0"]),
    ("objective_evaluator.jl", ev, 91, ["const STATIONARITY_SWING = 0.20"]),
    ("objective_evaluator.jl", ev, 1148, ["P_score = cfg.power_stat === :tail5 ? P_end : P_mean"]),
    ("objective_evaluator.jl", ev, 1161, ["fitness = fitness_fn(P_score, FoS_min, cfg, m_airborne)"]),
    ("objective_evaluator.jl", ev, 1192, ["swing = P_mean > 0.1 ? P_range / P_mean : 0.0"]),
    ("objective_evaluator.jl", ev, 1193, ["excess = max(0.0, swing - STATIONARITY_SWING)"]),
    ("objective_evaluator.jl", ev, 1194, ["fitness = fitness + STATIONARITY_LAMBDA * excess"]),
    ("objective_evaluator.jl", ev, 1200, ["if twist_ratio_max[] > 0.0"]),
    ("objective_evaluator.jl", ev, 1201, ["tr = min(twist_ratio_max[], 1.0)"]),
    ("objective_evaluator.jl", ev, 1202, ["fitness = fitness + W_TWIST_KG * (tr / max(1.0 - tr, 1e-6))^2"]),
    ("run_v13_5kw_masslift.jl", run, 76, ["const MIN_CLEARANCE = 1.5"]),
    ("run_v13_5kw_masslift.jl", run, 153, ["p_floor_kw = 5.0, p_ceiling_kw = 5.0"]),
    ("run_v13_5kw_masslift.jl", run, 155, ["fos_target = 2.5, fos_hard = 2.5"]),
    ("run_v13_5kw_masslift.jl", run, 156, ["power_stat = :tail5, penalize_ceiling = false"]),
    ("run_v13_5kw_masslift.jl", run, 256, ["if clearance < MIN_CLEARANCE"]),
    ("run_v13_5kw_masslift.jl", run, 257, ["status = :clearance_reject"]),
    ("run_v13_5kw_masslift.jl", run, 266, ["KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m)"]),
    ("run_v13_5kw_masslift.jl", run, 272, ["status = r.twist_crossed ? :reject_twist : :reject"]),
    ("run_v13_5kw_masslift.jl", run, 281, ["if status !== :ok"]),
    ("run_v13_5kw_masslift.jl", run, 282, ["result = 1e9"]),
]
print("-- source pins --")
for fname, lines, ln, subs in pins:
    line = lines[ln - 1]
    check("%s:%d" % (fname, ln), all(s in line for s in subs), repr(line))

# ── B. blob identity launch == HEAD == origin ────────────────────────────
print("-- blob identity --")
for f in ("src/objective_v12.jl", "src/objective_evaluator.jl", "scripts/run_v13_5kw_masslift.jl"):
    ids = [git("rev-parse", "%s:%s" % (c, f)) for c in ("a76c5e9", "HEAD", "origin/bank-derate-cos2p65")]
    check("blob identity launch == HEAD == origin: " + f, len(set(ids)) == 1, str(ids))
check("a76c5e9 is an ancestor of HEAD",
      subprocess.run(["git", "-C", ROOT, "merge-base", "--is-ancestor", "a76c5e9", "HEAD"]).returncode == 0)

# ── C. winner closure on the source forms ────────────────────────────────
print("-- winner closure on the source forms --")
reeval = read("scratch/sv_p0_winner_reeval.txt")
masslog = read("scratch/av_b2_mass_recon.log")
conv = read("scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/convergence.csv")
tele3 = read("scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/telemetry.csv")
audit = read("docs/validation/2026-10-08-phase0-bankderate2-audit.md")

m = re.search(r"fitness_fn args: P_mean=([0-9.eE+-]+) FoS_min=([0-9.eE+-]+) mass=([0-9.eE+-]+)", reeval)
if m is None:
    print("FAIL  reeval 'fitness_fn args' line not found")
    sys.exit(1)
P_arg, F_arg, m_arg = (float(v) for v in m.groups())


def gre(pat, text):
    mm = re.search(pat, text, re.M)
    if mm is None:
        print("FAIL  pattern not found: " + pat)
        sys.exit(1)
    return float(mm.group(1))


P_end_f = gre(r"^  P_end = ([0-9.eE+-]+)", reeval)
P_range_f = gre(r"^  P_range = ([0-9.eE+-]+)", reeval)
tr_f = gre(r"^  twist_ratio = ([0-9.eE+-]+)", reeval)
fit_f = gre(r"^  fitness = ([0-9.eE+-]+)", reeval)
m_log = gre(r"m_b full = ([0-9.eE+-]+) kg", masslog)
conv_row = [r for r in conv.splitlines() if r.startswith("3,26,")][0]
fit_csv = float(conv_row.split(",")[2])
tele_row = [r for r in tele3.splitlines() if ",27.364," in r][0].split(",")
tr_t = float(tele_row[10])

mass, P_score, FoS = 25.69846825623688, 5.314113662272673, 14.971791422208508
tr, P_range, P_mean, fitness_rec = 0.4393474253185575, 0.028659374428010587, 5.3087794439367935, 27.3635412663488
CEIL, FOS_HARD = 5.0, 2.5

for name, good in [
    ("reeval fitness == convergence gen-26 == NR-005", fit_f == fitness_rec and fit_csv == fitness_rec),
    ("seam arg P_score == P_end field (tail-5 basis)", P_arg == P_score and P_end_f == P_score),
    ("seam arg FoS_min == field", F_arg == FoS),
    ("seam arg mass == NR-018 == mass log print", m_arg == mass and m_log == mass),
    ("twist_ratio reeval == telemetry column", tr_f == tr and tr_t == tr),
    ("P_range field matches", P_range_f == P_range),
]:
    check(name, good)

excess = max(P_score - CEIL, 0.0)
overpow = 5.0 * (excess * excess)
r = min(tr, 1.0)
margin = max(1.0 - r, 1e-6)
tw = 1.0 * ((r / margin) * (r / margin))
util = 20.0 * ((FOS_HARD / FoS) * (FOS_HARD / FoS))
swing = P_range / P_mean
stat = 10.0 * max(0.0, swing - 0.20)
f_calc = ((((mass + overpow) + 0.0) + util) + stat) + tw

print("over-power   =  5.0 * (P_score - 5.0)^2       = %r   (P_score %r, excess %r)" % (overpow, P_score, excess))
print("utilisation  = 20.0 * (2.5 / FoS_min)^2       = %r" % util)
print("twist        =  1.0 * (r / (1 - r))^2         = %r   (r %r)" % (tw, r))
print("stationarity = 10.0 * max(0, swing - 0.20)    = %r   (swing %r)" % (stat, swing))
print("closure      = %r   recorded = %r   diff = %r" % (f_calc, fitness_rec, f_calc - fitness_rec))
check("closure diff == 0.0", f_calc == fitness_rec, "%r" % (f_calc - fitness_rec,))

ma = re.search(r"mass ([0-9.]+) \+ overpower ([0-9.]+) \+ utilisation ([0-9.]+) \+ twist ([0-9.]+)", audit)
if ma:
    am, ao, au, at_ = (float(v.rstrip(".")) for v in ma.groups())
    check("Phase 0 audit string equals: mass", am == mass)
    check("Phase 0 audit string equals: overpower", ao == overpow)
    check("Phase 0 audit string equals: utilisation", au == util)
    check("Phase 0 audit string equals: twist", at_ == tw)
else:
    check("Phase 0 audit term string found", False)

term_sum = overpow + util + tw
direct_gap = fitness_rec - mass
print("term sum     = %r" % term_sum)
print("direct gap   = %r" % direct_gap)
print("seam (sum - gap) = %r" % (term_sum - direct_gap))
check("term sum equals 1.665073010111922", term_sum == 1.665073010111922, repr(term_sum))
check("direct gap equals 1.6650730101119215 (the NR-039 total)", direct_gap == 1.6650730101119215, repr(direct_gap))
check("term sum minus direct gap sits inside 1e-15 (the recorded 4.4e-16 seam)",
      0.0 < term_sum - direct_gap < 1e-15, repr(term_sum - direct_gap))
reg = read("docs/reporting/numbers-register.md")
check("register NR-039 carries the three penalty strings",
      all(s in reg for s in ("0.49333696413175443", "0.5576509889014662", "0.6140850570787014")))

# ── D. reject census: the 1.0e9 stamp over all 930 rows ──────────────────
print("-- reject census (three telemetry files) --")
counts = Counter()
non_ok = 0
ok_rows = 0
bad = []
min_ok = None
for isl in (1, 2, 3):
    path = "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_%d/telemetry.csv" % isl
    for line in read(path).splitlines():
        if not line or line.startswith("#") or line.startswith("island,"):
            continue
        c = line.split(",")
        if len(c) < 6:
            continue
        fit, status = c[3], c[4]
        counts[status] += 1
        if status == "ok":
            ok_rows += 1
            v = float(fit)
            if fit == "1.0e9":
                bad.append((isl, fit, status))
            min_ok = v if min_ok is None or v < min_ok else min_ok
        else:
            non_ok += 1
            if fit != "1.0e9":
                bad.append((isl, fit, status))

print("ok rows:", ok_rows, "| non-ok rows:", non_ok, "| stamp '1.0e9':", non_ok, "| least ok score:", min_ok)
print("status mix:", dict(counts))
check("row totals read 930", sum(counts.values()) == 930)
check("status mix reads 508 / 301 / 110 / 11 (NR-002)",
      counts["ok"] == 508 and counts["reject"] == 301 and counts["clearance_reject"] == 110
      and counts["reject_twist"] == 11, str(dict(counts)))
check("every non-ok row carries the 1.0e9 stamp; no ok row does",
      non_ok == 422 and ok_rows == 508 and not bad, str(bad[:4]))
check("least ok score is the island-3 winner 27.364", min_ok == 27.364)

if not ok:
    print("SV_NR046_FAIL")
    sys.exit(1)
print("SV_NR046_DONE  (source pinned; blob identity launch == HEAD == origin; closure exact; reject census clean)")
