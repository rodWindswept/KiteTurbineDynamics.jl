#!/usr/bin/env python3
# sv_nr047_k_sweep_rows_check.py — the k-sweep display rows sign (science-validator, 2026-10-14)
#
# The queue item: sign the six sweep display rows for section 2.3 (one row per k),
# the omega column named (omega_final, not omega_eq), and the companion forms —
# the tip pair, the two retirements — as NR-047. Plus the sizing-side pair as
# NR-048. This checker:
#   A. pins the sweep file (blob d17d1377) at the landing commit, HEAD and origin,
#   B. recomputes the six display rows from the raw CSV at full precision,
#   C. pins the comment and code sites (sweep header, runner comment, ceiling gate),
#   D. pins the sizing-pair tokens at the two record files,
#   E. re-reads the register blocks NR-047 and NR-048 as written.
# Stdlib only. Token SV_NR047_DONE on success, SV_NR047_FAIL otherwise.
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ok = True
n = 0


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def check(name, good, extra=""):
    global ok, n
    n += 1
    tail = "" if good else ("  [" + extra + "]")
    print(("OK  " if good else "FAIL") + "  " + name + tail)
    ok = ok and good


def git(*args):
    return subprocess.run(["git", "-C", ROOT] + list(args), capture_output=True, text=True).stdout.strip()


def region(rel, a, b):
    return "\n".join(read(rel).splitlines()[a - 1:b])


print("sv_nr047_k_sweep_rows_check — read at HEAD", git("rev-parse", "--short", "HEAD"),
      "| origin", git("rev-parse", "--short", "origin/bank-derate-cos2p65"))

# ── A. the sweep file identity ───────────────────────────────────────────
print("-- A. the sweep file identity --")
BLOB = "d17d1377b191dde5b44df7f5534d0cdc4c48d0f3"
CSV = "scripts/results/k_sweep_daisy_5kw.csv"
check("blob hash-object == d17d1377 (the NR-041 pin)", git("hash-object", CSV) == BLOB, git("hash-object", CSV))
check("blob at the landing commit adea1a3 == d17d1377", git("rev-parse", "adea1a3:" + CSV) == BLOB)
check("blob at HEAD == d17d1377", git("rev-parse", "HEAD:" + CSV) == BLOB)
check("blob at origin == d17d1377", git("rev-parse", "origin/bank-derate-cos2p65:" + CSV) == BLOB)

# ── B. the six display rows recompute from the raw CSV ───────────────────
print("-- B. the six display rows recompute from the raw CSV --")
lines = [l for l in read(CSV).splitlines() if l and not l.startswith("#")]
check("column line reads k,status,P_mean,P_end,omega_eq,omega_final,FoS_min,T_lift,wall_s",
      lines[0] == "k,status,P_mean,P_end,omega_eq,omega_final,FoS_min,T_lift,wall_s", lines[0])
rows = {}
for l in lines[1:]:
    c = l.split(",")
    rows[float(c[0])] = c
check("ten data rows", len(rows) == 10, str(len(rows)))
check("omega_eq reads 0.0 on all ten rows (the column-name caution)",
      all(r[4] == "0.0" for r in rows.values()))

EXPECT = [
    (0.5, "reject", "3.49", "19.14", "51.8"),
    (1.0, "ok", "5.45", "17.64", "47.8"),
    (1.5, "ok", "6.78", "16.59", "42.8"),
    (1.94, "ok", "7.56", "15.80", "40.1"),
    (2.24, "ok", "8.00", "15.34", "36.4"),
    (3.0, "ok", "8.89", "14.42", "24.3"),
]
for k, st, p, w, fs in EXPECT:
    r = rows[k]
    p_f = "{:.2f}".format(float(r[2]))
    w_f = "{:.2f}".format(float(r[5]))
    fs_f = "{:.1f}".format(float(r[6]))
    check("k %g: status %s, P_mean %s, omega_final %s, FoS %s recompute" % (k, st, p, w, fs),
          r[1] == st and p_f == p and w_f == w and fs_f == fs,
          "got %s / %s / %s / %s" % (r[1], p_f, w_f, fs_f))

check("k 0.5 sits under the 5.0 kW floor (reject)", float(rows[0.5][2]) < 5.0)
check("the other nine rows read ok", all(r[1] == "ok" for k, r in rows.items() if k != 0.5))
band = [float(rows[k][2]) for k in (4.0, 5.39, 7.0, 9.0)]
check("plateau band k 4.0 to 9.0 reads 8.9475 to 8.9511 (NR-041)",
      round(min(band), 4) == 8.9475 and round(max(band), 4) == 8.9511, str(band))
check("the k=5.39 row P_end reads 8.97 at 2 dp (the '~9 kW' claim)",
      "{:.2f}".format(float(rows[5.39][3])) == "8.97")

