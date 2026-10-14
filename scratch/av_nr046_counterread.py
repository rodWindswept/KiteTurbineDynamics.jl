#!/usr/bin/env python3
"""NR-046 counter-read: the objective seam row and the printed block
(aero-validator, 2026-10-14).

Independent pass over the signed row (SV, 4a86e6f) and the printed
section 2.4 block (draft v0.36):
  [A] the thirty source sites, re-read at the pinned LAUNCH commit;
  [B] blob identity launch == HEAD == origin;
  [C] the winner closure, recomputed with own arithmetic from raw tokens;
  [D] the reject census over the raw telemetry (stamp x status cross);
  [E] the register row and the append-only landing;
  [F] the printed block: forms verbatim, cites, guards, token census.

Reads committed bytes only. Runs no simulator.
"""
import hashlib
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
REGISTER = ROOT / "docs/reporting/numbers-register.md"
DRAFT = ROOT / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
LAUNCH = "a76c5e9"
ROW_COMMIT = "4a86e6f"

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


def show(ref, path):
    return subprocess.run(["git", "-C", str(ROOT), "show", f"{ref}:{path}"],
                          capture_output=True, text=True).stdout


reg = REGISTER.read_text(encoding="utf-8")
draft = DRAFT.read_text(encoding="utf-8")
tip = git("rev-parse", "--short", "HEAD")
print(f"[0] counter-read   tip {tip}   launch {LAUNCH}   row commit {ROW_COMMIT}")

# ---------------------------------------------------------- [A] source pins
print("[A] the source sites, re-read at the launch commit")
obj = show(LAUNCH, "src/objective_v12.jl").splitlines()
ev = show(LAUNCH, "src/objective_evaluator.jl").splitlines()
run = show(LAUNCH, "scripts/run_v13_5kw_masslift.jl").splitlines()
PINS = [
    (obj, 114, "W_OVERPOWER_KG_PER_KW2 = 5.0"),
    (obj, 115, "W_TWIST_KG", "1.0"),
    (obj, 116, "W_UTILISATION_KG", "20.0"),
    (obj, 149, "FoS_min < cfg.fos_hard", "return Inf"),
    (obj, 150, "P_mean < cfg.p_floor_kw", "return Inf"),
    (obj, 153, "excess_kw = max(P_mean - cfg.p_ceiling_kw, 0.0)"),
    (obj, 154, "W_OVERPOWER_KG_PER_KW2 * excess_kw^2"),
    (obj, 161, "penalty_twist = W_TWIST_KG * (r / margin)^2"),
    (obj, 165, "W_UTILISATION_KG * (cfg.fos_hard / FoS_min)^2"),
    (obj, 167, "return mass + penalty_overpower + penalty_twist + penalty_util"),
    (ev, 90, "STATIONARITY_LAMBDA = 10.0"),
    (ev, 91, "STATIONARITY_SWING = 0.20"),
    (ev, 1148, "P_score = cfg.power_stat === :tail5 ? P_end : P_mean"),
    (ev, 1161, "fitness_fn(P_score, FoS_min, cfg, m_airborne)"),
    (ev, 1192, "swing = P_mean > 0.1 ? P_range / P_mean : 0.0"),
    (ev, 1193, "max(0.0, swing - STATIONARITY_SWING)"),
    (ev, 1194, "fitness = fitness + STATIONARITY_LAMBDA * excess"),
    (ev, 1200, "if twist_ratio_max[] > 0.0"),
    (ev, 1201, "tr = min(twist_ratio_max[], 1.0)"),
    (ev, 1202, "fitness = fitness + W_TWIST_KG * (tr / max(1.0 - tr, 1e-6))^2"),
    (run, 76, "MIN_CLEARANCE = 1.5"),
    (run, 153, "p_floor_kw = 5.0, p_ceiling_kw = 5.0"),
    (run, 155, "fos_target = 2.5, fos_hard = 2.5"),
    (run, 156, "power_stat = :tail5"),
    (run, 256, "if clearance < MIN_CLEARANCE"),
    (run, 257, "status = :clearance_reject"),
    (run, 266, "appropriate_mass_fitness(P, F, c, m)"),
    (run, 272, "r.twist_crossed ? :reject_twist : :reject"),
    (run, 281, "if status !== :ok"),
    (run, 282, "result = 1e9"),
]
n_pin = 0
for lines_, ln, *subs in PINS:
    line = lines_[ln - 1] if ln - 1 < len(lines_) else ""
    good = line != "" and all(s in line for s in subs)
    (ok if good else bad)(f"pin at launch line {ln}: {subs[0][:44]}")
    n_pin += 1

