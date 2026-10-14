#!/usr/bin/env python3
"""Draft v0.34 — the polish pair two: design implications + conclusion (author seat, 2026-10-14).

Applies to the tip (e4ff3c1), fail-closed, two-state (base read from
`git show HEAD:<path>`; never from the working file):

  D1  version pin: v0.33 -> v0.34, date held 2026-10-14
  D2  head status line: the sweep-21 note. "Sections 3.4 to 3.6 await the
      Phase 1 to 3 interpretation." -> "Sections 3.4 to 3.6 carry their text."
  D3  section 3.6: the pending bracket retires; the design implications land
      (four implications + the merged next-step list)
  D4  section 5: the conclusion rewrites as a conditional decision statement
  T1  tracker v0.34 entry

Gates: STE per file (rc=0; total must not exceed base; no category
gains), declared token diff (draft + tracker), the register-seat
citation checker. --write copies candidates over the repo files only
when every gate is green.

Usage:
  python3 scratch/au_v034_polish_pair2.py          # build, gate, report
  python3 scratch/au_v034_polish_pair2.py --write  # copy candidates over repo files
"""
import hashlib
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER_REL = "docs/reporting/draft-tracker.md"
REG = "docs/reporting/numbers-register.md"
BASE_D = ROOT / "scratch/au_v034_draft_base.md"
CAND_D = ROOT / "scratch/au_v034_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v034_tracker_base.md"
CAND_T = ROOT / "scratch/au_v034_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v034_polish_pair2.log"

# Declared before the run — the full push delta against the tip.
# First pass runs with ASSERT_TOKENS False to print the live sets; the
# sets are baked here and the second pass asserts them exactly.
ASSERT_TOKENS = True
EXPECT_D_ADD = {
    "110": 1, "15.0": 1, "2": 1, "2.03": 1, "25.698": 2, "34": 1,
    "4": 1, "5": 1, "5.309": 1, "6": 1, "7": 1,
}
EXPECT_D_REM = {"3": 1, "33": 1}
EXPECT_T_ADD = {"3.6": 1, "34": 1}
EXPECT_T_REM = {}

D1 = (
    "Internal engineering report. Draft v0.33. Date 2026-10-14.",
    "Internal engineering report. Draft v0.34. Date 2026-10-14.",
)

D2 = (
    "Sections 3.4 to 3.6 await the Phase 1 to 3 interpretation.",
    "Sections 3.4 to 3.6 carry their text.",
)

D3_OLD = "### 3.6 Design implications [PENDING. Phase 3 and the regime table supply this.]"

D3_NEW = (
    "### 3.6 Design implications\n"
    "\n"
    "The record supports four implications.\n"
    "\n"
    "First, the searched TRPT family contains a compact feasible candidate under the modeled objective and gates.\n"
    "The winner produces 5.309 kilowatts of mean power with an airborne mass of 25.698 kilograms (NR-008, NR-018).\n"
    "\n"
    "Second, the winner holds large structural and twist margins at the final operating point.\n"
    "The window-minimum factor of safety is 15.0 (NR-009).\n"
    "The least segment torque margin is 2.03, at S1 (NR-040).\n"
    "The margins suggest room for further mass reduction.\n"
    "Any reduction waits on blade integrity and lifter validation.\n"
    "\n"
    "Third, future searches should treat clearance as a design constraint in its own right.\n"
    "The status mix reads 110 clearance_reject designs (NR-002).\n"
    "Future searches can steer away from low-clearance geometry with a clearance map or a shaped penalty.\n"
    "\n"
    "Fourth, part of the winner genome stays inactive at one active rotor (NR-011, NR-017).\n"
    "Conditional genes can improve the search efficiency without changing the machine problem.\n"
    "\n"
    "Recommended next steps:\n"
    "\n"
    "1. Fix the rapid-path rope-break gate before using the rapid path for screening (NR-013).\n"
    "\n"
    "2. Add blade root factor-of-safety checks to the structural gate set.\n"
    "\n"
    "3. Validate lifter modulation across the wind bands.\n"
    "\n"
    "4. Extend the wind cases beyond the steady sheared profile.\n"
    "\n"
    "5. Extend the model to the launch and recovery sequence.\n"
    "\n"
    "6. Extract the lever statistics from the campaign telemetry.\n"
    "\n"
    "7. Re-run a short campaign with conditional genes and a clearance-aware decoder."
)

