#!/usr/bin/env python3
"""Draft v0.55 — the reject split and the item-2.1 environment set fold
(author seat, 2026-10-15).

Folds the two keyed items the room signed this pass:

  (a) the status-mix split (NR-055, signed at a51e9d9 under the founder's
      "Print" ruling). The plain reject class (301) prints as three
      subgroups: 96 below the 5 kW power floor, 4 on factor of safety,
      201 with the cause not logged. The split folds at sections 3.1
      and 5.
  (b) the item-2.1 environment set (NR-056 to NR-058, signed at
      a51e9d9; read at the aero seat at c08f3bd). The section 3.3 table
      takes two environment rows — the shear law and the shaft
      elevation — and the swing sentence takes its steady-wind basis
      note.

Text-only; no value moves. The set folds as: the version pin; one
split block at section 3.1; one split block at section 5; two table
rows at section 3.3; one basis note line; the tracker entry.

  D1  version pin v0.54 -> v0.55 (date held at 2026-10-15)
  D2  the reject split prints at section 3.1 (NR-055)
  D3  the reject split prints at section 5 (NR-055)
  D4  the section 3.3 table takes the shear-law and shaft-elevation rows
  D5  the swing sentence takes its steady-wind basis note (NR-058)
  T1  tracker v0.55 entry

Two-state, fail-closed (mirrors au_v054_33_opoint_and_torsion_fold.py):
  - builds from `git show HEAD:<path>` (never the working file)
  - asserts every anchor exactly once
  - reconstruction: the candidate equals base plus the declared edits,
    and reverses exactly
  - changed-line census: the difflib opcode list must match exactly
  - STE: rc=0; no category gains; totals held
  - declared token diff must match exactly
  - register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v055_split_and_env_fold.py          # build, gate, report
  python3 scratch/au_v055_split_and_env_fold.py --write  # copy candidates over
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
BASE_D = ROOT / "scratch/au_v055_split_draft_base.md"
CAND_D = ROOT / "scratch/au_v055_split_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v055_split_tracker_base.md"
CAND_T = ROOT / "scratch/au_v055_split_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v055_split_and_env_fold.log"

# Declared before the run. The pin moves (54 out, 55 in) on the draft.
# The tracker adds its v0.55 entry (55, the section tokens 3.1 and 5 and
# the item token 2.1). The new cites add no token; the new values add
# their own tokens (96 twice, 201 twice, 301 once, the 5 kW floor four
# times, 2.5 twice, the exponent pair 1/7, the Daisy pair 10.0 and 4.8,
# the shaft 30 and hub 9.4000).
ASSERT_TOKENS = True
EXPECT_D_ADD = {
    "1": 1,
    "10.0": 1,
    "2.5": 2,
    "201": 2,
    "30": 1,
    "301": 1,
    "4.8": 1,
    "5": 4,
    "55": 1,
    "7": 1,
    "9.4000": 1,
    "96": 2,
}
EXPECT_D_REM = {"54": 1}
# "item-2.1" yields the token "1" alone: the "2" sits hyphen-flanked, so
# the lookbehind kills the "2.1" run and only the "1" survives. Baked.
EXPECT_T_ADD = {"1": 1, "3.1": 1, "5": 1, "55": 1}
EXPECT_T_REM = {}

# Expected difflib opcode list, base lines -> candidate lines (baked from
# the dry run; the dry run prints the live list when it disagrees).
EXPECT_OPCODES = [
    ("equal", 0, 2, 0, 2),
    ("replace", 2, 3, 2, 3),
    ("equal", 3, 475, 3, 475),
    ("insert", 475, 475, 475, 481),
    ("equal", 475, 525, 481, 531),
    ("insert", 525, 525, 531, 533),
    ("equal", 525, 529, 533, 537),
    ("insert", 529, 529, 537, 538),
    ("equal", 529, 907, 538, 916),
    ("insert", 907, 907, 916, 922),
    ("equal", 907, 1044, 922, 1059),
]

D1 = (
    "Internal engineering report. Draft v0.54. Date 2026-10-15.",
    "Internal engineering report. Draft v0.55. Date 2026-10-15.",
)

D2 = (
    "ok, 301 reject, 110 clearance_reject and 11 reject_twist (NR-002).\n"
    "Each island starts its population from the same seed genome.",
    "ok, 301 reject, 110 clearance_reject and 11 reject_twist (NR-002).\n"
    "\n"
    "The reject class splits three ways (NR-055).\n"
    "96 ran below the 5 kW power floor.\n"
    "Four ran at or above 5 kW with a factor of safety below 2.5.\n"
    "The cause is not logged for the remaining 201.\n"
    "\n"
    "Each island starts its population from the same seed genome.",
)

D3 = (
    "The search found 508 feasible candidates in the searched space (NR-002).\n"
    "The best performing one had a mean power of 5.309 kW.",
    "The search found 508 feasible candidates in the searched space (NR-002).\n"
    "\n"
    "The 301 rejects split three ways (NR-055).\n"
    "96 ran below the 5 kW power floor.\n"
    "Four ran at or above 5 kW with a factor of safety below 2.5.\n"
    "The cause is not logged for the remaining 201.\n"
    "\n"
    "The best performing one had a mean power of 5.309 kW.",
)

D4 = (
    "| Reference wind speed | 11.01 m/s at 9.41 m | NR-008, NR-032 |\n"
    "| Ring speed ratio | 5.566 | NR-031 |",
    "| Reference wind speed | 11.01 m/s at 9.41 m | NR-008, NR-032 |\n"
    "| Shear law | Hellmann power law, exponent 1/7, from the measured Daisy pair 10.0 m/s at 4.8 m | NR-056 |\n"
    "| Shaft elevation | 30 deg, hub at 9.4000 m | NR-057 |\n"
    "| Ring speed ratio | 5.566 | NR-031 |",
)

D5 = (
    "Its window swing reads 0.029 kW on 5.309 kW, half a per cent (NR-014).\n"
    "The machine held a steady operating point through the measurement window.",
    "Its window swing reads 0.029 kW on 5.309 kW, half a per cent (NR-014).\n"
    "The reported trace runs steady wind, so the swing reads as a steady-wind response, not a stability property (NR-058).\n"
    "The machine held a steady operating point through the measurement window.",
)

T1_OLD = (
    "No value moves, and no figure byte moves.\n"
    "\n"
    "## 2. Working notes"
)
T1_NEW = (
    "No value moves, and no figure byte moves.\n"
    "\n"
    "v0.55 pass by @author (2026-10-15).\n"
    "This pass prints the reject split and closes the item-2.1 environment set.\n"
    "The status mix takes the three-way split at sections 3.1 and 5 (NR-055).\n"
    "The operating table takes the shear law and the shaft elevation rows (NR-056, NR-057).\n"
    "The swing sentence takes its steady-wind basis note (NR-058).\n"
    "No value moves, and no figure byte moves.\n"
    "\n"
    "## 2. Working notes"
)

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")

PAIRS = [
    ("D1 version pin", D1),
    ("D2 section 3.1 split", D2),
    ("D3 section 5 split", D3),
    ("D4 environment rows", D4),
    ("D5 swing basis note", D5),
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
        ("pin: v0.55 dated 2026-10-15",
         "Draft v0.55" in cand_d and "Draft v0.54" not in cand_d and "Date 2026-10-15" in cand_d),
        ("reconstruction: candidate == base plus declared edits", cand_d == recon),
        ("reverse: base == candidate minus declared edits", rev == base_d),
        ("D2 lands once, old gone", cand_d.count(D2[1]) == 1 and cand_d.count(D2[0]) == 0),
        ("D3 lands once, old gone", cand_d.count(D3[1]) == 1 and cand_d.count(D3[0]) == 0),
        ("D4 lands once, old gone", cand_d.count(D4[1]) == 1 and cand_d.count(D4[0]) == 0),
        ("D5 lands once, old gone", cand_d.count(D5[1]) == 1 and cand_d.count(D5[0]) == 0),
        ("line count exact", len(c_lines) == (len(b_lines) + 15)),
        ("opcodes exact", EXPECT_OPCODES is not None and ops == EXPECT_OPCODES),
        ("new form count: 3.1 open reads once",
         cand_d.count("The reject class splits three ways (NR-055).") == 1),
        ("new form count: 5 open reads once",
         cand_d.count("The 301 rejects split three ways (NR-055).") == 1),
        ("new form count: subgroup A reads twice",
         cand_d.count("96 ran below the 5 kW power floor.") == 2),
        ("new form count: subgroup B reads twice",
         cand_d.count("Four ran at or above 5 kW with a factor of safety below 2.5.") == 2),
        ("new form count: subgroup C reads twice",
         cand_d.count("The cause is not logged for the remaining 201.") == 2),
        ("new form count: shear-law row reads once",
         cand_d.count("| Shear law | Hellmann power law, exponent 1/7, from the measured Daisy pair 10.0 m/s at 4.8 m | NR-056 |") == 1),
        ("new form count: shaft row reads once",
         cand_d.count("| Shaft elevation | 30 deg, hub at 9.4000 m | NR-057 |") == 1),
        ("new form count: swing note reads once",
         cand_d.count("The reported trace runs steady wind, so the swing reads as a steady-wind response, not a stability property (NR-058).") == 1),
        ("cite: NR-055 reads 2", cand_d.count("NR-055") == 2),
        ("cite: NR-056 reads 1", cand_d.count("NR-056") == 1),
        ("cite: NR-057 reads 1", cand_d.count("NR-057") == 1),
        ("cite: NR-058 reads 1", cand_d.count("NR-058") == 1),
        ("old pin form gone", cand_d.count("Draft v0.54") == 0),
        ("value holds: 22 degrees",
         cand_d.count("22 degrees") == base_d.count("22 degrees")),
        ("value holds: 25.698",
         cand_d.count("25.698") == base_d.count("25.698")),
        ("value holds: NR-049",
         cand_d.count("NR-049") == base_d.count("NR-049")),
        ("value holds: NR-050",
         cand_d.count("NR-050") == base_d.count("NR-050")),
        ("value holds: least segment margin",
         cand_d.count("The least segment torque margin is 2.03") == base_d.count("The least segment torque margin is 2.03")),
        ("hold: study-is-simulation-only",
         cand_d.count("The study is simulation-only.") == base_d.count("The study is simulation-only.") == 1),
        ("hold: never-allows-breaks close",
         cand_d.count("The fix removes false rejections. It never allows breaks.") ==
         base_d.count("The fix removes false rejections. It never allows breaks.") == 1),
        ("hold: gate table torsional row",
         cand_d.count("| Torsional capacity | capacity/demand | least margin 2.03 at S1 | +102.9 per cent above unity, 2.03 times | NR-040 |") == 1),
        ("region: 1 to the 3.1 heading unchanged",
         region(cand_d, "## 1 Introduction", "### 3.1 The search at scale") ==
         region(base_d, "## 1 Introduction", "### 3.1 The search at scale")),
        ("region: 3.2 to 3.3 heading unchanged",
         region(cand_d, "### 3.2 Convergence", "### 3.3 The winner") ==
         region(base_d, "### 3.2 Convergence", "### 3.3 The winner")),
        ("region: 3.4 to 5 unchanged",
         region(cand_d, "### 3.4 The levers of Performance", "## 5 Conclusion") ==
         region(base_d, "### 3.4 The levers of Performance", "## 5 Conclusion")),
        ("region: 6 to Document control unchanged",
         region(cand_d, "## 6 Nomenclature", "## Document control") ==
         region(base_d, "## 6 Nomenclature", "## Document control")),
        ("region: Document control to claims appendix unchanged",
         region(cand_d, "## Document control", "## Appendix: Claims and evidence") ==
         region(base_d, "## Document control", "## Appendix: Claims and evidence")),
        ("region: claims appendix unchanged",
         region(cand_d, "## Appendix: Claims and evidence", "## Appendix: Figure provenance") ==
         region(base_d, "## Appendix: Claims and evidence", "## Appendix: Figure provenance")),
        ("region: figure provenance unchanged",
         region(cand_d, "## Appendix: Figure provenance", "- `checks` `e6bcfca931") ==
         region(base_d, "## Appendix: Figure provenance", "- `checks` `e6bcfca931")),
        ("tracker v0.55 entry", "v0.55 pass by @author" in cand_t),
        ("tracker history held",
         "v0.54 pass by @author" in cand_t and "v0.53 pass by @author" in cand_t
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
