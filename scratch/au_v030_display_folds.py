#!/usr/bin/env python3
"""Draft v0.30 — the display rulings fold (author seat, 2026-10-13).

Folds the science-validator display rulings (read `d7f8871`):
  - the minimum factor of safety reads 15.0 at all five report sites
    (front summary, three in section 3.3, section 5; the abstract held
    the form already);
  - the section 3.3 lift chain reads 20.698 and 304.6 newtons
    (the six-decimal operand retires).

Two-state, fail-closed (mirrors au_v028_precone_fold.py):
  - builds from `git show HEAD:<path>` (never from the working file)
  - asserts every anchor exactly once
  - runs the STE gate on base and candidate per file; the candidate must
    not exceed the baseline total or gain a category
  - runs the numeric token diff against the declared expected delta
  - runs the register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v030_display_folds.py          # build, gate, report (no writes)
  python3 scratch/au_v030_display_folds.py --write  # copy candidates over the repo files
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
BASE_D = ROOT / "scratch/au_v030_draft_base.md"
CAND_D = ROOT / "scratch/au_v030_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v030_tracker_base.md"
CAND_T = ROOT / "scratch/au_v030_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v030_display_folds.log"

# Declared before the run: the display forms move, nothing else. The pin
# moves v0.29 -> v0.30. Hyphen-joined dates and backticked hashes yield no
# tokens under the pattern.
EXPECT_D_ADD = {"15.0": 5, "20.698": 1, "304.6": 1, "30": 1}
EXPECT_D_REM = {"14.972": 5, "20.698468": 1, "304.58": 1, "29": 1}
EXPECT_T_ADD = {"30": 2, "15.0": 1, "20.698": 1, "304.6": 1}
EXPECT_T_REM = {}

DRAFT_PAIRS = [
    ("D1 version pin",
     "Internal engineering report. Draft v0.29. Date 2026-10-13.",
     "Internal engineering report. Draft v0.30. Date 2026-10-13."),
    ("D2 front summary FoS",
     "Its minimum factor of safety is 14.972 (NR-009).",
     "Its minimum factor of safety is 15.0 (NR-009)."),
    ("D3 section 3.3 FoS sentence",
     "Its factor of safety reads\n14.972 (NR-009).",
     "Its factor of safety reads\n15.0 (NR-009)."),
    ("D4 operating table cell",
     "| Minimum factor of safety | 14.972 | NR-009 |",
     "| Minimum factor of safety | 15.0 | NR-009 |"),
    ("D5 gate table cell",
     "| Structural FoS floor | 2.5 | pass, 14.972 minimum |",
     "| Structural FoS floor | 2.5 | pass, 15.0 minimum |"),
    ("D6 section 5 FoS sentence",
     "Its power reads 5.309 kilowatts and its factor of safety 14.972 (NR-008, NR-009).",
     "Its power reads 5.309 kilowatts and its factor of safety 15.0 (NR-008, NR-009)."),
    ("D7 lift chain forms",
     "The vertical load is 1.5 \u00d7 20.698468 \u00d7 9.81 = 304.58 newtons.",
     "The vertical load is 1.5 \u00d7 20.698 \u00d7 9.81 = 304.6 newtons."),
]

TRACKER_PAIRS = [
    ("T1 v0.30 entry",
     "The placement stands open to a room bounce.\n\n## 2. Working notes",
     "The placement stands open to a room bounce.\n\n"
     "v0.30 pass by @author (2026-10-13).\n"
     "This pass folds the display rulings.\n"
     "The minimum factor of safety reads 15.0 at all five report sites.\n"
     "The lift chain reads 20.698 and 304.6 newtons.\n"
     "NR-009 keeps the row value, and the capture hub ring reading keeps its form.\n"
     "No figure moves.\n\n"
     "## 2. Working notes"),
    ("T2 display note closure",
     "The display notes sit with @science-validator.",
     "The ruling updated the display note, and the report sites fold at draft v0.30. @science-validator holds the note."),
]

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")


def run(cmd):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


def lint(path):
    r = run(["python3", "ste-lint.py", "--fail-above", "2.0", str(path)])
    m = re.search(r"total=\s*(\d+)\s+per100w=\s*([\d.]+)", r.stdout)
    total = int(m.group(1)) if m else None
    per100 = float(m.group(2)) if m else None
    wm = re.search(r"words=\s*(\d+)", r.stdout)
    words = int(wm.group(1)) if wm else None
    cats = Counter()
    for line in r.stdout.splitlines():
        mm = re.match(r"\[HOOK:ste\].*?: ([a-z_()>0-9w]+) x(\d+)", line)
        if mm:
            cats[mm.group(1)] += int(mm.group(2))
    return r.returncode, words, total, per100, dict(cats)


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
        ("pin v0.30", "Draft v0.30" in cand_d),
        ("no 14.972 left", "14.972" not in cand_d),
        ("15.0 count 7 (six sites plus the 15.033 neighbor)", cand_d.count("15.0") == 7),
        ("15.033 kept", cand_d.count("15.033") == 1),
        ("no 20.698468 left", "20.698468" not in cand_d),
        ("no 304.58 left", "304.58" not in cand_d),
        ("chain form present", "1.5 \u00d7 20.698 \u00d7 9.81 = 304.6 newtons" in cand_d),
        ("tracker v0.30 entry", "v0.30 pass by @author" in cand_t),
        ("display note closure", "fold at draft v0.30" in cand_t),
        ("old display line gone", "The display notes sit with @science-validator." not in cand_t),
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

    rc_db, w_db, tot_db, p100_db, cats_db = lint(BASE_D)
    rc_dc, w_dc, tot_dc, p100_dc, cats_dc = lint(CAND_D)
    rc_tb, w_tb, tot_tb, p100_tb, cats_tb = lint(BASE_T)
    rc_tc, w_tc, tot_tc, p100_tc, cats_tc = lint(CAND_T)
    say(f"STE draft base: rc={rc_db} words={w_db} total={tot_db} per100w={p100_db} {cats_db}")
    say(f"STE draft candidate: rc={rc_dc} words={w_dc} total={tot_dc} per100w={p100_dc} {cats_dc}")
    say(f"STE tracker base: rc={rc_tb} words={w_tb} total={tot_tb} per100w={p100_tb} {cats_tb}")
    say(f"STE tracker candidate: rc={rc_tc} words={w_tc} total={tot_tc} per100w={p100_tc} {cats_tc}")
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