D4_OLD = """## 5 Conclusion

The work runs a differential-evolution search over the design space of a rigid-wing ground-generation rotary kite turbine.
The machine uses a tensile rotary power transmission.
The campaign scores each design on the ODE path.
The measurement window stands behind every number.

The campaign found the best feasible candidate in 930 evaluations (NR-001).
The winner survives the full window.
Its power reads 5.309 kilowatts and its factor of safety 15.0 (NR-008, NR-009).
At the winner operating point, the least segment torque margin is 2.03, at S1 (NR-040).

The result shows that a compact TRPT machine can satisfy the power, clearance, twist and structural gates in simulation.
The large structural margins suggest room for further mass reduction.

The Daisy anchor ties the model to a measured flight reference.

The conclusion is conditional on the model.
Blade integrity is not yet gated.
Lifter modulation remains an assumption.
The rapid path awaits its rope-break gate fix (NR-013).

The next steps add blade structural checks, validate lifter modulation and complete the levers and implications sections.
The boundaries in the discussion name the work that comes next.
[Daisy values need register rows before the final report quotes
them.]"""

D4_NEW = """## 5 Conclusion

The report screened 930 rigid-wing ground-generation rotary kite turbine designs with a tensile rotary power transmission (NR-001).
The campaign scored each design on the ODE path over the measurement window (NR-015).
One fixed power-law generator load and one fixed gate set held for every design (NR-015).

The search found a feasible candidate in the searched space.
Its mean power is 5.309 kilowatts and its airborne mass is 25.698 kilograms (NR-008, NR-018).
Its window-minimum factor of safety is 15.0 (NR-009).
All checked TRPT rings and twist segments operate below their failure boundaries at the final operating point (NR-021, NR-022).
The least segment torque margin is 2.03, at S1 (NR-040).

The result shows that a compact TRPT machine can satisfy the power, clearance, twist and structural gates in simulation.
That result holds under the modeled load and wind.
It does not show flight readiness, a global optimum, or full structural safety.
Blade integrity is not yet gated, and lifter modulation remains an assumption.
The rapid path awaits its rope-break gate fix (NR-013).

The Daisy anchor ties the model to a measured flight reference.

The next work closes the model gaps.
Add blade structural checks and validate lifter modulation.
Extend the model to the launch and recovery sequence.
Extend the wind cases beyond the steady sheared profile.
The large structural margins suggest room for mass reduction, once those checks hold.

[Daisy values need register rows before the final report quotes
them.]"""

T1_OLD = "No value moves.\n\n## 2. Working notes"
T1_NEW = (
    "No value moves.\n\n"
    "v0.34 pass by @author (2026-10-14).\n"
    "This pass completes the design implications at section 3.6 and rewrites the conclusion.\n"
    "The next steps merge with the four front-block open items into one list.\n"
    "The head status line and the sweep-21 seam note settle.\n"
    "No value moves.\n\n## 2. Working notes"
)

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")


def run(cmd):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


def lint(path):
    r = run(["python3", "ste-lint.py", "--fail-above", "2.0", str(path)])
    m = re.search(r"total=\s*(\d+)\s+per100w=\s*([\d.]+)", r.stdout)
    total = int(m.group(1)) if m else None
    wm = re.search(r"words=\s*(\d+)", r.stdout)
    words = int(wm.group(1)) if wm else None
    cats = Counter()
    for line in r.stdout.splitlines():
        mm = re.match(r"\[HOOK:ste\].*?: ([a-z_()>0-9w]+) x(\d+)", line)
        if mm and mm.group(1) != "em_dash":
            cats[mm.group(1)] += int(mm.group(2))
    em = re.search(r"em_dash=\s*(\d+)", r.stdout)
    cats["_em_dash_info"] = int(em.group(1)) if em else 0
    return r.returncode, words, total, dict(cats)


