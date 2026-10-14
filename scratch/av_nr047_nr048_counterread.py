#!/usr/bin/env python3
"""Item-8 aero leg, part 1: the NR-047 / NR-048 counter-read
(aero-validator, 2026-10-14).

The science-validator signed the k-sweep display rows (NR-047) and the
sizing-side pair (NR-048) at `07e2eb9` and requested the counter-read
from the aero seat. This pass:

  [A] pins the sweep file (blob d17d1377) at the landing commit, HEAD
      and origin, and pins the code and comment sites;
  [B] recomputes all six display triples from the raw CSV at full
      precision and rounds them under the reading rules;
  [C] re-reads the companion forms (tips, retirements) and the sizing
      tokens at the record files;
  [D] re-reads the register blocks NR-047 and NR-048 as written;
  [E] re-runs the seat checker (scratch/sv_nr047_k_sweep_rows_check.py)
      and requires SV_NR047_DONE at 46 checks, 0 fail.

Reads committed bytes and the working tree copies of the edited
surfaces only. Runs no simulator. Stdlib only.
"""
import csv
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
CSV = "scripts/results/k_sweep_daisy_5kw.csv"
SWEEP = "scripts/sweep_k_mppt_5kw.jl"
RUNNER = "scripts/run_v13_5kw_masslift.jl"
EVAL = "src/objective_evaluator.jl"
SEEDS = "scripts/compute_seeds.jl"
DRAFT = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
REG = "docs/reporting/numbers-register.md"
DEC = "DECISIONS.md"
PLAN = "docs/plans/2026-09-06-closed-form-beam-sizing.md"
CHECKER = "scratch/sv_nr047_k_sweep_rows_check.py"
BLOB = "d17d1377b191dde5b44df7f5534d0cdc4c48d0f3"
LANDING = "adea1a3"
DRAFT_REV = "12a5753"

OK = 0
FAIL = 0


def ok(msg):
    global OK
    OK += 1
    print(f"  ok   {msg}")


def bad(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args],
                          capture_output=True, text=True).stdout.strip()


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


tip = git("rev-parse", "--short", "HEAD")
print(f"av_nr047_nr048_counterread — read at HEAD {tip} "
      f"| origin {git('rev-parse', '--short', 'origin/bank-derate-cos2p65')}")

# ── A. the sweep-file and site pins ─────────────────────────────────────
print("[A] the sweep file and the sites")
h = git("hash-object", CSV)
(ok if h == BLOB else bad)(f"worktree CSV hashes to d17d1377 ({h[:12]})")
for rev in (LANDING, "HEAD", "origin/bank-derate-cos2p65"):
    b = git("rev-parse", f"{rev}:{CSV}")
    (ok if b == BLOB else bad)(f"CSV blob at {rev} == d17d1377")
sweep = read(SWEEP)
(ok if "K_SWEEP = [0.5, 1.0, 1.5, 1.94, 2.24, 3.0, 4.0, 5.39, 7.0, 9.0]" in sweep
 else bad)("sweep script carries the load list")
(ok if "omega_final = ground-ring omega at window end" in sweep
 else bad)("sweep script names omega_final")
for s in ("0.175·(5/1.5)^2.5 = 2.24", "0.42·(5/1.5)^2.5", "mass_scale) = 1.94"):
    (ok if s in sweep else bad)(f"sweep header anchor reads: {s}")
runner = read(RUNNER)
for s in ("2.24 sustains 8.0 kW (P_end, converged window) at ω 15.3",
          "(tip 73 m/s), FoS 36.",
          "k=1.0 sustains 5.45 kW but at",
          "ω 17.6 (tip 85 m/s, near the 100 m/s ceiling)",
          "5.39 (3-blade anchor) was chosen on the BROKEN machine",
          "forces ~9 kW from the 60 m² seed",
          "NOT p_base.k_mppt (3.55 — mass_scale'd, unanchored)"):
    (ok if s in runner else bad)(f"runner comment reads: {s[:44]}")