# --------------------------------------------------------- [B] blob identity
print("[B] blob identity launch == HEAD == origin")
for f, want in [("src/objective_v12.jl", "da9c5554"),
                ("src/objective_evaluator.jl", "52669d40"),
                ("scripts/run_v13_5kw_masslift.jl", "bf5c5e36")]:
    ids = [git("rev-parse", f"{ref}:{f}")
           for ref in (LAUNCH, "HEAD", "origin/bank-derate-cos2p65")]
    (ok if len(set(ids)) == 1 and ids[0].startswith(want) else bad)(
        f"{f.split('/')[-1]}: {ids[0][:8]} == launch == HEAD == origin")
rc = subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor",
                     LAUNCH, "HEAD"]).returncode
(ok if rc == 0 else bad)("launch sits in the tip ancestry")

# ------------------------------------------------------ [C] the closure
print("[C] the winner closure, own arithmetic from raw tokens")
reeval_path = ROOT / "scratch/sv_p0_winner_reeval.txt"
reeval = reeval_path.read_text() if reeval_path.exists() else ""


def one(pat, text, label, flags=re.M):
    m = re.search(pat, text, flags)
    if m is None:
        bad(f"{label}: pattern not found")
        return None
    return m.group(1)


P_arg = one(r"fitness_fn args: P_mean=([0-9.eE+-]+)", reeval, "seam arg line")
F_arg = one(r"FoS_min=([0-9.eE+-]+)", reeval, "seam arg FoS")
m_arg = one(r"mass=([0-9.eE+-]+)", reeval, "seam arg mass")
P_end = one(r"^\s*P_end = ([0-9.eE+-]+)", reeval, "P_end")
P_range = one(r"^\s*P_range = ([0-9.eE+-]+)", reeval, "P_range")
tr_tok = one(r"^\s*twist_ratio = ([0-9.eE+-]+)", reeval, "twist_ratio")
fit_tok = one(r"^\s*fitness = ([0-9.eE+-]+)", reeval, "fitness")
print(f"    raw tokens: P_end {P_end}  P_range {P_range}  "
      f"twist_ratio {tr_tok}  fitness {fit_tok}")

for token, where, label in [
        ("25.69846825623688", reg, "NR-018 mass token"),
        ("14.971791422208508", reg, "NR-009 FoS token"),
        ("5.314113662272673", reg, "tail-5 basis token"),
        ("0.028659374428010587", reg, "P_range token"),
        ("0.4393474253185575", reg, "twist ratio token"),
        ("27.3635412663488", reg, "fitness token")]:
    (ok if token in where else bad)(f"register carries the {label}")
for got, want, label in [
        (m_arg, "25.69846825623688", "mass == NR-018"),
        (F_arg, "14.971791422208508", "FoS_min == NR-009"),
        (P_arg, "5.314113662272673", "P_score == P_end (tail-5)"),
        (P_end, "5.314113662272673", "P_end field"),
        (tr_tok, "0.4393474253185575", "twist ratio field"),
        (fit_tok, "27.3635412663488", "fitness record")]:
    (ok if got == want else bad)(label)

tele3 = (ROOT / "scripts/results/v13_5kw_masslift_len18.8_rotorcount_"
         "bankderate2/island_3/telemetry.csv").read_text()
trow = [ln for ln in tele3.splitlines() if ",27.364," in ln]
(ok if len(trow) == 1 else bad)(f"telemetry winner row found ({len(trow)})")
if trow:
    cols = trow[0].split(",")
    (ok if cols[10] == tr_tok else bad)(
        f"telemetry twist_ratio column == reeval token ({cols[10]})")
