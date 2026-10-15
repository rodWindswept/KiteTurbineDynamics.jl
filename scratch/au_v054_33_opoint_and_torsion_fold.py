#!/usr/bin/env python3
"""Draft v0.54 — the operating point completes and the torsion clause folds
(author seat, 2026-10-15).

Folds the two keyed items the room delivered this pass:

  (a) the operating-point completion (Harris review item 2.1, the
      "signed but unprinted" set). The words landed at the
      science-validator seat 2026-10-15 (`2142d43`): the NR-031/032
      source cells take the corrected basis — the AeroDyn v5.0.0 BEM
      table, a computation — and the fold carries it.
  (b) the torsion clause and the floor sentence (Harris review items
      1.3 and 2.3). NR-052 and NR-053 signed at `2142d43`; the
      torsion sentence text is ruled in the register's reading rules
      ("the collapse factor of safety >= 1.5, the twist within the
      crossing limit, and the 2.5 gate does not cover torsion today").

Text-only; no value moves. The set folds as: the version pin; three
operating-table rows; one paragraph (swept-area set, air density, the
rotor Cp with its basis, the Betz check); one paragraph (the gate set
per class, the torsion criteria, the realisability floor); the tracker
entry.

  D1  version pin v0.53 -> v0.54 (date held at 2026-10-15)
  D2  the operating table takes three rows (wind, ring ratio, tip ratio)
  D3  the operating paragraph takes the area set, density, Cp, Betz
  D4  the gate block takes the per-class sentence and the floor (NR-052/053)
  T1  tracker v0.54 entry

Two-state, fail-closed (mirrors au_v053_41_fixed_defect_fold.py):
  - builds from `git show HEAD:<path>` (never the working file)
  - asserts every anchor exactly once
  - reconstruction: the candidate equals base plus the declared edits,
    and reverses exactly
  - changed-line census: the difflib opcode list must match exactly
  - STE: rc=0; no category gains; totals held
  - declared token diff must match exactly
  - register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v054_33_opoint_and_torsion_fold.py          # build, gate, report
  python3 scratch/au_v054_33_opoint_and_torsion_fold.py --write  # copy candidates over
"""
import difflib
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
BASE_D = ROOT / "scratch/au_v054_33_opoint_draft_base.md"
CAND_D = ROOT / "scratch/au_v054_33_opoint_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v054_33_opoint_tracker_base.md"
CAND_T = ROOT / "scratch/au_v054_33_opoint_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v054_33_opoint_and_torsion_fold.log"

# Declared before the run. The pin moves (53 out, 54 in) on the draft.
# The tracker adds its v0.54 entry (54 and the section token 3.3). The
# new cites add no token; the new values add their own tokens.
ASSERT_TOKENS = True
EXPECT_D_ADD = {
    "0.0": 1,
    "0.2258": 1,
    "0.2944": 1,
    "1.225": 1,
    "1.5": 1,
    "11.01": 1,
    "19.1304": 1,
    "2.5": 2,
    "27.75": 1,
    "39.4912": 1,
    "45.9733": 1,
    "5.566": 1,
    "54": 1,
    "6.8415": 1,
    "72.25": 1,
    "9.41": 1,
}
EXPECT_D_REM = {"53": 1}
EXPECT_T_ADD = {"3.3": 1, "54": 1}
EXPECT_T_REM = {}

# Expected difflib opcode list, base lines -> candidate lines (baked from
# the dry run; the dry run prints the live list when it disagrees).
EXPECT_OPCODES = [
    ("equal", 0, 2, 0, 2),
    ("replace", 2, 3, 2, 3),
    ("equal", 3, 524, 3, 524),
    ("insert", 524, 524, 524, 527),
    ("equal", 524, 533, 527, 536),
    ("insert", 533, 533, 536, 547),
    ("equal", 533, 544, 547, 558),
    ("insert", 544, 544, 558, 567),
    ("equal", 544, 1021, 567, 1044),
]

D1 = (
    "Internal engineering report. Draft v0.53. Date 2026-10-15.",
    "Internal engineering report. Draft v0.54. Date 2026-10-15.",
)

D2 = (
    "| Lift-line tension | 324.1 N | NR-010 |",
    "| Lift-line tension | 324.1 N | NR-010 |\n"
    "| Reference wind speed | 11.01 m/s at 9.41 m | NR-008, NR-032 |\n"
    "| Ring speed ratio | 5.566 | NR-031 |\n"
    "| Tip-speed ratio | 6.8415 | NR-032 |",
)

