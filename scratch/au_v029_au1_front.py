#!/usr/bin/env python3
"""Draft v0.29 — AU1, the front summary block (author seat, 2026-10-13).

Folds feedback round 2, parts 1, 12 and 17: one decision-oriented front
block after the abstract and keywords. It carries the summary, six
findings bullets and the limits paragraph. Placement stands open to a
room bounce.

Two-state, fail-closed (mirrors au_v028_precone_fold.py):
  - builds from `git show HEAD:<path>` (never from the working file)
  - asserts every anchor exactly once
  - runs the STE gate on base and candidate per file; the candidate must
    not exceed the baseline total or gain a category
  - runs the numeric token diff against the declared expected delta
  - runs the register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v029_au1_front.py          # build, gate, report (no writes)
  python3 scratch/au_v029_au1_front.py --write  # copy candidates over the repo files
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
BASE_D = ROOT / "scratch/au_v029_draft_base.md"
CAND_D = ROOT / "scratch/au_v029_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v029_tracker_base.md"
CAND_T = ROOT / "scratch/au_v029_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v029_au1_front.log"

# Declared before the run (dry-run per ktd-ste-gate): the version pin, the
# inserted block's numerals, and the tracker entry. Hyphen-joined dates and
# backticked hashes yield no tokens under the pattern; 930-design yields
# none (trailing hyphen); the bare 3 in "Island 3" counts.
EXPECT_D_ADD = {"29": 1, "930": 2, "5": 2, "508": 1, "422": 1, "5.309": 1,
                "25.698": 1, "14.972": 1, "2.03": 1, "36.109": 1, "27.364": 1, "3": 1}
EXPECT_D_REM = {"28": 1}
EXPECT_T_ADD = {"29": 1}
EXPECT_T_REM = {}

BLOCK = (
    "**Summary for decision.** The project completed a 930-design simulation\n"
    "screen of a 5 kW-class ground-generation rotary kite turbine with a\n"
    "tensile rotary power transmission (NR-001).\n"
    "\n"
    "The screen found a feasible candidate under the model and gates.\n"
    "The key findings follow.\n"
    "\n"
    "- The differential-evolution campaign evaluated 930 candidate designs (NR-001).\n"
    "\n"
    "- Of the 930, 508 designs pass every gate and 422 fail one gate (NR-002).\n"
    "\n"
    "- The campaign winner is the best feasible candidate under the modeled objective and gates.\n"
    "  Its mean power is 5.309 kilowatts and its airborne mass 25.698 kilograms (NR-008, NR-018).\n"
    "  Its minimum factor of safety is 14.972 (NR-009).\n"
    "\n"
    "- All checked TRPT rings and twist segments operate below their failure boundaries at the final operating point (NR-021, NR-022).\n"
    "  The least segment torque margin is 2.03, at S1 (NR-040).\n"
    "\n"
    "- The seed genome scores 36.109 kg-equivalent (NR-006).\n"
    "  Island 3 reaches 27.364 kg-equivalent (NR-005).\n"
    "\n"
    "- The ODE path reproduces every recorded winner field (NR-012).\n"
    "  The rapid path awaits its rope-break gate fix (NR-013).\n"
    "\n"
    "The report shows that a feasible 5 kW-class candidate exists in the\n"
    "searched space under the model and gates.\n"
    "\n"
    "It does not show flight readiness, a global optimum, or full structural\n"
    "safety. Blade integrity, lifter modulation, launch and recovery, and\n"
    "atmospheric realism remain open work items."
)

DRAFT_PAIRS = [
    ("D1 version pin",
     "Internal engineering report. Draft v0.28. Date 2026-10-13.",
     "Internal engineering report. Draft v0.29. Date 2026-10-13."),
    ("D2 AU1 block insert",
     "simulation, design search, factor of safety.\n\n## 1 Introduction",
     "simulation, design search, factor of safety.\n\n" + BLOCK + "\n\n## 1 Introduction"),
]

TRACKER_PAIRS = [
    ("T1 v0.29 entry",
     "v0.28 pass by @author (2026-10-13).\n"
     "This pass folds the AeroDyn pre-cone gloss at section 2.1.\n"
     "The founder return note 10 closes on the aero read (`2db50f9`).\n"
     "No value, unit or row moves.\n\n## 2. Working notes",
     "v0.28 pass by @author (2026-10-13).\n"
     "This pass folds the AeroDyn pre-cone gloss at section 2.1.\n"
     "The founder return note 10 closes on the aero read (`2db50f9`).\n"
     "No value, unit or row moves.\n"
     "\n"
     "v0.29 pass by @author (2026-10-13).\n"
     "This pass folds AU1 from the feedback plan: the summary for decision block lands after the abstract and keywords.\n"
     "The block carries the summary, six findings bullets and the limits paragraph.\n"
     "The placement stands open to a room bounce.\n"
     "\n## 2. Working notes"),
]

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")


def run(cmd):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


def lint(path):
    r = run(["python3", "ste-lint.py", "--fail-above", "2.0", str(path)])
    m = re.search(r"total=\s*(\d+)\s+per100w=\s*([\d.]+)", r.stdout)
    wm = re.search(r"words=\s*(\d+)", r.stdout)
    total = int(m.group(1)) if m else None
    words = int(wm.group(1)) if wm else None
    cats = Counter()
    for line in r.stdout.splitlines():
        mm = re.match(r"\[HOOK:ste\].*?: ([a-z_()>0-9w]+) x(\d+)", line)
        if mm:
            cats[mm.group(1)] += int(mm.group(2))
    return r.returncode, total, words, dict(cats), r.stdout


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

    cand_d = base_d
    for name, anchor, repl in DRAFT_PAIRS:
        c = cand_d.count(anchor)
        if c != 1:
            say(f"ANCHOR FAIL {name}: count={c}")
            LOG_P.write_text("\n".join(log))
            sys.exit(1)
        cand_d = cand_d.replace(anchor, repl, 1)
        say(f"ok {name}")

    cand_t = base_t
    for name, anchor, repl in TRACKER_PAIRS:
        c = cand_t.count(anchor)
        if c != 1:
            say(f"ANCHOR FAIL {name}: count={c}")
            LOG_P.write_text("\n".join(log))
            sys.exit(1)
        cand_t = cand_t.replace(anchor, repl, 1)
        say(f"ok {name}")

    guards = [
        ("old pin gone", "Draft v0.28" not in cand_d),
        ("new pin present", "Draft v0.29" in cand_d),
        ("decision block present once", cand_d.count("**Summary for decision.**") == 1),
        ("block before intro", cand_d.index("**Summary for decision.**") < cand_d.index("## 1 Introduction")),
        ("block after keywords", cand_d.index("**Keywords.**") < cand_d.index("**Summary for decision.**")),
        ("v0.29 entry present", "v0.29 pass by @author" in cand_t),
        ("tracker notes section intact", "## 2. Working notes" in cand_t),
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

    rc_db, tot_db, w_db, cats_db, _ = lint(BASE_D)
    rc_dc, tot_dc, w_dc, cats_dc, _ = lint(CAND_D)
    rc_tb, tot_tb, w_tb, cats_tb, _ = lint(BASE_T)
    rc_tc, tot_tc, w_tc, cats_tc, _ = lint(CAND_T)
    say(f"STE draft base: rc={rc_db} words={w_db} total={tot_db} {cats_db}")
    say(f"STE draft candidate: rc={rc_dc} words={w_dc} total={tot_dc} {cats_dc}")
    say(f"STE tracker base: rc={rc_tb} words={w_tb} total={tot_tb} {cats_tb}")
    say(f"STE tracker candidate: rc={rc_tc} words={w_tc} total={tot_tc} {cats_tc}")
    gains_d = {k: v - cats_db.get(k, 0) for k, v in cats_dc.items() if v > cats_db.get(k, 0)}
    gains_t = {k: v - cats_tb.get(k, 0) for k, v in cats_tc.items() if v > cats_tb.get(k, 0)}
    if gains_d:
        say(f"draft category gains: {gains_d}")
    if gains_t:
        say(f"tracker category gains: {gains_t}")
    ste_ok = (rc_dc == 0 and rc_tc == 0 and tot_db is not None and tot_dc is not None
              and tot_tb is not None and tot_tc is not None
              and tot_dc <= tot_db and tot_tc <= tot_tb and not gains_d and not gains_t)

    ta, tb_ = Counter(TOK.findall(base_d)), Counter(TOK.findall(cand_d))
    add_d, rem_d = dict(tb_ - ta), dict(ta - tb_)
    tok_ok_d = (add_d == EXPECT_D_ADD and rem_d == EXPECT_D_REM)
    say(f"draft token delta add: {add_d}")
    say(f"draft token delta rem: {rem_d}")
    say(f"draft token check: {'PASS' if tok_ok_d else 'FAIL'} (declared add {EXPECT_D_ADD} rem {EXPECT_D_REM})")

    tta, ttb = Counter(TOK.findall(base_t)), Counter(TOK.findall(cand_t))
    add_t, rem_t = dict(ttb - tta), dict(tta - ttb)
    tok_ok_t = (add_t == EXPECT_T_ADD and rem_t == EXPECT_T_REM)
    say(f"tracker token delta add: {add_t}")
    say(f"tracker token delta rem: {rem_t}")
    say(f"tracker token check: {'PASS' if tok_ok_t else 'FAIL'} (declared add {EXPECT_T_ADD} rem {EXPECT_T_REM})")

    r = run(["python3", "scratch/sv_check_draft_citations.py", str(CAND_D), REG])
    cite_ok = (r.returncode == 0)
    say(f"citation checker: rc={r.returncode}")
    say(r.stdout.strip())
    if r.stderr.strip():
        say(r.stderr.strip())

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
