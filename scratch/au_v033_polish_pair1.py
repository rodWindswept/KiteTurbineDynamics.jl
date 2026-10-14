#!/usr/bin/env python3
"""Draft v0.33 — the polish pair one: winner margins text + evolution story (author seat, 2026-10-14).

Applies to the tip (efc44f3), fail-closed, two-state (base read from
`git show HEAD:<path>`; never from the working file):

  D1  version pin: v0.32 -> v0.33, date held 2026-10-14
  D2  section 3.4: the winner margins text lands beside the rings and
      twist plates (between the row 7 marker and the row 20 marker)
  D3  section 3.5: the pending bracket retires; the evolution story text
      lands below the strip marker
  T1  tracker v0.33 entry

Gates: STE per file (rc=0; total must not exceed base; no category
gains), declared token diff (draft + tracker), the register-seat
citation checker. --write copies candidates over the repo files only
when every gate is green.

Usage:
  python3 scratch/au_v033_polish_pair1.py          # build, gate, report
  python3 scratch/au_v033_polish_pair1.py --write  # copy candidates over repo files
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
BASE_D = ROOT / "scratch/au_v033_draft_base.md"
CAND_D = ROOT / "scratch/au_v033_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v033_tracker_base.md"
CAND_T = ROOT / "scratch/au_v033_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v033_polish_pair1.log"

# Declared before the run — the full push delta against the tip.
# (Baked after the dry run; the assert is exact on both sides.)
ASSERT_TOKENS = True
EXPECT_D_ADD = {
    "0": 2, "0.20": 1, "0.804": 1, "0.82": 1, "0.951": 1, "1.665": 1,
    "15.0": 1, "15.033": 1, "2.03": 1, "2.69": 1, "22.8": 1,
    "25.698": 1, "26": 1, "27.364": 2, "28.315": 1, "29.8": 1,
    "32.293": 1, "33": 1, "33.5": 1, "33.9": 1, "35.2": 1,
    "36.109": 2, "4.580": 1, "6": 1, "92.6": 1, "98.9": 1,
}
EXPECT_D_REM = {"32": 1}
EXPECT_T_ADD = {"33": 1, "3.4": 1, "3.5": 1}
EXPECT_T_REM = {}

D1 = (
    "Internal engineering report. Draft v0.32. Date 2026-10-14.",
    "Internal engineering report. Draft v0.33. Date 2026-10-14.",
)

MARGIN = (
    "The hub ring R6 governs the structural check at the winner operating point (NR-021).\n"
    "The window-minimum factor of safety is 15.0 (NR-009).\n"
    "At the final step, R6 reads 15.033 (NR-021).\n"
    "R2 to R4 read 29.8 to 35.2 (NR-021).\n"
    "R5 carries almost no load in the checked beam (NR-021).\n"
    "\n"
    "The ground ring sits on ground support and stays outside the ring check.\n"
    "All five TRPT segments remain inside their over-twist limits at the winner operating point (NR-022).\n"
    "S1 to S4 transmit 33.5 to 33.9 degrees against a 98.9 degree limit (NR-022).\n"
    "S5 transmits 22.8 degrees against its 92.6 degree limit (NR-022).\n"
    "The least segment torque margin is 2.03, at S1 (NR-040).\n"
    "\n"
    "S5 carries the largest segment torque margin, 2.69 (NR-040).\n"
    "The winner is not close to ring buckling, over-twist or segment torque saturation at this operating point.\n"
    "The margins are conditional.\n"
    "They cover the checked TRPT rings and segments only.\n"
    "They do not yet include blade integrity or lifter loads across wind bands."
)

EVO = (
    "The machine evolution strip traces the search on island 3 from the common seed to the campaign winner (NR-036).\n"
    "The objective falls from 36.109 kg-equivalent at generation 0 to 27.364 kg-equivalent at generation 26 (NR-036).\n"
    "The largest recorded drop falls between generations 0 and 6, from 36.109 to 32.293 (NR-036).\n"
    "The final recorded step reads 28.315 to 27.364, a drop of 0.951 (NR-036).\n"
    "\n"
    "The winner value is the search objective, not a mass reading.\n"
    "The objective reads the airborne mass 25.698 kg plus 1.665 kg-equivalent of penalties (NR-018, NR-039).\n"
    "\n"
    "The final panel matches the register winner.\n"
    "The panel reads three lines and six rings (NR-011).\n"
    "The hub radius is 4.580 m and the ground radius is 0.804 m.\n"
    "The blade scales read 0.82 and 0.20 (NR-011).\n"
    "The winner genome carries inactive slots at a rotor count of one (NR-011, NR-017).\n"
    "\n"
    "The strip shows built geometry and the search objective only.\n"
    "The strip prints no power value and no airborne mass value."
)

A1_OLD = "Values cite NR-022 and NR-023.]\n\n[Figure seated: figure-map row 20"
A1_NEW = "Values cite NR-022 and NR-023.]\n\n" + MARGIN + "\n\n[Figure seated: figure-map row 20"

A2_OLD = "### 3.5 The evolution story [PENDING. Phase 3 and the machine renderer supply this section.]"
A2_NEW = "### 3.5 The evolution story"

A3_OLD = "Values cite NR-005, NR-006, NR-011 and NR-036.]\n\n### 3.6 Design implications"
A3_NEW = "Values cite NR-005, NR-006, NR-011 and NR-036.]\n\n" + EVO + "\n\n### 3.6 Design implications"

T1_OLD = "No value moves.\n\n## 2. Working notes"
T1_NEW = (
    "No value moves.\n\n"
    "v0.33 pass by @author (2026-10-14).\n"
    "This pass completes the winner margins text at section 3.4 and the evolution story at section 3.5.\n"
    "The margin text prints signed rows NR-009, NR-021, NR-022 and NR-040.\n"
    "The evolution story prints signed rows NR-036, NR-005, NR-018, NR-039 and NR-011.\n"
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
        ("D2 winner margins insert", A1_OLD, A1_NEW),
        ("D3a 3.5 heading", A2_OLD, A2_NEW),
        ("D3b evolution story insert", A3_OLD, A3_NEW),
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
        ("pin v0.33", "Draft v0.33" in cand_d and "Draft v0.32" not in cand_d),
        ("pending bracket retired", "[PENDING. Phase 3 and the machine renderer supply this section.]" not in cand_d),
        ("heading form", "### 3.5 The evolution story\n" in cand_d),
        ("margin block present", "R2 to R4 read 29.8 to 35.2 (NR-021)." in cand_d
         and "The window-minimum factor of safety is 15.0 (NR-009)." in cand_d),
        ("evolution block present", "The winner genome carries inactive slots at a rotor count of one (NR-011, NR-017)." in cand_d
         and "The final recorded step reads 28.315 to 27.364, a drop of 0.951 (NR-036)." in cand_d),
        ("no 3.816 print", "3.816" not in cand_d),
        ("no 14.972 print", "14.972" not in cand_d),
        ("hub ring kept form", cand_d.count("15.033") >= 2),
        ("section 3.6 pending held", "### 3.6 Design implications [PENDING. Phase 3 and the regime table supply this.]" in cand_d),
        ("levers reading intact", "The two plates map the same search in two views." in cand_d),
        ("markers held",
         all(m in cand_d for m in [
             "figure-map row 6 (ring utilisation plate",
             "figure-map row 7 (twist limit plate",
             "figure-map row 9 (machine evolution strip",
             "figure-map row 20 (the levers landscape",
             "figure-map row 21 (the parameter atlas",
         ])),
        ("tracker v0.33 entry", "v0.33 pass by @author" in cand_t),
        ("tracker history held", "v0.32 pass by @author" in cand_t and "v0.31 pass by @author" in cand_t),
        ("tracker no-value-moves count", cand_t.count("No value moves.") == 3),
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