conv = (ROOT / "scripts/results/v13_5kw_masslift_len18.8_rotorcount_"
        "bankderate2/island_3/convergence.csv").read_text()
crow = [ln for ln in conv.splitlines() if ln.startswith("3,26,")]
(ok if crow and crow[0].split(",")[2] == fit_tok else bad)(
    "convergence gen-26 fitness == record")

mass = float("25.69846825623688")
P = float("5.314113662272673")
FoS = float("14.971791422208508")
tr = float("0.4393474253185575")
P_r = float("0.028659374428010587")
P_m = float("5.3087794439367935")
fitness_rec = float("27.3635412663488")

excess = max(P - 5.0, 0.0)
op = 5.0 * (excess * excess)
ratio = 2.5 / FoS
util = 20.0 * (ratio * ratio)
r = min(tr, 1.0)
margin = max(1.0 - r, 1e-6)
tw = 1.0 * ((r / margin) * (r / margin))
swing = P_r / P_m
stat = 10.0 * max(0.0, swing - 0.20)
chain = ((((mass + op) + 0.0) + util) + stat) + tw

for got, want, label in [
        (repr(op), "0.49333696413175443", "over-power charge"),
        (repr(util), "0.5576509889014662", "utilisation charge"),
        (repr(tw), "0.6140850570787014", "twist charge"),
        (repr(chain), "27.3635412663488", "closure sum")]:
    (ok if got == want else bad)(f"{label}: {got} (want {want})")
(ok if stat == 0.0 else bad)(f"stationarity charge reads zero (swing {swing:.6f})")
term_sum = op + util + tw
direct_gap = fitness_rec - mass
seam = term_sum - direct_gap
(ok if repr(term_sum) == "1.665073010111922" else bad)(
    f"term sum {term_sum!r}")
(ok if repr(direct_gap) == "1.6650730101119215" else bad)(
    f"direct gap {direct_gap!r}")
(ok if repr(seam) == "4.440892098500626e-16" else bad)(
    f"seam gap {seam!r}")

nr039 = next(ln for ln in reg.splitlines() if ln.startswith("| NR-039 |"))
m3 = re.search(r"over-power ([\d.]+) \+ utilisation ([\d.]+) \+ twist ([\d.]+)",
               nr039)
(ok if m3 and (m3.group(1), m3.group(2), m3.group(3).rstrip(".")) ==
    ("0.49333696413175443", "0.5576509889014662", "0.6140850570787014")
    else bad)("NR-039 carries the three penalty strings")

# -------------------------------------------------- [D] the reject census
print("[D] the reject census over the raw telemetry")
counts = Counter()
stamp = Counter()
bad_rows = []
min_ok = None
for isl in (1, 2, 3):
    p = (ROOT / f"scripts/results/v13_5kw_masslift_len18.8_rotorcount_"
         f"bankderate2/island_{isl}/telemetry.csv")
    for ln in p.read_text().splitlines():
        if not ln or ln.startswith("#") or ln.startswith("island,"):
            continue
        c = ln.split(",")
        if len(c) < 6:
            continue
        fit, status = c[3], c[4]
        counts[status] += 1
        if status == "ok":
            if fit == "1.0e9":
                bad_rows.append((isl, fit, status))
            v = float(fit)
            min_ok = v if min_ok is None or v < min_ok else min_ok
        else:
            if fit != "1.0e9":
                bad_rows.append((isl, fit, status))
            stamp[status] += 1
(ok if sum(counts.values()) == 930 else bad)(
    f"row totals read 930 ({sum(counts.values())})")
(ok if (counts["ok"], counts["reject"], counts["clearance_reject"],
        counts["reject_twist"]) == (508, 301, 110, 11) else bad)(
    f"status mix 508/301/110/11 ({dict(counts)})")
(ok if sum(stamp.values()) == 422 and not bad_rows else bad)(
    f"422 stamped, no crossover ({len(bad_rows)} bad rows)")
