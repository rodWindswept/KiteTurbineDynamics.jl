#!/usr/bin/env python3
"""scratch/sv_sv5_margins_check.py - science-validator, 2026-10-13.

SV5 margin block: recompute every quoted margin from committed bytes.
Read-only. Sources (all committed):
  docs/reporting/figures/pair-extract/extract-winner-operating-point.log
  scripts/run_v13_5kw_masslift.jl            (gate constants)
  scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/telemetry.csv
  scratch/sv_w7_knob_rerun_2026-10-13.log    (this seat's knob re-run)
  scratch/av_w7_clearance_probe_2026-10-13.log (aero knob run)
Prints the margin table and gates the quote forms. Sentinels only when OK.
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTRACT = os.path.join(ROOT, "docs/reporting/figures/pair-extract/extract-winner-operating-point.log")
RUNNER = os.path.join(ROOT, "scripts/run_v13_5kw_masslift.jl")
TELE = os.path.join(ROOT, "scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2/island_3/telemetry.csv")
SV_LOG = os.path.join(ROOT, "scratch/sv_w7_knob_rerun_2026-10-13.log")
AV_LOG = os.path.join(ROOT, "scratch/av_w7_clearance_probe_2026-10-13.log")

EXTRACT_SHA = "7579e84a5724a2a41f9ada08200b0dc59e0a03177ce9193c4978abc1d71474f8"

fails = []


def check(name, got, want):
    ok = got == want
    if not ok:
        fails.append(f"{name}: got {got!r} want {want!r}")
    print(f"  {'OK ' if ok else 'FAIL'} {name}: {got!r} == {want!r}")
    return ok


def near(name, got, want, tol):
    ok = abs(got - want) < tol
    if not ok:
        fails.append(f"{name}: |{got} - {want}| >= {tol}")
    print(f"  {'OK ' if ok else 'FAIL'} {name}: diff {abs(got - want):.3e} < {tol:.0e}")
    return ok


# ---- extract log ----------------------------------------------------------
etext = open(EXTRACT).read()
sha = hashlib.sha256(open(EXTRACT, "rb").read()).hexdigest()
print("== pins ==")
check("extract sha256", sha, EXTRACT_SHA)
check("extract sha matches receipt form", sha[:8] + "...", "7579e84a...")

clr = float(re.search(r"clearance = ([0-9.]+) m", etext).group(1))
P_end = float(re.search(r"P_end = ([0-9.]+)", etext).group(1))
FoS = float(re.search(r"FoS_min = ([0-9.]+)", etext).group(1))

segs = {}
for line in etext.splitlines():
    m = re.match(r"^(S[1-5]) \| (.+)$", line)
    if m:
        f = [c.strip() for c in line.split("|")]
        segs[m.group(1)] = dict(twist=float(f[5]), dcrit=float(f[6]),
                                tau=float(f[8]), cap=float(f[9]))
print(f"== extract read ==")
print(f"  clearance {clr!r}  P_end {P_end!r}  FoS_min {FoS!r}  segments {sorted(segs)}")

# ---- runner constants -----------------------------------------------------
rtext = open(RUNNER).read()
MIN_CLR = float(re.search(r"MIN_CLEARANCE = ([0-9.]+)", rtext).group(1))
P_FLOOR = float(re.search(r"p_floor_kw = ([0-9.]+)", rtext).group(1))
FOS_HARD = float(re.search(r"fos_hard = ([0-9.]+)", rtext).group(1))
print(f"== runner constants ==")
print(f"  MIN_CLEARANCE {MIN_CLR}  p_floor_kw {P_FLOOR}  fos_hard {FOS_HARD}")

# ---- telemetry row 3,26,9 -------------------------------------------------
tele_clr = None
for line in open(TELE):
    if line.startswith("3,26,9,"):
        tele_clr = float(line.split(",")[11])
check("telemetry 3,26,9 clearance", tele_clr, 5.47)

# ---- knob re-runs ---------------------------------------------------------
sv_vals = [float(v) for v in re.findall(r"clearance = ([0-9.]+)", open(SV_LOG).read())]
av_vals = [float(v) for v in re.findall(r"clearance = ([0-9.]+)", open(AV_LOG).read())]
print("== knob runs ==")
print(f"  sv rerun gate/score: {sv_vals}")
print(f"  av  run  gate/score: {av_vals}")
check("sv rerun == av run (both paths)", sv_vals, av_vals)
near("gate path vs extract", sv_vals[0] - clr, 0.0, 1e-12)
check("gate rounds to telemetry", round(sv_vals[0], 2), 5.47)
check("score rounds to telemetry", round(sv_vals[1], 2), 5.47)
print(f"  decode paths apart by {abs(sv_vals[1] - sv_vals[0]):.3e} m")

# ---- margins --------------------------------------------------------------
print("== margins ==")

clr_m = clr - MIN_CLR
check("clearance margin quote", f"{clr_m:.3f}", "3.968")
check("clearance ratio quote", f"{clr / MIN_CLR:.2f}", "3.65")
check("clearance percent quote", f"{clr_m / MIN_CLR * 100:.1f}", "264.5")

pm = P_end - P_FLOOR
check("power margin quote", f"{pm:.3f}", "0.314")
check("power percent quote", f"{pm / P_FLOOR * 100:.2f}", "6.28")
check("power ratio quote", f"{P_end / P_FLOOR:.2f}", "1.06")

fm = FoS - FOS_HARD
check("FoS ratio quote", f"{FoS / FOS_HARD:.2f}", "5.99")
check("FoS margin quote", f"{fm:.3f}", "12.472")
check("FoS percent quote", f"{fm / FOS_HARD * 100:.1f}", "498.9")

tw = {k: v["dcrit"] - v["twist"] for k, v in segs.items()}
least = min(tw, key=tw.get)
print(f"  segment twist margins: " + ", ".join(f"{k} {tw[k]:.3f}" for k in sorted(tw)))
check("least twist margin segment", least, "S1")
s1 = segs["S1"]
check("S1 twist margin quote", f"{tw['S1']:.3f}", "64.913")
check("S1 twist ratio quote", f"{s1['dcrit'] / s1['twist']:.2f}", "2.91")
check("S1 twist percent quote", f"{tw['S1'] / s1['dcrit'] * 100:.1f}", "65.7")

tr = segs["S1"]["cap"] / segs["S1"]["tau"]
check("S1 torque ratio quote", f"{tr:.2f}", "2.03")
check("S1 torque percent quote", f"{(tr - 1) * 100:.1f}", "102.9")

print("== full digits ==")
print(f"  clear margin {clr_m!r}  ratio {clr / MIN_CLR!r}  pct {clr_m / MIN_CLR * 100!r}")
print(f"  power margin {pm!r}  pct {pm / P_FLOOR * 100!r}")
print(f"  fos ratio {FoS / FOS_HARD!r}  margin {fm!r}  pct {fm / FOS_HARD * 100!r}")
print(f"  twist S1 margin {tw['S1']!r}  ratio {s1['dcrit'] / s1['twist']!r}")
print(f"  torque S1 ratio {tr!r}")

if fails:
    print("\nFAILURES:")
    for f in fails:
        print("  " + f)
    sys.exit(1)
print("\nSV_SV5_MARGINS_OK")