D3 = (
    "Its airborne mass reads 25.698 kilograms (NR-018).\n"
    "\n"
    "The winner clears each checked gate.",
    "Its airborne mass reads 25.698 kilograms (NR-018).\n"
    "\n"
    "The swept area reads 45.9733 square metres raw and 39.4912 square\n"
    "metres on the wind-normal basis (NR-033). The air density reads\n"
    "1.225 kilograms per cubic metre (NR-034).\n"
    "\n"
    "The rotor Cp reads from the AeroDyn v5.0.0 blade element momentum\n"
    "(BEM) table: 0.2944 at the ring speed ratio, and 0.2258 at the\n"
    "tip-speed ratio (NR-031, NR-032).\n"
    "\n"
    "The Betz ceiling reads 19.1304 kW, and the winner delivers 27.75 per\n"
    "cent of it (NR-034).\n"
    "\n"
    "The winner clears each checked gate.",
)

D4 = (
    "| Rope break | none on the window | pass on the cold path | the warm path rejects healthy winners | NR-012, NR-013 |\n"
    "\n"
    "A lifter kite holds the machine aloft.",
    "| Rope break | none on the window | pass on the cold path | the warm path rejects healthy winners | NR-012, NR-013 |\n"
    "\n"
    "The gate set reads per class. The structural members and the lines\n"
    "hold a factor of safety of 2.5 or higher (NR-015).\n"
    "\n"
    "Torsion keeps its own criteria. The collapse factor of safety reads\n"
    "1.5 or higher, and the twist stays within the crossing limit (NR-052).\n"
    "\n"
    "The realisability floor reads 72.25 degrees (NR-053). As run, the\n"
    "2.5 gate does not cover torsion (NR-052).\n"
    "\n"
    "A lifter kite holds the machine aloft.",
)

T1_OLD = (
    "No value moves, and no figure byte moves.\n"
    "\n"
    "## 2. Working notes"
)
T1_NEW = (
    "No value moves, and no figure byte moves.\n"
    "\n"
    "v0.54 pass by @author (2026-10-15).\n"
    "This pass completes the winner operating point at section 3.3 and prints the torsion clause.\n"
    "The operating table takes the reference wind speed, the ring speed ratio and the tip-speed ratio. The paragraph takes the swept-area set, the air density, the rotor Cp and the Betz check (NR-031 to NR-034).\n"
    "The gate set prints per class, with the torsion criteria and the realisability floor (NR-052, NR-053).\n"
    "No value moves, and no figure byte moves.\n"
    "\n"
    "## 2. Working notes"
)

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")

PAIRS = [
    ("D1 version pin", D1),
    ("D2 operating-table rows", D2),
    ("D3 operating paragraph", D3),
    ("D4 gate block", D4),
]


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


def region(text, start, end):
    i = text.index(start)
    j = text.index(end, i)
    return text[i:j]


