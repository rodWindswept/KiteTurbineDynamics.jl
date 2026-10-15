#!/usr/bin/env python3
"""Draft v0.47 — the round-6 fold (author seat, 2026-10-14).

Folds the round-6 rulings in one pass, keyed on the science sign
(`cb862df`, receipt docs/reporting/room-responses/
science-validator-2026-10-14-round6-signs.md):

  D1  version pin v0.46 -> v0.47 (date held 2026-10-14)
  D2  the hub-name retirement: the ten draft sites take the signed top
      forms (topmost ring / topmost rotor ring / top)
  D3  section 5: the count sentence (508 of 930, NR-002) and the winner
      sentence pair in the founder form
  D4  section 3.4 retitle: The levers -> The levers of Performance
  T1  tracker v0.47 entry

Signed site table: science-validator round-6 signs, section 1. The
routing: hermes-2026-10-14-feedback6-routing.md, comments 1 to 3 plus
the heading edit.

Two-state, fail-closed (mirrors au_v045_au7_discussion.py):
  - builds from `git show HEAD:<path>` (never the working file)
  - asserts every anchor exactly once
  - STE: rc=0; no category gains on either file; totals held
  - declared token diff must match exactly
  - register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v047_round6_fold.py          # build, gate, report
  python3 scratch/au_v047_round6_fold.py --write  # copy candidates over
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
BLOCK_REL = "scratch/sw_levers_reading_block.md"
BASE_D = ROOT / "scratch/au_v047_draft_base.md"
CAND_D = ROOT / "scratch/au_v047_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v047_tracker_base.md"
CAND_T = ROOT / "scratch/au_v047_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v047_round6_fold.log"

# Declared before the run. The pin moves (46 out, 47 in); the count
# sentence prints 508 (NR-002). No other value token moves.
ASSERT_TOKENS = True
EXPECT_D_ADD = {"47": 1, "508": 1}
EXPECT_D_REM = {"46": 1}
EXPECT_T_ADD = {"47": 1, "508": 1, "930": 1, "3.4": 1}
EXPECT_T_REM = {}

D1 = (
    "Internal engineering report. Draft v0.46. Date 2026-10-14.",
    "Internal engineering report. Draft v0.47. Date 2026-10-14.",
)

# the ten hub sites, signed forms (science-validator table, section 1)
D2 = [
    ("2.1 radii",
     "The search treats each of these as a gene. The ring geometry sets the\n"
     "hub and ground radii, and the rotor count sets how many rings carry\n"
     "blades.",
     "The search treats each of these as a gene. The ring geometry sets the\n"
     "topmost-ring and ground radii, and the rotor count sets how many rings carry\n"
     "blades."),
    ("2.2.2 load",
     "The hub-segment helix force reads about 1278 N/vertex (NR-048).",
     "The top-segment helix force reads about 1278 N/vertex (NR-048)."),
    ("3.3 capture",
     "The capture hub\nring reads 15.033 at the final step (NR-021).",
     "The capture topmost ring\nreads 15.033 at the final step (NR-021)."),
    ("3.3 table row",
     "| Hub radius | 4.580 m | NR-011 |",
     "| Topmost ring radius | 4.580 m | NR-011 |"),
    ("3.3 radius",
     "hub radius is 4.580 metres and the ground radius 0.804 metres",
     "topmost ring radius is 4.580 metres and the ground radius 0.804 metres"),
    ("3.4 line",
     "The hub ring R6 governs the structural check at the winner operating point (NR-021).",
     "The topmost rotor ring R6 governs the structural check at the winner operating point (NR-021)."),
    ("3.5 radius",
     "The hub radius is 4.580 m and the ground radius is 0.804 m.",
     "The topmost ring radius is 4.580 m and the ground radius is 0.804 m."),
    ("4.2 table row",
     "The middle rotor landed on the hub.",
     "The middle rotor landed on the topmost ring."),
    ("4.2 narrative",
     "build. An off-by-one in the rotor-to-ring map put the middle rotor on\n"
     "the hub (2026-08-26).",
     "build. An off-by-one in the rotor-to-ring map put the middle rotor on\n"
     "the topmost ring (2026-08-26)."),
    ("4.2 narrative 2",
     "  the FoS fix, and its rotors sat one ring toward the hub.",
     "  the FoS fix, and its rotors sat one ring toward the top."),
]

D3 = [
    ("5 count",
     "The search found a feasible candidate in the searched space.",
     "The search found 508 feasible candidates in the searched space (NR-002)."),
    ("5 winner pair",
     "Its mean power is 5.309 kW and its airborne mass is 25.698 kilograms (NR-008, NR-018).",
     "The best performing one had a mean power of 5.309 kW.\n"
     "Its airborne mass is 25.698 kilograms (NR-008, NR-018)."),
]

D4 = (
    "### 3.4 The levers\n",
    "### 3.4 The levers of Performance\n",
)

T1_OLD = (
    "The five plates and the three caption kits take the top forms (round-6 comment 1).\n"
    "No value moves.\n"
    "\n"
    "## 2. Working notes"
)
T1_NEW = (
    "The five plates and the three caption kits take the top forms (round-6 comment 1).\n"
    "No value moves.\n"
    "\n"
    "v0.47 pass by @author (2026-10-14).\n"
    "This pass folds the round-6 rulings, keyed on the science sign.\n"
    "The topmost-ring rename lands at the ten draft sites (topmost ring, topmost rotor ring and top).\n"
    "The conclusion prints the count 508 of 930 (NR-002), and the winner sentence takes the founder form.\n"
    "Section 3.4 retitles to The levers of Performance.\n"
    "No signed value changes.\n"
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

    block = (ROOT / BLOCK_REL).read_text().rstrip("\n")
    say(f"frozen levers block: {len(block)} bytes, md5 {hashlib.md5(block.encode()).hexdigest()}")

    # --- build the candidates -------------------------------------------
    cand_d = base_d
    pairs = [("D1 version pin", D1[0], D1[1])]
    pairs += [(f"D2 {name}", old, new) for name, old, new in D2]
    pairs += [(f"D3 {name}", old, new) for name, old, new in D3]
    pairs.append(("D4 retitle", D4[0], D4[1]))
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
    hub_b = len(re.findall(r"(?i)hub", base_d))
    hub_c = len(re.findall(r"(?i)hub", cand_d))
    top_b = len(re.findall(r"(?i)topmost", base_d))
    top_c = len(re.findall(r"(?i)topmost", cand_d))
    sec5 = region(cand_d, "## 5 Conclusion", "## 6 Nomenclature")
    markers_b = re.findall(r"^\[Figure seated:.*$", base_d, re.M)
    markers_c = re.findall(r"^\[Figure seated:.*$", cand_d, re.M)
    guards = [
        ("pin v0.47", "Draft v0.47" in cand_d and "Draft v0.46" not in cand_d),
        ("hub census: base 10", hub_b == 10),
        ("hub census: candidate 0", hub_c == 0),
        ("topmost census: base 1, candidate 9", top_b == 1 and top_c == 9),
        ("signed form: 2.1 radii", "topmost-ring and ground radii" in cand_d),
        ("signed form: 2.2.2 load", "The top-segment helix force reads about 1278 N/vertex (NR-048)." in cand_d),
        ("signed form: 3.3 capture", "The capture topmost ring" in cand_d),
        ("signed form: 3.3 table row", "| Topmost ring radius | 4.580 m | NR-011 |" in cand_d),
        ("signed form: 3.3 radius", "topmost ring radius is 4.580 metres" in cand_d),
        ("signed form: 3.4 full name", "The topmost rotor ring R6 governs" in cand_d),
        ("signed form: 3.5 radius", "The topmost ring radius is 4.580 m and the ground radius is 0.804 m." in cand_d),
        ("signed form: 4.2 table", "landed on the topmost ring." in cand_d),
        ("signed form: 4.2 narrative", "the topmost ring (2026-08-26)." in cand_d),
        ("signed form: 4.2 narrative 2", "one ring toward the top." in cand_d),
        ("retitle lands once", cand_d.count("### 3.4 The levers of Performance\n") == 1
         and "### 3.4 The levers\n" not in cand_d),
        ("count sentence once", cand_d.count("The search found 508 feasible candidates in the searched space (NR-002).") == 1),
        ("winner sentence once", cand_d.count("The best performing one had a mean power of 5.309 kW.") == 1),
        ("mass sentence once", cand_d.count("Its airborne mass is 25.698 kilograms (NR-008, NR-018).") == 1),
        ("no reject split in section 5", "301" not in sec5 and "110" not in sec5 and "reject" not in sec5),
        ("value holds: 4.580", cand_d.count("4.580") == base_d.count("4.580")),
        ("value holds: 15.033", cand_d.count("15.033") == base_d.count("15.033")),
        ("value holds: 5.309", cand_d.count("5.309") == base_d.count("5.309")),
        ("value holds: 25.698", cand_d.count("25.698") == base_d.count("25.698")),
        ("value holds: 0.804", cand_d.count("0.804") == base_d.count("0.804")),
        ("value holds: 930", cand_d.count("930") == base_d.count("930")),
        ("count prints: 508 held", cand_d.count("508") == base_d.count("508") + 1),
        ("count cites: NR-002 held", cand_d.count("(NR-002)") == base_d.count("(NR-002)") + 1),
        ("region 1-2.1 unchanged",
         region(cand_d, "## 1 Introduction", "### 2.1 The kite turbine and its terms")
         == region(base_d, "## 1 Introduction", "### 2.1 The kite turbine and its terms")),
        ("region 2.4-3.3 unchanged",
         region(cand_d, "### 2.4 The campaign", "### 3.3 The winner")
         == region(base_d, "### 2.4 The campaign", "### 3.3 The winner")),
        ("region 3.6-4.2 unchanged",
         region(cand_d, "### 3.6 Design implications", "### 4.2 The failure ledger")
         == region(base_d, "### 3.6 Design implications", "### 4.2 The failure ledger")),
        ("region 4.3-5 unchanged",
         region(cand_d, "### 4.3 Model boundaries", "## 5 Conclusion")
         == region(base_d, "### 4.3 Model boundaries", "## 5 Conclusion")),
        ("region 6 to end unchanged",
         cand_d.split("## 6 Nomenclature")[1] == base_d.split("## 6 Nomenclature")[1]),
        ("frozen levers block held once", cand_d.count(block) == 1),
        ("seven seated markers hold", len(markers_c) == 7 and markers_c == markers_b),
        ("safety forms held",
         "never allows breaks" in cand_d and "the check judges only real operation" in cand_d),
        ("classified line held",
         "- Of the 930, 508 designs pass every gate. The other 422 designs read 301 reject, 110 clearance_reject and 11 reject_twist (NR-002)." in cand_d),
        ("rename held", "soft constraint penalties" in cand_d and "gate penalties" not in cand_d),
        ("objective block held",
         "`f = mass + 5.0 * max(P_score - 5.0, 0)^2 + 20.0 * (2.5 / FoS_min)^2 + 1.0 * (r / (1 - r))^2`" in cand_d),
        ("number-gate brackets held",
         "[2.24 holds a register row (NR-015). The other values need rows" in cand_d
         and "[Daisy values need register rows before the final report quotes" in cand_d),
        ("head status line held",
         "Sections 3.4 to 3.6 carry their text." in cand_d),
        ("tracker v0.47 entry", "v0.47 pass by @author" in cand_t),
        ("tracker history held",
         "v0.46 pass by @fig-img-diagrams" in cand_t and "v0.45 pass by @author" in cand_t),
        ("tracker hub sites untouched",
         len(re.findall(r"(?i)hub", cand_t)) == len(re.findall(r"(?i)hub", base_t))),
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
    gains_d = {k: v - cats_db.get(k, 0) for k, v in cats_dc.items() if v > cats_db.get(k, 0) and not k.startswith("_")}
    gains_t = {k: v - cats_tb.get(k, 0) for k, v in cats_tc.items() if v > cats_tb.get(k, 0) and not k.startswith("_")}
    if gains_d:
        say(f"draft category gains: {gains_d}")
    if gains_t:
        say(f"tracker category gains: {gains_t}")
    ste_ok = (rc_dc == 0 and rc_tc == 0
              and None not in (tot_db, tot_dc, tot_tb, tot_tc)
              and tot_dc == tot_db and tot_tc == tot_tb
              and not gains_d and not gains_t)

    # --- token diff ---------------------------------------------------------
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

    # --- citation gate ------------------------------------------------------
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
