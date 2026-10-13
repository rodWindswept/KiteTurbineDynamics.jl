#!/usr/bin/env python3
"""Draft v0.31 — the AU3 wording set, ungated part (author seat, 2026-10-13).

Folds feedback round 2, part AU3, minus the items held for reads:
  - section 2.1: polygon sentence takes the active-rotor form (6.1, 14.5)
  - section 3.3: blade-scale and bank sentences take the two-slot forms
    (6.1, 14.6, 14.7)
  - section 3.3: the era sentence drops the development-history phrase (14.1)
  - section 3.1: the seed lines take the runner-checked policy (14.4)
  - section 4.3: the wind bullet gains the base-case line (14.8)
Held for routes (not folded): the FoS and line-length forms (aero read),
the Daisy sentences (rows), the presumption line (AU4).

Two-state, fail-closed (mirrors au_v030_display_folds.py):
  - builds from `git show HEAD:<path>` (never from the working file)
  - asserts every anchor exactly once
  - runs the STE gate on base and candidate per file; the candidate must
    not exceed the baseline total or gain a category
  - runs the numeric token diff against the declared expected delta
  - runs the register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v031_au3_wording.py          # build, gate, report (no writes)
  python3 scratch/au_v031_au3_wording.py --write  # copy candidates over the repo files
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
BASE_D = ROOT / "scratch/au_v031_draft_base.md"
CAND_D = ROOT / "scratch/au_v031_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v031_tracker_base.md"
CAND_T = ROOT / "scratch/au_v031_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v031_au3_wording.log"

# Declared before the run: the wording forms move; the slot sentences add
# the two slot numerals; the pin moves v0.30 -> v0.31. No value token moves.
EXPECT_D_ADD = {"1": 1, "2": 1, "31": 1}
EXPECT_D_REM = {"30": 1}
EXPECT_T_ADD = {"31": 1}
EXPECT_T_REM = {}

DRAFT_PAIRS = [
    ("D1 version pin",
     "Internal engineering report. Draft v0.30. Date 2026-10-13.",
     "Internal engineering report. Draft v0.31. Date 2026-10-13."),
    ("D2 polygon active-rotor form",
     "The polygon count also equals the blade count. A rotor is a set of blades\non a ring. A pentagonal rotor carries five blades.",
     "For an active rotor, the polygon count equals the blade count. It also\nequals the number of TRPT line attachments around the ring. A rotor is\na set of blades on a ring. A pentagonal rotor carries five blades.\n\nInactive genome slots may hold bank or blade-scale values. They do not\ncreate physical blades unless the rotor count selects them."),
    ("D3 blade-scale slots form",
     "Its blade scales read 0.82 on the active rotor and 0.20 on a rotor\nthat does not exist. The count is one (NR-011).",
     "The winner genome contains two blade-scale slots. Slot 1 reads 0.82 and\ndecodes to the single active rotor. Slot 2 reads 0.20 and stays inactive\nbecause the rotor count is one (NR-011)."),
    ("D4 bank slots form",
     "The bank gene reads 7.088 degrees at ring 6 (NR-017). A second bank\nslot reads 22 degrees, but it reaches no rotor at a count of one\n(NR-011).",
     "The winner genome contains two bank-angle slots. Ring 6 decodes the\nactive main-rotor bank angle as 7.088 degrees (NR-017).\n\nA second bank slot reads 22 degrees. It does not decode to a physical\nrotor at a count of one (NR-011)."),
    ("D5 era sentence form",
     "It stopped early: a screen, not a survey. The\ndevelopment-history chapter carries the trade, tagged by era.",
     "It stopped early: a screen, not a survey.\nThis report covers the wind-authority era campaign and the recorded\ncorrections that shaped it."),
    ("D6 seed policy form",
     "All three islands start from one seed.\nThe recorded common seed genome scores 36.109 kg-equivalent under the campaign objective (NR-006).",
     "Each island starts its population from the same seed genome.\nThe recorded common seed genome scores 36.109 kg-equivalent under the campaign objective (NR-006).\nThe other members of each population draw at random under a fixed seed per island (scripts/run_v13_5kw_masslift.jl)."),
    ("D7 wind base-case line",
     "  Gusts and turbulence do not occur in a scored run.\n  The wind direction stays fixed.",
     "  Gusts and turbulence do not occur in a scored run.\n  The wind direction stays fixed.\n  The scored profile is a base case, not a full weather envelope."),
]

TRACKER_PAIRS = [
    ("T1 v0.31 entry",
     "NR-009 keeps the row value, and the capture hub ring reading keeps its form.\nNo figure moves.\n\n## 2. Working notes",
     "NR-009 keeps the row value, and the capture hub ring reading keeps its form.\nNo figure moves.\n\n"
     "v0.31 pass by @author (2026-10-13).\n"
     "This pass folds the AU3 wording set, the ungated part.\n"
     "The polygon, blade-scale and bank sentences take the active-rotor forms.\n"
     "The seed lines take the runner-checked policy.\n"
     "The era sentence and the wind bullet take their clarity forms.\n"
     "No value moves.\n\n"
     "## 2. Working notes"),
    ("T2 AU3 holds line",
     "The ruling updated the display note, and the report sites fold at draft v0.30. @science-validator holds the note.",
     "The ruling updated the display note, and the report sites fold at draft v0.30. @science-validator holds the note.\n\n"
     "- The AU3 holds: the FoS phrase and the line-length definition wait on the aero read. The Daisy sentences wait on their rows. The presumption line waits on AU4."),
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
        ("pin v0.31", "Draft v0.31" in cand_d and "Draft v0.30" not in cand_d),
        ("polygon form", "For an active rotor, the polygon count equals the blade count." in cand_d),
        ("inactive slots line", "create physical blades unless the rotor count selects them" in cand_d),
        ("blade slot forms", "Slot 1 reads 0.82" in cand_d and "Slot 2 reads 0.20" in cand_d),
        ("bank slot form", "winner genome contains two bank-angle slots" in cand_d),
        ("era form", "wind-authority era campaign" in cand_d),
        ("seed form", "draw at random under a fixed seed per island" in cand_d),
        ("wind base case", "base case, not a full weather envelope" in cand_d),
        ("old forms gone",
         "development-history chapter carries" not in cand_d
         and "a rotor that does not exist" not in cand_d
         and "All three islands start from one seed" not in cand_d
         and "reaches no rotor at a count of one" not in cand_d),
        ("tracker v0.31 entry", "v0.31 pass by @author" in cand_t),
        ("tracker holds line", "The AU3 holds" in cand_t),
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