def sh256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    write = "--write" in sys.argv
    log = []

    def say(s):
        print(s)
        log.append(s)

    head = run(["git", "rev-parse", "--short", "HEAD"]).stdout.strip()
    say(f"base tip: {head}")

    base_d = run(["git", "show", f"HEAD:{DRAFT_REL}"]).stdout
    base_t = run(["git", "show", f"HEAD:{TRACKER_REL}"]).stdout
    BASE_D.write_text(base_d)
    BASE_T.write_text(base_t)
    say(f"base draft sha256: {sh256(BASE_D)}")
    say(f"base tracker sha256: {sh256(BASE_T)}")

    # --- build the candidates ------------------------------------------
    cand_d = base_d
    pairs = [
        ("D1 version pin", D1[0], D1[1]),
        ("D2 head status line", D2[0], D2[1]),
        ("D3 section 3.6", D3_OLD, D3_NEW),
        ("D4 section 5 rewrite", D4_OLD, D4_NEW),
    ]
    for name, old, new in pairs:
        c = cand_d.count(old)
        if c != 1:
            say(f"ANCHOR FAIL {name}: count={c}")
            LOG_P.write_text("\n".join(log))
            sys.exit(1)
        cand_d = cand_d.replace(old, new, 1)
        say(f"ok {name}")

    cand_t = base_t
    c = cand_t.count(T1_OLD)
    if c != 1:
        say(f"ANCHOR FAIL T1 tracker entry: count={c}")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    cand_t = cand_t.replace(T1_OLD, T1_NEW, 1)
    say("ok T1 tracker entry")

    # --- guards ---------------------------------------------------------
    guards = [
        ("pin v0.34", "Draft v0.34" in cand_d and "Draft v0.33" not in cand_d),
        ("head line updated", "Sections 3.4 to 3.6 carry their text." in cand_d
         and "await the Phase 1 to 3 interpretation" not in cand_d),
        ("3.6 bracket retired", "[PENDING. Phase 3 and the regime table supply this.]" not in cand_d),
        ("implications block present",
         "The record supports four implications." in cand_d
         and "Recommended next steps:" in cand_d
         and "7. Re-run a short campaign with conditional genes and a clearance-aware decoder." in cand_d),
        ("conclusion opening", "The report screened 930 rigid-wing ground-generation rotary kite turbine designs" in cand_d),
        ("conclusion conditionals", "It does not show flight readiness, a global optimum, or full structural safety." in cand_d),
        ("daisy bracket held", "[Daisy values need register rows before the final report quotes\nthem.]" in cand_d),
        ("old conclusion gone", "The work runs a differential-evolution search over the design space" not in cand_d),
        ("no 14.972 print", "14.972" not in cand_d),
        ("markers held",
         all(m in cand_d for m in [
             "figure-map row 6 (ring utilisation plate",
             "figure-map row 7 (twist limit plate",
             "figure-map row 9 (machine evolution strip",
             "figure-map row 20 (the levers landscape",
             "figure-map row 21 (the parameter atlas",
         ])),
        ("section 3.5 intact", "The winner genome carries inactive slots at a rotor count of one (NR-011, NR-017)." in cand_d),
        ("tracker v0.34 entry", "v0.34 pass by @author" in cand_t),
        ("tracker history held", "v0.33 pass by @author" in cand_t and "v0.32 pass by @author" in cand_t),
        ("tracker no-value-moves count", cand_t.count("No value moves.") == 4),
    ]
    for label, ok in guards:
        say(f"guard {label}: {'ok' if ok else 'FAIL'}")
        if not ok:
            LOG_P.write_text("\n".join(log))
            sys.exit(1)

    CAND_D.write_text(cand_d)
    CAND_T.write_text(cand_t)
    say(f"candidate draft sha256: {sh256(CAND_D)}")
    say(f"candidate tracker sha256: {sh256(CAND_T)}")

    # --- STE gates ------------------------------------------------------
    rc_db, w_db, tot_db, cats_db = lint(BASE_D)
    rc_dc, w_dc, tot_dc, cats_dc = lint(CAND_D)
    rc_tb, w_tb, tot_tb, cats_tb = lint(BASE_T)
    rc_tc, w_tc, tot_tc, cats_tc = lint(CAND_T)
    say(f"STE draft base: rc={rc_db} words={w_db} total={tot_db} {cats_db}")
    say(f"STE draft candidate: rc={rc_dc} words={w_dc} total={tot_dc} {cats_dc}")
    say(f"STE tracker base: rc={rc_tb} words={w_tb} total={tot_tb} {cats_tb}")
    say(f"STE tracker candidate: rc={rc_tc} words={w_tc} total={tot_tc} {cats_tc}")
    gains_d = {k: v - cats_db.get(k, 0) for k, v in cats_dc.items() if v > cats_db.get(k, 0) and not k.startswith("_")}
    gains_t = {k: v - cats_tb.get(k, 0) for k, v in cats_tc.items() if v > cats_tb.get(k, 0) and not k.startswith("_")}
    if gains_d:
        say(f"draft category gains: {gains_d}")
    if gains_t:
        say(f"tracker category gains: {gains_t}")
    ste_ok = (rc_dc == 0 and rc_tc == 0
              and None not in (tot_db, tot_dc, tot_tb, tot_tc)
              and tot_dc <= tot_db and tot_tc <= tot_tb and not gains_d and not gains_t)

    # --- token diff -----------------------------------------------------
    ta, tb_ = Counter(TOK.findall(base_d)), Counter(TOK.findall(cand_d))
    add_d, rem_d = dict(tb_ - ta), dict(ta - tb_)
    if ASSERT_TOKENS:
        tok_ok_d = (add_d == EXPECT_D_ADD and rem_d == EXPECT_D_REM)
    else:
        tok_ok_d = True
    say(f"draft token delta add: {dict(sorted(add_d.items()))}")
    say(f"draft token delta rem: {dict(sorted(rem_d.items()))}")
    say(f"draft token check: {'PASS' if tok_ok_d else 'FAIL'}")

    tta, ttb = Counter(TOK.findall(base_t)), Counter(TOK.findall(cand_t))
    add_t, rem_t = dict(ttb - tta), dict(tta - ttb)
    if ASSERT_TOKENS:
        tok_ok_t = (add_t == EXPECT_T_ADD and rem_t == EXPECT_T_REM)
    else:
        tok_ok_t = True
    say(f"tracker token delta add: {dict(sorted(add_t.items()))}")
    say(f"tracker token delta rem: {dict(sorted(rem_t.items()))}")
    say(f"tracker token check: {'PASS' if tok_ok_t else 'FAIL'}")

    # --- citation gate --------------------------------------------------
    r = run(["python3", "scratch/sv_check_draft_citations.py", str(CAND_D), REG])
    cite_ok = r.returncode == 0
    for line in r.stdout.splitlines()[:6]:
        say(line)
    say(f"citation checker: rc={r.returncode}")

    all_ok = ste_ok and tok_ok_d and tok_ok_t and cite_ok
    say(f"GATES: ste={'pass' if ste_ok else 'fail'} tokens_d={'pass' if tok_ok_d else 'fail'} "
        f"tokens_t={'pass' if tok_ok_t else 'fail'} citations={'pass' if cite_ok else 'fail'}")
    LOG_P.write_text("\n".join(log))

    if write:
        if not all_ok:
            say("--write refused: gates not green")
            sys.exit(1)
        shutil.copyfile(CAND_D, ROOT / DRAFT_REL)
        shutil.copyfile(CAND_T, ROOT / TRACKER_REL)
        say(f"draft written: {DRAFT_REL}")
        say(f"tracker written: {TRACKER_REL}")


if __name__ == "__main__":
    main()