# ── C. the pin sites ─────────────────────────────────────────────────────
print("-- C. the pin sites --")
sw = region("scripts/sweep_k_mppt_5kw.jl", 6, 8)
check("sweep header: 6-blade anchor line", "k_daisy(6-blade) = 0.175" in sw and "= 2.24" in sw)
check("sweep header: 3-blade anchor line", "k_daisy(3-blade) = 0.42" in sw and "= 5.39" in sw)
check("sweep header: theory anchor line", "theory (params_10kw mass_scale) = 1.94" in sw)
check("sweep K_SWEEP list carries the ten loads",
      "const K_SWEEP = [0.5, 1.0, 1.5, 1.94, 2.24, 3.0, 4.0, 5.39, 7.0, 9.0]" in read("scripts/sweep_k_mppt_5kw.jl"))
check("sweep header names the omega column",
      "omega_final = ground-ring omega at window end" in read("scripts/sweep_k_mppt_5kw.jl"))

run = region("scripts/run_v13_5kw_masslift.jl", 158, 168)
check("runner comment: k=2.24 pairing",
      "2.24 sustains 8.0 kW (P_end, converged window)" in run and "(tip 73 m/s), FoS 36" in run)
check("runner comment: k=1.0 pairing",
      "k=1.0 sustains 5.45 kW" in run and "\u03c9 17.6 (tip 85 m/s, near the 100 m/s ceiling)" in run)
check("runner comment: the 5.39 retirement", "5.39 (3-blade anchor) was chosen on the BROKEN machine" in run)
check("runner comment: the ~9 kW claim", "forces ~9 kW from the 60" in run)
check("runner comment: the 3.55 retirement",
      "NOT p_base.k_mppt (3.55" in run and "mass_scale'd, unanchored" in run)
check("compute_seeds pins the single-source k",
      "const K_MPPT_5KW_HONEST = 2.24" in read("scripts/compute_seeds.jl"))

ev = read("src/objective_evaluator.jl")
check("ceiling const reads 100.0 at :103", "const TIP_SPEED_CEILING_MPS = 100.0" in ev)
evr = region("src/objective_evaluator.jl", 420, 438)
check("ceiling applied to ring rims", "abs(w) * r_ring <= TIP_SPEED_CEILING_MPS" in evr)
check("ceiling applied to the hub rotor tip", "abs(w_hub) * sys.rotor.radius <= TIP_SPEED_CEILING_MPS" in evr)
check("ceiling applied to expansion rotor tips", "abs(w) * er.blade_tip_radius <= TIP_SPEED_CEILING_MPS" in evr)

# ── D. the sizing-pair tokens ────────────────────────────────────────────
print("-- D. the sizing-pair tokens --")
dec = read("DECISIONS.md")
check("DECISIONS: the ruling heading",
      "## [2026-09-06] TRPT beam sizing: load case = generator load step" in dec)
check("DECISIONS: the load-step sizing token",
      "Sizing load case = a bounded generator load step" in dec
      and "(nominal `k_mppt \u00d7 2`)" in dec
      and "measured `F_helix \u2248 1278 N/vertex` on the hub segment" in dec)
check("DECISIONS: the k-easing refusal token", "rotor spins up to twist 87.9\u00b0 > 78.8\u00b0" in dec)

pl = read("docs/plans/2026-09-06-closed-form-beam-sizing.md")
check("plan: section 7.1 restates the sizing pair",
      "load step** (nominal `k_mppt \u00d7 2`), measured `F_helix \u2248 1278 N/vertex` on the" in pl)
check("plan: the scenario list carries the k-ease line",
      "25 m/s spins the rotor up to twist 87.9\u00b0 (> 78.8\u00b0 collapse)" in pl)
check("plan: the load-step x2 row",
      "load step \u00d72** \u2192 `F_helix` 1278 N/vertex, twist 50.8\u00b0 (under limit)" in pl)
check("plan: names the evidence script", "scratch/scenario_sweep.jl" in pl)
check("the scenario sweep script is committed",
      git("ls-files", "scratch/scenario_sweep.jl") == "scratch/scenario_sweep.jl")

# ── E. the register blocks as written ────────────────────────────────────
print("-- E. the register blocks as written --")
reg = read("docs/reporting/numbers-register.md")
check("register carries the NR-047 block",
      "## Derived row: NR-047, the k-sweep display rows for section 2.3" in reg)
check("register carries the NR-048 block",
      "## Derived row: NR-048, the sizing-side pair for the k = 2.24 story" in reg)
check("the display table reads one row per k",
      "| 0.5 | reject | 3.49 | 19.14 | 51.8 |" in reg
      and "| 2.24 | ok | 8.00 | 15.34 | 36.4 |" in reg
      and "| 3.0 | ok | 8.89 | 14.42 | 24.3 |" in reg)
check("the omega column is named in the NR-047 block",
      "The settled speed reads in `omega_final`." in reg)
check("the NR-047 id row is signed",
      "| NR-047 |" in reg and "signed (science-validator, 2026-10-14)" in reg)
check("the NR-048 id row is signed", "| NR-048 |" in reg)

if not ok:
    print("SV_NR047_FAIL")
    sys.exit(1)
print("SV_NR047_DONE  (%d checks: sweep pinned at adea1a3 == HEAD == origin; six display rows"
      " recompute; pin sites read; sizing pair pinned; register blocks read)" % n)