(ok if min_ok == 27.364 else bad)(f"least ok score 27.364 ({min_ok})")

# ------------------------------------------- [E] the register row landing
print("[E] the register row and its landing")
nr046 = [ln for ln in reg.splitlines() if ln.startswith("| NR-046 |")]
(ok if len(nr046) == 1 else bad)("NR-046 row present")
row = nr046[0]
for token in ("f = mass + 5.0 * max(P_score - 5.0, 0)^2",
              "20.0 * (2.5 / FoS_min)^2", "1.0 * (r / (1 - r))^2",
              "r = min(twist_ratio, 1)",
              "10.0 * max(0, swing - 0.20)", "swing = P_range / P_mean",
              "422 of 930", "kg-equivalent", "`1e9` stamp is a search cost",
              "src/objective_v12.jl:114-116", ":145-168",
              "run_v13_5kw_masslift.jl:153-156, 256-257, 266, 272, 281-283"):
    (ok if token in row else bad)(f"row carries {token[:44]!r}")
(ok if "signed (science-validator, 2026-10-14)" in row else bad)(
    "row signed 2026-10-14")
num = git("diff", "--numstat", f"{ROW_COMMIT}^", ROW_COMMIT, "--",
          "docs/reporting/numbers-register.md")
add, dele = (num.split()[:2] if num else ("?", "?"))
(ok if dele == "0" else bad)(
    f"register landing append-only (+{add} / -{dele})")

# ------------------------------------------------- [F] the printed block
print("[F] the printed section 2.4 block (v0.36)")
block = draft.split("### 2.4 The campaign", 1)[1].split("### 2.5", 1)[0]
for token in ("`f = mass + 5.0 * max(P_score - 5.0, 0)^2 + 20.0 * "
              "(2.5 / FoS_min)^2 + 1.0 * (r / (1 - r))^2`",
              "`r = min(twist_ratio, 1)`",
              "`10.0 * max(0, swing - 0.20)`",
              "soft constraint penalties", "`1e9`", "kg-equivalent",
              "(NR-046)"):
    (ok if token in block else bad)(f"block carries {token[:52]!r}")
(ok if "gate penalties" not in draft else bad)(
    "old form 'gate penalties' absent from the draft")
(ok if "14.97" not in draft and "14.972" not in draft else bad)(
    "the 14.97 example does not print")
n_cite = block.count("(NR-046)")
(ok if n_cite >= 8 else bad)(f"block cites NR-046 at {n_cite} sites")

# token census of the prose (formula and table lines handled separately)
scrubbed = re.sub(r"\n\|.*\|", "", block)
scrubbed = re.sub(r"`[^`]*`", "", scrubbed)
scrubbed = re.sub(r"NR-\d{3}", "", scrubbed)
allowed = {"1.0", "5.0", "20.0", "10.0", "0.20", "2.5", "20",
           "310", "930", "40"}
left = []
for m in re.finditer(r"\d+(?:\.\d+)?(?:e\d+)?", scrubbed):
    t = m.group(0)
    if t not in allowed:
        ctx = scrubbed[max(0, m.start() - 40):m.end() + 40].replace("\n", " ")
        left.append((t, ctx))
(ok if not left else bad)(f"prose census clean ({len(left)} leftovers)")
for t, ctx in left:
    print(f"       leftover {t!r} near {ctx!r}")
tbl = [ln for ln in block.splitlines() if ln.startswith("|")]
tbl_tokens = set()
for ln in tbl:
    tbl_tokens |= set(re.findall(r"\d+(?:\.\d+)?(?:e\d+)?", ln))
(ok if {"3", "310", "930", "5.0", "2.5", "10", "40", "2.24", "18.8"} <=
    tbl_tokens else bad)(f"config table tokens {sorted(tbl_tokens)}")

print(f"\nchecks: {OK + FAIL}  ok: {OK}  fail: {FAIL}")
print("AV_NR046_DONE" if FAIL == 0 else "AV_NR046_FAIL")
sys.exit(1 if FAIL else 0)