def opcodes(base, cand):
    b, c = base.splitlines(), cand.splitlines()
    return difflib.SequenceMatcher(a=b, b=c, autojunk=False).get_opcodes()


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

    # --- build the candidates -------------------------------------------
    cand_d = base_d
    for name, (old, new) in PAIRS:
        c = cand_d.count(old)
        if c != 1:
            say(f"ANCHOR FAIL {name}: count={c}")
            LOG_P.write_text("\n".join(log))
            sys.exit(1)
        cand_d = cand_d.replace(old, new, 1)
        say(f"ok {name}")

    c = base_t.count(T1_OLD)
    if c != 1:
        say(f"ANCHOR FAIL T1 tracker entry: count={c}")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    cand_t = base_t.replace(T1_OLD, T1_NEW, 1)
    say("ok T1 tracker entry")

    # --- candidates written to scratch up front (bake runs read these) ---
    CAND_D.write_text(cand_d)
    CAND_T.write_text(cand_t)
    say(f"candidate draft sha256: {sh256(CAND_D)}")
    say(f"candidate tracker sha256: {sh256(CAND_T)}")

    # --- live diagnostics (printed before the guards, so a bake run shows
    # --- every value the expectations need) ------------------------------
    ops = opcodes(base_d, cand_d)
    b_lines, c_lines = base_d.splitlines(), cand_d.splitlines()
    say(f"line count: base {len(b_lines)} -> candidate {len(c_lines)}")
    say(f"draft opcodes: {ops}")

    def tokdiff(base, cand):
        a, b = Counter(TOK.findall(base)), Counter(TOK.findall(cand))
        return dict(b - a), dict(a - b)

    add_d, rem_d = tokdiff(base_d, cand_d)
    add_t, rem_t = tokdiff(base_t, cand_t)
    say(f"draft token delta add: {dict(sorted(add_d.items()))}")
    say(f"draft token delta rem: {dict(sorted(rem_d.items()))}")
    say(f"tracker token delta add: {dict(sorted(add_t.items()))}")
    say(f"tracker token delta rem: {dict(sorted(rem_t.items()))}")
    say(f"cite count: base {base_d.count('NR-')} -> candidate {cand_d.count('NR-')}")

    rc_db, w_db, tot_db, cats_db = lint(BASE_D)
    rc_dc, w_dc, tot_dc, cats_dc = lint(CAND_D)
    rc_tb, w_tb, tot_tb, cats_tb = lint(BASE_T)
    rc_tc, w_tc, tot_tc, cats_tc = lint(CAND_T)
    say(f"STE draft base: rc={rc_db} words={w_db} total={tot_db} {cats_db}")
    say(f"STE draft candidate: rc={rc_dc} words={w_dc} total={tot_dc} {cats_dc}")
    say(f"STE tracker base: rc={rc_tb} words={w_tb} total={tot_tb} {cats_tb}")
    say(f"STE tracker candidate: rc={rc_tc} words={w_tc} total={tot_tc} {cats_tc}")

    # --- guards ----------------------------------------------------------
    recon = base_d
    for _, (old, new) in PAIRS:
        recon = recon.replace(old, new, 1)
    rev = cand_d
    for _, (old, new) in reversed(PAIRS):
        rev = rev.replace(new, old, 1)

    guards = [
        ("pin: v0.54 dated 2026-10-15",
         "Draft v0.54" in cand_d and "Draft v0.53" not in cand_d and "Date 2026-10-15" in cand_d),
        ("reconstruction: candidate == base plus declared edits", cand_d == recon),
        ("reverse: base == candidate minus declared edits", rev == base_d),
        ("D2 lands once, base row kept once", cand_d.count(D2[1]) == 1 and cand_d.count(D2[0]) == 1),
        ("D3 lands once, old gone", cand_d.count(D3[1]) == 1 and cand_d.count(D3[0]) == 0),
        ("D4 lands once, old gone", cand_d.count(D4[1]) == 1 and cand_d.count(D4[0]) == 0),
        ("line count exact", len(c_lines) == (len(b_lines) + 23)),
        ("opcodes exact", EXPECT_OPCODES is not None and ops == EXPECT_OPCODES),
        ("new form count: wind row == 1",
         cand_d.count("| Reference wind speed | 11.01 m/s at 9.41 m | NR-008, NR-032 |") == 1),
        ("new form count: ring ratio row == 1",
         cand_d.count("| Ring speed ratio | 5.566 | NR-031 |") == 1),
        ("new form count: tip ratio row == 1",
         cand_d.count("| Tip-speed ratio | 6.8415 | NR-032 |") == 1),
        ("new form count: area sentence == 1",
         cand_d.count("The swept area reads 45.9733 square metres raw") == 1),
        ("new form count: Betz pair == 1",
         cand_d.count("The Betz ceiling reads 19.1304 kW, and the winner delivers 27.75 per\ncent of it (NR-034).") == 1),
        ("new form count: torsion pair == 1",
         cand_d.count("Torsion keeps its own criteria. The collapse factor of safety reads\n1.5 or higher, and the twist stays within the crossing limit (NR-052).") == 1),
        ("new form count: floor close == 1",
         cand_d.count("The realisability floor reads 72.25 degrees (NR-053).") == 1),
        ("new form count: torsion close == 1",
         cand_d.count("2.5 gate does not cover torsion (NR-052).") == 1),
        ("new form count: 'Betz' reads once (base 0)",
         cand_d.count("Betz") == 1),
        ("value holds: 22 degrees",
         cand_d.count("22 degrees") == base_d.count("22 degrees")),
        ("value holds: 25.698",
         cand_d.count("25.698") == base_d.count("25.698")),
        ("value holds: NR-049",
         cand_d.count("NR-049") == base_d.count("NR-049")),
        ("value holds: NR-050",
         cand_d.count("NR-050") == base_d.count("NR-050")),
        ("hold: study-is-simulation-only",
         cand_d.count("The study is simulation-only.") == base_d.count("The study is simulation-only.") == 1),
        ("hold: never-allows-breaks close",
         cand_d.count("The fix removes false rejections. It never allows breaks.") ==
         base_d.count("The fix removes false rejections. It never allows breaks.") == 1),
        ("hold: gate table rows unchanged",
         cand_d.count("| Torsional capacity | capacity/demand | least margin 2.03 at S1 | +102.9 per cent above unity, 2.03 times | NR-040 |") == 1),
        ("region: 3.3 head to the operating table unchanged",
         region(cand_d, "### 3.3 The winner", "| Mean power, measurement window |") ==
         region(base_d, "### 3.3 The winner", "| Mean power, measurement window |")),
        ("region: swing block to the mass line unchanged",
         region(cand_d, "\n\nIts window swing reads 0.029 kW", "Its airborne mass reads 25.698 kilograms (NR-018).") ==
         region(base_d, "\n\nIts window swing reads 0.029 kW", "Its airborne mass reads 25.698 kilograms (NR-018).")),
        ("region: gate table to rope row unchanged",
         region(cand_d, "| Power floor | 5.0 kW | pass, P_end 5.314 kW.", "| Rope break | none on the window |") ==
         region(base_d, "| Power floor | 5.0 kW | pass, P_end 5.314 kW.", "| Rope break | none on the window |")),
        ("region: lifter block to 4.1 unchanged",
         region(cand_d, "A lifter kite holds the machine aloft.", "### 4.1 Evaluation fidelity") ==
         region(base_d, "A lifter kite holds the machine aloft.", "### 4.1 Evaluation fidelity")),
        ("region: 1 to 3.3 unchanged",
         region(cand_d, "## 1 Introduction", "### 3.3 The winner") ==
         region(base_d, "## 1 Introduction", "### 3.3 The winner")),
        ("region: 4.1 to 6 Nomenclature unchanged",
         region(cand_d, "### 4.1 Evaluation fidelity", "## 6 Nomenclature") ==
         region(base_d, "### 4.1 Evaluation fidelity", "## 6 Nomenclature")),
        ("region: 6 to Document control unchanged",
         region(cand_d, "## 6 Nomenclature", "## Document control") ==
         region(base_d, "## 6 Nomenclature", "## Document control")),
        ("region: document control to claims appendix unchanged",
         region(cand_d, "## Document control", "## Appendix: Claims and evidence") ==
         region(base_d, "## Document control", "## Appendix: Claims and evidence")),
        ("region: claims appendix unchanged",
         region(cand_d, "## Appendix: Claims and evidence", "## Appendix: Figure provenance") ==
         region(base_d, "## Appendix: Claims and evidence", "## Appendix: Figure provenance")),
        ("tracker v0.54 entry", "v0.54 pass by @author" in cand_t),
        ("tracker history held",
         "v0.53 pass by @author" in cand_t and "v0.52 pass by @author" in cand_t
         and "## 2. Working notes" in cand_t),
        ("tracker reconstruction exact", cand_t == base_t.replace(T1_OLD, T1_NEW, 1)),
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

    # --- STE gates --------------------------------------------------------
    rc_db, w_db, tot_db, cats_db = lint(BASE_D)
    rc_dc, w_dc, tot_dc, cats_dc = lint(CAND_D)
    rc_tb, w_tb, tot_tb, cats_tb = lint(BASE_T)
    rc_tc, w_tc, tot_tc, cats_tc = lint(CAND_T)
    say(f"STE draft base: rc={rc_db} words={w_db} total={tot_db} {cats_db}")
    say(f"STE draft candidate: rc={rc_dc} words={w_dc} total={tot_dc} {cats_dc}")
    say(f"STE tracker base: rc={rc_tb} words={w_tb} total={tot_tb} {cats_tb}")
    say(f"STE tracker candidate: rc={rc_tc} words={w_tc} total={tot_tc} {cats_tc}")

    def gains(cb, cc):
        return {k: v - cb.get(k, 0) for k, v in cc.items()
                if v > cb.get(k, 0) and not k.startswith("_")}

    gained = {"draft": gains(cats_db, cats_dc), "tracker": gains(cats_tb, cats_tc)}
    for name, g in gained.items():
        if g:
            say(f"{name} category gains: {g}")
    ste_ok = (rc_dc == 0 and rc_tc == 0
              and None not in (tot_db, tot_dc, tot_tb, tot_tc)
              and tot_dc == tot_db and tot_tc == tot_tb
              and not gains(cats_db, cats_dc) and not gains(cats_tb, cats_tc))

    # --- token diff -------------------------------------------------------
    add_d, rem_d = tokdiff(base_d, cand_d)
    add_t, rem_t = tokdiff(base_t, cand_t)
    tok_ok = True
    for name, add, rem, ea, er in [
        ("draft", add_d, rem_d, EXPECT_D_ADD, EXPECT_D_REM),
        ("tracker", add_t, rem_t, EXPECT_T_ADD, EXPECT_T_REM),
    ]:
        ok = (add == ea and rem == er) if ASSERT_TOKENS else True
        tok_ok = tok_ok and ok
        say(f"{name} token delta add: {dict(sorted(add.items()))}")
        say(f"{name} token delta rem: {dict(sorted(rem.items()))}")
        say(f"{name} token check: {'PASS' if ok else 'FAIL'}")

    # --- citation gate ----------------------------------------------------
    r = run(["python3", "scratch/sv_check_draft_citations.py", str(CAND_D), REG])
    cite_ok = r.returncode == 0
    for line in r.stdout.splitlines()[:6]:
        say(line)
    say(f"citation checker: rc={r.returncode}")

    all_ok = ste_ok and tok_ok and cite_ok
    say(f"GATES: ste={'pass' if ste_ok else 'fail'} tokens={'pass' if tok_ok else 'fail'} "
        f"citations={'pass' if cite_ok else 'fail'}")
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