ev = read(EVAL).splitlines()
(ok if "const TIP_SPEED_CEILING_MPS = 100.0" in ev[102] else bad)(
    "TIP_SPEED_CEILING_MPS = 100.0 at src/objective_evaluator.jl:103")
seeds = read(SEEDS)
(ok if "const K_MPPT_5KW_HONEST = 2.24" in seeds else bad)(
    "compute_seeds pins the single-source k at 2.24")
(ok if "k_mppt = K_MPPT_5KW_HONEST" in runner else bad)(
    "runner consumes the single source")

# ── B. the six display triples recompute from the raw CSV ───────────────
print("[B] the six triples recompute from the raw CSV")
rows = {}
with open(ROOT / CSV, encoding="utf-8") as f:
    lines = [l for l in f if l and not l.startswith("#")]
cr = list(csv.DictReader(lines))
(ok if len(cr) == 10 else bad)(f"csv carries ten data rows ({len(cr)})")
(ok if all(float(r["omega_eq"]) == 0.0 for r in cr) else bad)(
    "omega_eq reads 0.0 on all ten rows")
for r in cr:
    rows[r["k"]] = r
DISPLAY = {
    "0.5": ("reject", "3.49", "19.14", "51.8"),
    "1.0": ("ok", "5.45", "17.64", "47.8"),
    "1.5": ("ok", "6.78", "16.59", "42.8"),
    "1.94": ("ok", "7.56", "15.80", "40.1"),
    "2.24": ("ok", "8.00", "15.34", "36.4"),
    "3.0": ("ok", "8.89", "14.42", "24.3"),
}
draft = read(DRAFT)
draftn = re.sub(r"\s+", " ", draft)
reg = read(REG)
regn = re.sub(r"\s+", " ", reg)
for k, (st, p, w, fo) in DISPLAY.items():
    r = rows[k]
    fp, fw, ff = (f"{float(r['P_mean']):.2f}", f"{float(r['omega_final']):.2f}",
                  f"{float(r['FoS_min']):.1f}")
    good = (r["status"] == st and fp == p and fw == w and ff == fo)
    (ok if good else bad)(f"k {k}: recompute rounds to {st} {p} {w} {fo} "
                          f"(got {r['status']} {fp} {fw} {ff})")
    line = f"| {k} | {st} | {p} | {w} | {fo} |"
    (ok if line in draft else bad)(f"draft table reads '{line}'")
    (ok if line in reg else bad)(f"register NR-047 table reads '{line}'")
(ok if float(rows["0.5"]["P_mean"]) < 5.0 else bad)(
    "k 0.5 reads under the 5.0 kW bar")
(ok if f"{float(rows['5.39']['P_end']):.2f}" == "8.97" else bad)(
    "k 5.39 P_end rounds to 8.97 (the '~9 kW' cross-read)")
(ok if "5.450868423585806" == rows["1.0"]["P_mean"] and
     "17.635572770055294" == rows["1.0"]["omega_final"] and
     "47.800187200992305" == rows["1.0"]["FoS_min"] else bad)(
    "k 1.0 full-precision triple reads as recorded")
(ok if "7.997584762516935" == rows["2.24"]["P_mean"] and
     "15.343704281699525" == rows["2.24"]["omega_final"] and
     "36.41539771790948" == rows["2.24"]["FoS_min"] else bad)(
    "k 2.24 full-precision triple reads as recorded")

# ── C. the companion forms and the sizing tokens ────────────────────────
print("[C] the companion forms and the sizing tokens")
for s in ("3.55 was a mass-scaled value with no anchor.",
          "5.39 was the 3-blade anchor chosen on the broken machine.",
          "That load forces about 9 kW from the seed (NR-047).",
          "The k 1.0 row settles at omega 17.6, tip about 85 m/s, near the 100 m/s ceiling.",
          "The selected k 2.24 settles at omega 15.3, tip about 73 m/s (NR-047).",
          "The FoS_min column reads 36.4 at k 2.24, down to 24.3 at k 3.0 (NR-047).",
          "The objective charges 5 kg-equivalent per excess kW squared above the 5.0 kW ceiling (NR-046).",
          "The beam sizes on a bounded generator load step, twice the nominal load (NR-048).",
          "The hub-segment helix force reads about 1278 N/vertex (NR-048).",
          "The low-wind lull is benign under the load law.",
          "The record refuses k easing as the high-wind substitute.",
          "The rotor spins up to 87.9° of twist against the 78.8° collapse limit (NR-048)."):
    (ok if s in draft else bad)(f"draft reads: {s[:48]}...")
