#!/usr/bin/env python3
"""Draft v0.28 — the AeroDyn pre-cone gloss fold (author seat, 2026-10-13).

Folds the AeroDyn pre-cone equivalence (founder return note 10) into
section 2.1 and closes the tracker open item. The read sits at `2db50f9`
(room response: aero-validator-2026-10-13-precone-equivalence-read.md).

Two-state, fail-closed (mirrors au_docx_v027_fold.py):
  - builds from `git show HEAD:<path>` (never from the working file)
  - asserts every anchor exactly once
  - runs the STE gate on base and candidate per file; the candidate must
    not exceed the baseline total or gain a category
  - runs the numeric token diff against the declared expected delta
  - runs the register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v028_precone_fold.py          # build, gate, report (no writes)
  python3 scratch/au_v028_precone_fold.py --write  # copy candidates over the repo files
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
BASE_D = ROOT / "scratch/au_v028_draft_base.md"
CAND_D = ROOT / "scratch/au_v028_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v028_tracker_base.md"
CAND_T = ROOT / "scratch/au_v028_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v028_precone_fold.log"

# Declared before the run (dry-run per ktd-ste-gate): the draft diff is the
# version pin only; the tracker adds the v0.28 entry and the closure line.
# Hyphen-joined dates and backticked hashes yield no tokens under the pattern.
EXPECT_D_ADD = {"28": 1}
EXPECT_D_REM = {"27": 1}
EXPECT_T_ADD = {"28": 2, "10": 1, "2.1": 1}
EXPECT_T_REM = {}

DRAFT_PAIRS = [
    ("D1 version pin",
     "Internal engineering report. Draft v0.27. Date 2026-10-13.",
     "Internal engineering report. Draft v0.28. Date 2026-10-13."),
    ("D2 pre-cone gloss",
     "Bank is the blade angle away from the ring plane about its chord axis at\n"
     "the ring. Blade scale sets the blade size. The scale multiplies the\n"
     "blade span and chord, and the blade mass follows the span cubed.",
     "Bank is the blade angle away from the ring plane about its chord axis at\n"
     "the ring. The equivalent term in AeroDyn is pre-cone.\n"
     "\n"
     "Blade scale sets the blade size. The scale multiplies the blade span\n"
     "and chord, and the blade mass follows the span cubed."),
]

TRACKER_PAIRS = [
    ("T1 v0.28 entry",
     "The downstream numbering holds pending the founder call, and the block diagram takes its figure-map row 19 pointer.\n\n## 2. Working notes",
     "The downstream numbering holds pending the founder call, and the block diagram takes its figure-map row 19 pointer.\n\n"
     "v0.28 pass by @author (2026-10-13).\n"
     "This pass folds the AeroDyn pre-cone gloss at section 2.1.\n"
     "The founder return note 10 closes on the aero read (`2db50f9`).\n"
     "No value, unit or row moves.\n"
     "\n## 2. Working notes"),
    ("T2 note-10 item closes",
     "- The AeroDyn pre-cone equivalence for \"bank\": awaits the\n@aero-validator read (founder return note 10).",
     "- The AeroDyn pre-cone equivalence for \"bank\": landed (founder return\nnote 10, aero read `2db50f9`). The gloss folds at draft v0.28."),
]

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")


def run(cmd):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


def lint(path):
    r = run(["python3", "ste-lint.py", "--fail-above", "2.0", str(path)])
    m = re.search(r"total=\s*(\d+)\s+per100w=\s*([\d.]+)", r.stdout)
    total = int(m.group(1)) if m else None
    cats = Counter()
    for line in r.stdout.splitlines():
        mm = re.match(r"\[HOOK:ste\].*?: ([a-z_()>0-9w]+) x(\d+)", line)
        if mm:
            cats[mm.group(1)] += int(mm.group(2))
    return r.returncode, total, dict(cats), r.stdout


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
        ("old pin gone", "Draft v0.27" not in cand_d),
        ("new pin present", "Draft v0.28" in cand_d),
        ("gloss present once", cand_d.count("The equivalent term in AeroDyn is pre-cone.") == 1),
        ("single AeroDyn mention", cand_d.count("AeroDyn") == 1),
        ("old tracker hold gone", "awaits the\n@aero-validator read" not in cand_t),
        ("v0.28 entry present", "v0.28 pass by @author" in cand_t),
        ("closure line present", "landed (founder return" in cand_t),
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

    rc_db, tot_db, cats_db, _ = lint(BASE_D)
    rc_dc, tot_dc, cats_dc, _ = lint(CAND_D)
    rc_tb, tot_tb, cats_tb, _ = lint(BASE_T)
    rc_tc, tot_tc, cats_tc, _ = lint(CAND_T)
    say(f"STE draft base: rc={rc_db} total={tot_db} {cats_db}")
    say(f"STE draft candidate: rc={rc_dc} total={tot_dc} {cats_dc}")
    say(f"STE tracker base: rc={rc_tb} total={tot_tb} {cats_tb}")
    say(f"STE tracker candidate: rc={rc_tc} total={tot_tc} {cats_tc}")
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
