#!/usr/bin/env python3
# sv_nr039_fitness_recon.py — NR-039 island-3 fitness decomposition (science-validator, 2026-10-12)
# Reconciles NR-005 (island-3 best fitness, 27.364 kg) against NR-018 (winner airborne mass, 25.698 kg).
#
# Fitness chain at launch a76c5e9 (the commit that produced the dataset; PROVENANCE.md):
#   objective_evaluator.jl:1148       P_score = P_end when power_stat = :tail5 (runner line 156 pins :tail5)
#   objective_evaluator.jl:1149       m_airborne = expansion_airborne_mass(sys, pc)
#   objective_evaluator.jl:1161       fitness = fitness_fn(P_score, FoS_min, cfg, m_airborne)
#   objective_evaluator.jl:1192-1194  stationarity add (swing gate 0.20, lambda 10.0)
#   objective_evaluator.jl:1200-1203  twist add (W_TWIST_KG = 1.0)
#   objective_v12.jl:114-116 weights (5.0 / 1.0 / 20.0); :145-168 appropriate_mass_fitness body
#
# Inputs are the stored full-precision fields. Each one is cross-checked against a raw
# artifact before the arithmetic runs. Stdlib only.
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def read(rel):
    with open(os.path.join(ROOT, rel)) as f:
        return f.read()

reeval = read("scratch/sv_p0_winner_reeval.txt")
masslog = read("scratch/av_b2_mass_recon.log")
conv = read("scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/convergence.csv")
tele = read("scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/telemetry.csv")

# ---------------------------------------------------------------------------
# Constants as stored (full precision) and their artifact anchors
# ---------------------------------------------------------------------------
mass        = 25.69846825623688        # NR-018; av_b2_mass_recon.log prints 25.6984682562368789
P_score     = 5.314113662272673        # the tail-5 score power (P_end) handed to the seam
FoS_min     = 14.971791422208508       # window minimum FoS, NR-009 basis
twist_ratio = 0.4393474253185575       # gate max_ratio (telemetry column, same instant)
P_range     = 0.028659374428010587     # NR-014 basis
P_mean      = 5.3087794439367935       # NR-008 basis
fitness_rec = 27.3635412663488         # convergence.csv gen 26 fitness = NR-005 full precision

CEIL, FOS_HARD = 5.0, 2.5
W_OVER, W_TWIST, W_UTIL = 5.0, 1.0, 20.0
LAMBDA, SWING_GATE = 10.0, 0.20

# ---------------------------------------------------------------------------
# Self-checks against the raw artifacts
# ---------------------------------------------------------------------------
ok = True

m = re.search(r"fitness_fn args: P_mean=([0-9.eE+-]+) FoS_min=([0-9.eE+-]+) mass=([0-9.eE+-]+)", reeval)
P_arg, F_arg, m_arg = (float(v) for v in m.groups())
P_end_f = float(re.search(r"^  P_end = ([0-9.eE+-]+)", reeval, re.M).group(1))
P_range_f = float(re.search(r"^  P_range = ([0-9.eE+-]+)", reeval, re.M).group(1))
tr_f = float(re.search(r"^  twist_ratio = ([0-9.eE+-]+)", reeval, re.M).group(1))
fit_f = float(re.search(r"^  fitness = ([0-9.eE+-]+)", reeval, re.M).group(1))
m_log = float(re.search(r"m_b full = ([0-9.eE+-]+) kg", masslog).group(1))
conv_row = [r for r in conv.splitlines() if r.startswith("3,26,")][0]
fit_csv = float(conv_row.split(",")[2])
tele_row = [r for r in tele.splitlines() if ",27.364," in r][0].split(",")
tr_t = float(tele_row[10])

checks = [
    ("reeval fitness == convergence.csv gen-26 fitness == NR-005",
        fit_f == fitness_rec and fit_csv == fitness_rec),
    ("seam arg P_score == P_end field (tail-5 charge basis)",
        P_arg == P_score and P_end_f == P_score),
    ("seam arg FoS_min == field", F_arg == FoS_min),
    ("seam arg mass == NR-018 == av_b2 log full-precision print",
        m_arg == mass and m_log == mass),
    ("twist_ratio (reeval) == telemetry column",
        tr_f == twist_ratio and tr_t == twist_ratio),
    ("P_range field matches", P_range_f == P_range),
]
print("-- self-checks against raw artifacts --")
for name, good in checks:
    print(("OK  " if good else "FAIL") + "  " + name)
    ok = ok and good

# ---------------------------------------------------------------------------
# Recompute the objective chain, in the evaluator's own operation order
# ---------------------------------------------------------------------------
excess = max(P_score - CEIL, 0.0)
overpow = W_OVER * (excess * excess)                    # W * excess^2 (literal_pow)
r = min(twist_ratio, 1.0)
margin = max(1.0 - r, 1e-6)
tw_term = W_TWIST * ((r / margin) * (r / margin))       # W * (tr / margin)^2
util = W_UTIL * ((FOS_HARD / FoS_min) * (FOS_HARD / FoS_min))
swing = P_range / P_mean
stat = LAMBDA * max(0.0, swing - SWING_GATE)

# Order: seam returns ((mass + overpow) + twist_default_0.0) + util;
# then + stationarity; then + twist term.
f_calc = ((((mass + overpow) + 0.0) + util) + stat) + tw_term

diff = f_calc - fitness_rec
pen_total = overpow + util + tw_term
gap = fitness_rec - mass

print("-- recomputation (single precision chain, Float64) --")
print("swing         =", repr(swing), " (gate 0.20 -> stationarity charge 0.0)")
print("over-power    =", repr(overpow), " %.17g" % overpow)
print("utilisation   =", repr(util), " %.17g" % util)
print("twist         =", repr(tw_term), " %.17g" % tw_term)
print("stationarity  =", repr(stat))
print("mass          =", repr(mass))
print("fitness calc  =", repr(f_calc))
print("fitness rec   =", repr(fitness_rec))
print("diff          =", repr(diff))
print("penalty total =", repr(pen_total))
print("gap (rec - mass) =", repr(gap))

print("-- cross-read against the Phase 0 audit term strings --")
audit_forms = [
    ("over-power", "0.49333696413175443", overpow),
    ("utilisation", "0.5576509889014662", util),
    ("twist", "0.6140850570787014", tw_term),
    ("mass", "25.69846825623688", mass),
    ("fitness", "27.3635412663488", fitness_rec),
]
for name, s, v in audit_forms:
    same = float(s) == v
    print(("OK  " if same else "FAIL") + "  %-11s audit %s" % (name, s))
    ok = ok and same

if not ok or diff != 0.0:
    print("SV_NR039_FAIL")
    sys.exit(1)
print("SV_NR039_DONE  (closure exact, diff = 0.0)")