dec = read(DEC)
(ok if "measured `F_helix ≈ 1278 N/vertex` on the hub segment" in dec else bad)(
    "DECISIONS [2026-09-06] carries the sizing token")
(ok if "rotor spins up to twist 87.9° > 78.8°" in dec else bad)(
    "DECISIONS carries the k-easing refusal")
plan = read(PLAN)
(ok if "nominal `k_mppt × 2`" in plan and "1278 N/vertex" in plan else bad)(
    "plan section 7.1 restates the sizing pair")
(ok if "twist 87.9° (> 78.8° collapse)" in plan else bad)(
    "plan scenario list carries the k-ease line")
(ok if (ROOT / "scratch/scenario_sweep.jl").exists() else bad)(
    "the scenario sweep script is committed")

# ── D. the register blocks as written ───────────────────────────────────
print("[D] the register blocks as written")
(ok if "## Derived row: NR-047" in reg else bad)("register carries the NR-047 block")
(ok if "## Derived row: NR-048" in reg else bad)("register carries the NR-048 block")
(ok if reg.count("Counter-read requested from the aero seat.") >= 2 else bad)(
    "both blocks request the aero counter-read")
(ok if "## Aero counter-read: NR-047, NR-048 (2026-10-14, aero-validator)" in reg
 else bad)("the aero counter-read block lands")
(ok if "Verdict: no discrepancy found. Both rows stand as signed." in reg
 else bad)("the verdict line reads")
(ok if "## Aero wording amends: NR-025 (2026-10-14, aero-validator)" in reg
 else bad)("the NR-025 wording amend lands")
(ok if '"the rope-break check armed across both"' in regn else bad)(
    "the amend carries the detector form")

# ── E. the draft fold pin and the guards ────────────────────────────────
print("[E] the draft fold pin and the guards")
pin = git("rev-parse", f"{DRAFT_REV}:{DRAFT}")
for rev in (DRAFT_REV, "HEAD", "origin/bank-derate-cos2p65"):
    b = git("rev-parse", f"{rev}:{DRAFT}")
    (ok if b == pin and b != "" else bad)(f"draft blob at {rev} == {DRAFT_REV}")
(ok if "The sweep rows read as follows (NR-047)." in draft else bad)(
    "the fold introduces the table at NR-047")
(ok if "omega_final (rad/s)" in draft else bad)("the draft names omega_final")
(ok if draft.count("enabl") == 0 else bad)("draft reads zero 'enabl'")
(ok if draft.count("breaks only") == 0 else bad)("draft reads zero 'breaks only'")
(ok if "It never allows breaks." in draft else bad)(
    "the safety set states the negation")
(ok if "The evaluator arms the rope-break check across the relax and the window." in draftn
 else bad)("the detector form reads in the draft")
(ok if draft.count("3.816") == 0 else bad)("guarded 3.816 absent")
(ok if len(re.findall(r"27\.363(?!\d)", draft)) == 0 else bad)(
    "guarded rounded 27.363 absent")

# ── F. the seat checker re-runs ─────────────────────────────────────────
print("[F] the seat checker re-runs")
r = subprocess.run([sys.executable, str(ROOT / CHECKER)],
                   capture_output=True, text=True)
(ok if r.returncode == 0 else bad)(f"checker exit {r.returncode}")
(ok if "SV_NR047_DONE" in r.stdout else bad)("checker token SV_NR047_DONE")
m = re.search(r"\(46 checks", r.stdout)
(ok if m else bad)("checker reads 46 checks")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_NR047_COUNTERREAD_DONE" if FAIL == 0 else "AV_NR047_COUNTERREAD_FAIL")
sys.exit(1 if FAIL else 0)
