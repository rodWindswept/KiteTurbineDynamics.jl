#!/usr/bin/env python3
"""Draft v0.52 — the basics-of-TRPT refresher (author seat, 2026-10-15).

Folds the founder ask as the room logs it: "The basics-of-TRPT refresher
for the report (scope call at @author). Not gated" (queue page;
"Founder asks, logged"), read as activated at the map seat of
2026-10-15 ("The passage recovers that ground for first-time readers").

This pass reads the scope as: a plain operation block at section 2.1,
closing the machine's term set ahead of the system-anatomy figure. The
block recovers the working chain for first-time readers: the rotor, the
rotary shaft, the ring-to-ring torque path, the ground take-off, the
tension requirement and the settled twisted form. Number-free and
cite-free; no value moves, and no new terms.

  D1  version pin v0.51 -> v0.52 (date held at 2026-10-15)
  D2  the operation block lands before the system-anatomy marker
  T1  tracker v0.52 entry

Two-state, fail-closed (mirrors au_v050_kmppt_plain_fold.py):
  - builds from `git show HEAD:<path>` (never the working file)
  - asserts every anchor exactly once
  - reconstruction: the candidate equals base plus the declared edits,
    and reverses exactly; the block carries no digits
  - changed-line census: the difflib opcode list must match exactly
  - STE: rc=0; no category gains; totals held
  - declared token diff must match exactly
  - register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v052_trpt_basics_fold.py          # build, gate, report
  python3 scratch/au_v052_trpt_basics_fold.py --write  # copy candidates over
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
BASE_D = ROOT / "scratch/au_v052_draft_base.md"
CAND_D = ROOT / "scratch/au_v052_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v052_tracker_base.md"
CAND_T = ROOT / "scratch/au_v052_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v052_trpt_basics_fold.log"

# Declared before the run. The pin moves (51 out, 52 in) on the draft.
# The tracker adds its v0.52 entry (52 and the section token 2.1). No
# value token moves.
ASSERT_TOKENS = True
EXPECT_D_ADD = {"52": 1}
EXPECT_D_REM = {"51": 1}
EXPECT_T_ADD = {"52": 1, "2.1": 1}
EXPECT_T_REM = {}

# Expected difflib opcode list, base lines -> candidate lines (baked from
# the dry run; the dry run prints the live list when it disagrees).
EXPECT_OPCODES = [
    ("equal", 0, 2, 0, 2),
    ("replace", 2, 3, 2, 3),
    ("equal", 3, 228, 3, 228),
    ("insert", 228, 228, 228, 241),
    ("equal", 228, 1009, 241, 1022),
]

D1 = (
    "Internal engineering report. Draft v0.51. Date 2026-10-15.",
    "Internal engineering report. Draft v0.52. Date 2026-10-15.",
)

BLOCK = (
    "At the top of the shaft the rotor turns in the wind.\n"
    "The whole shaft turns with the rotor.\n"
    "The shaft passes the torque from ring to ring.\n"
    "The lowest ring turns the generator at the ground station.\n"
    "\n"
    "The shaft works only under tension.\n"
    "Tension gives the shaft its capacity to transmit torque.\n"
    "With low tension the shaft bends and twists.\n"
    "A slack shaft cannot carry the load.\n"
    "\n"
    "Under the generator load the machine settles onto one operating point.\n"
    "In the settled state the shaft runs twisted along its length."
)

D2 = (
    "It is not a search gene (NR-049).\n\n[Figure seated: figure-map row 2",
    "It is not a search gene (NR-049).\n\n" + BLOCK + "\n\n[Figure seated: figure-map row 2",
)

T1_OLD = (
    "No value moves, and no figure byte moves.\n"
    "\n"
    "## 2. Working notes"
)
T1_NEW = (
    "No value moves, and no figure byte moves.\n"
    "\n"
    "v0.52 pass by @author (2026-10-15).\n"
    "This pass lands the basics-of-TRPT refresher at section 2.1.\n"
    "The operation block states how the machine carries torque to the ground.\n"
    "No value moves, and no figure byte moves.\n"
    "\n"
    "## 2. Working notes"
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
    pairs = [("D1 version pin", D1[0], D1[1]), ("D2 operation block", D2[0], D2[1])]
    cand_d = base_d
    for name, old, new in pairs:
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

    # --- guards ----------------------------------------------------------
    ops = opcodes(base_d, cand_d)
    say(f"draft opcodes: {ops}")
    b_lines, c_lines = base_d.splitlines(), cand_d.splitlines()

    guards = [
        ("pin: v0.52 dated 2026-10-15",
         "Draft v0.52" in cand_d and "Draft v0.51" not in cand_d and "Date 2026-10-15" in cand_d),
        ("reconstruction: candidate == base plus declared edits",
         cand_d == base_d.replace(D1[0], D1[1], 1).replace(D2[0], D2[1], 1)),
        ("reverse: base == candidate minus declared edits",
         cand_d.replace(D2[1], D2[0], 1).replace(D1[1], D1[0], 1) == base_d),
        ("insertion lands once, old junction gone",
         cand_d.count(D2[1]) == 1 and cand_d.count(D2[0]) == 0),
        ("block bytes once, digit-free", cand_d.count(BLOCK) == 1 and re.search(r"\d", BLOCK) is None),
        ("line count: base + 13", len(c_lines) == len(b_lines) + 13 == 1022),
        ("opcodes exact", ops == EXPECT_OPCODES),
        ("marker intact once",
         cand_d.count("[Figure seated: figure-map row 2 (system anatomy plate, slug `system-anatomy`). Values cite NR-011, NR-017 and NR-043.]") == 1),
        ("cite count held: NR-", cand_d.count("NR-") == base_d.count("NR-")),
        ("value holds: 22 degrees", cand_d.count("22 degrees") == base_d.count("22 degrees")),
        ("value holds: 0.75", cand_d.count("0.75") == base_d.count("0.75")),
        ("value holds: 0.113", cand_d.count("0.113") == base_d.count("0.113")),
        ("value holds: NR-049", cand_d.count("NR-049") == base_d.count("NR-049")),
        ("value holds: NR-050", cand_d.count("NR-050") == base_d.count("NR-050")),
        ("region: 1 Introduction to 2.1 unchanged",
         region(cand_d, "## 1 Introduction", "### 2.1 The kite turbine") == region(base_d, "## 1 Introduction", "### 2.1 The kite turbine")),
        ("region: 2.1 head to the block unchanged",
         region(cand_d, "### 2.1 The kite turbine and its terms", BLOCK) == region(base_d, "### 2.1 The kite turbine and its terms", "[Figure seated: figure-map row 2")),
        ("region: marker to 2.2 unchanged",
         region(cand_d, "[Figure seated: figure-map row 2", "### 2.2 The simulation") == region(base_d, "[Figure seated: figure-map row 2", "### 2.2 The simulation")),
        ("region: 2.2 to 2.4 unchanged",
         region(cand_d, "### 2.2 The simulation", "### 2.4 The campaign") == region(base_d, "### 2.2 The simulation", "### 2.4 The campaign")),
        ("region: 3 Results to 4 Discussion unchanged",
         region(cand_d, "## 3 Results", "## 4 Discussion") == region(base_d, "## 3 Results", "## 4 Discussion")),
        ("region: 4 Discussion to 5 Conclusion unchanged",
         region(cand_d, "## 4 Discussion", "## 5 Conclusion") == region(base_d, "## 4 Discussion", "## 5 Conclusion")),
        ("region: 5 Conclusion to 6 Nomenclature unchanged",
         region(cand_d, "## 5 Conclusion", "## 6 Nomenclature") == region(base_d, "## 5 Conclusion", "## 6 Nomenclature")),
        ("region: 6 Nomenclature to provenance appendix unchanged",
         region(cand_d, "## 6 Nomenclature", "## Appendix: Figure provenance") == region(base_d, "## 6 Nomenclature", "## Appendix: Figure provenance")),
        ("tracker v0.52 entry", "v0.52 pass by @author" in cand_t),
        ("tracker history held",
         "v0.51 pass by @fig-img-diagrams" in cand_t and "v0.50 pass by @author" in cand_t
         and "v0.49 pass by @author" in cand_t and "## 2. Working notes" in cand_t),
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
    def tokdiff(base, cand):
        a, b = Counter(TOK.findall(base)), Counter(TOK.findall(cand))
        return dict(b - a), dict(a - b)

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
