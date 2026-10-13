#!/usr/bin/env python3
"""Founder calls record pass (author seat, 2026-10-13).

Records three founder calls in the draft tracker. No draft line moves.

  F1/F3  section 2 working notes: the 2.2 retitle holds; any renumber
         rides the structure pass; the structure pass keeps the kite
         turbine and the simulation analysis pipeline distinct.
  F2     section 3: the renumber cascade is ruled (hold); display forms
         (FoS at 1 dp; span and measurement values to the nearest
         millimetre).

Two-state, fail-closed (mirrors au_v028_precone_fold.py):
  - builds from `git show HEAD:<path>` (never from the working file)
  - asserts every anchor exactly once
  - runs the STE gate on base and candidate; the candidate must not
    exceed the baseline total or gain a category
  - runs the numeric token diff against the declared expected delta

Usage:
  python3 scratch/au_founder_calls_record.py          # build, gate, report (no writes)
  python3 scratch/au_founder_calls_record.py --write  # copy the candidate over the tracker
"""
import hashlib
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRACKER_REL = "docs/reporting/draft-tracker.md"
BASE_T = ROOT / "scratch/au_founder_calls_tracker_base.md"
CAND_T = ROOT / "scratch/au_founder_calls_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_founder_calls_record.log"

# Declared before the run: the pass records the calls; the added numerals
# are the section numbers and the 1 dp form. Hyphen-joined dates and
# backticked hashes yield no tokens under the pattern.
EXPECT_T_ADD = {"2.2": 1, "1": 1, "2.4": 1, "2.6": 1}
EXPECT_T_REM = {}

TRACKER_PAIRS = [
    ("T1 founder calls block (working notes)",
     "working form pending the founder decision.\n\n## 3. Open requests",
     "working form pending the founder decision.\n\n"
     "Founder calls (2026-10-13). The 2.2 retitle holds. Any renumber rides the structure pass. "
     "The structure pass also keeps the two senses of \"machine\" apart: the kite turbine, and the simulation analysis pipeline.\n\n"
     "## 3. Open requests"),
    ("T2 cascade ruled and display forms (open requests)",
     "- The section 2.2 renumber cascade: pending the founder call (@user).\n",
     "- The section 2.2 renumber cascade: ruled (2026-10-13, @user). The retitle stands. Sections 2.4 to 2.6 keep their numbers. Any renumber rides the structure pass.\n\n"
     "- Display forms (2026-10-13, @user): the factor of safety prints at 1 dp in the report. Span and measurement values print no finer than the nearest millimetre. Full precision stays internal. The display notes sit with @science-validator.\n"),
]

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")


def run(cmd):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


def lint(path):
    r = run(["python3", "ste-lint.py", "--fail-above", "2.0", str(path)])
    m = re.search(r"total=\s*(\d+)\s+per100w=\s*([\d.]+)", r.stdout)
    total = int(m.group(1)) if m else None
    per100 = float(m.group(2)) if m else None
    cats = Counter()
    for line in r.stdout.splitlines():
        mm = re.match(r"\[HOOK:ste\].*?: ([a-z_()>0-9w]+) x(\d+)", line)
        if mm:
            cats[mm.group(1)] += int(mm.group(2))
    return r.returncode, total, per100, dict(cats), r.stdout


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

    base_t = run(["git", "show", f"HEAD:{TRACKER_REL}"]).stdout
    BASE_T.write_text(base_t)
    say(f"base tracker sha256: {sh256(BASE_T)}")

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
        ("founder block present", cand_t.count("Founder calls (2026-10-13).") == 1),
        ("old cascade hold gone", "pending the founder call (@user)" not in cand_t),
        ("ruled line present", "renumber cascade: ruled" in cand_t),
        ("machine distinction present", 'two senses of "machine" apart' in cand_t),
        ("display rule present", "no finer than the nearest millimetre" in cand_t),
        ("display routing present", "sit with @science-validator" in cand_t),
    ]
    for label, ok in guards:
        say(f"guard {label}: {'ok' if ok else 'FAIL'}")
        if not ok:
            LOG_P.write_text("\n".join(log))
            sys.exit(1)

    CAND_T.write_text(cand_t)
    say(f"candidate tracker sha256: {sh256(CAND_T)}")

    rc_tb, tot_tb, p100_tb, cats_tb, _ = lint(BASE_T)
    rc_tc, tot_tc, p100_tc, cats_tc, _ = lint(CAND_T)
    say(f"STE tracker base: rc={rc_tb} total={tot_tb} per100w={p100_tb} {cats_tb}")
    say(f"STE tracker candidate: rc={rc_tc} total={tot_tc} per100w={p100_tc} {cats_tc}")
    gains_t = {k: v - cats_tb.get(k, 0) for k, v in cats_tc.items() if v > cats_tb.get(k, 0)}
    if gains_t:
        say(f"tracker category gains: {gains_t}")
    ste_ok = (rc_tc == 0 and tot_tb is not None and tot_tc is not None
              and tot_tc <= tot_tb and not gains_t)

    tta, ttb = Counter(TOK.findall(base_t)), Counter(TOK.findall(cand_t))
    add_t, rem_t = dict(ttb - tta), dict(tta - ttb)
    tok_ok_t = (add_t == EXPECT_T_ADD and rem_t == EXPECT_T_REM)
    say(f"tracker token delta add: {add_t}")
    say(f"tracker token delta rem: {rem_t}")
    say(f"tracker token check: {'PASS' if tok_ok_t else 'FAIL'} (declared add {EXPECT_T_ADD} rem {EXPECT_T_REM})")

    all_ok = ste_ok and tok_ok_t
    say(f"GATES: ste={'pass' if ste_ok else 'fail'} tokens_t={'pass' if tok_ok_t else 'fail'}")
    LOG_P.write_text("\n".join(log))

    if write:
        if not all_ok:
            say("--write refused: gates not green")
            sys.exit(1)
        shutil.copyfile(CAND_T, ROOT / TRACKER_REL)
        say(f"tracker written: {TRACKER_REL}")


if __name__ == "__main__":
    main()
