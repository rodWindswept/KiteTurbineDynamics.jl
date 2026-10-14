#!/usr/bin/env python3
"""Draft v0.40 — the decision shape folds across the later sections (PL13, author seat, 2026-10-14).

Applies the part-15 decision shape to the settled later text: every section
answers what it learned, its evidence, what it does not prove, and its next
action.

  D1  version pin: v0.39 -> v0.40, date held 2026-10-14
  D2  section 3.4: the margin block takes its next-action line
  D3  section 3.5: the evolution story takes its limit and next-read lines
  D4  section 3.6: the implications take their condition and limit lines
  T1  tracker v0.40 entry

Section 4 and the appendix regions re-read unchanged (asserted).

Gates: STE per file (rc=0; totals must not exceed base; no category gains),
declared token diff (draft, tracker), the register-seat citation checker.
--write copies candidates over the repo files only when every gate is green.
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
BASE_D = ROOT / "scratch/au_v040_draft_base.md"
CAND_D = ROOT / "scratch/au_v040_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v040_tracker_base.md"
CAND_T = ROOT / "scratch/au_v040_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v040_decision_shape.log"

# Declared before the run. First pass runs with ASSERT_TOKENS False to print
# the live sets; the sets are baked here and the second pass asserts exactly.
ASSERT_TOKENS = True
EXPECT_D_ADD = {'40': 1}
EXPECT_D_REM = {'39': 1}
EXPECT_T_ADD = {'40': 1}
EXPECT_T_REM = {}

D1 = (
    "Internal engineering report. Draft v0.39. Date 2026-10-14.",
    "Internal engineering report. Draft v0.40. Date 2026-10-14.",
)

D2 = (
    "They do not yet include blade integrity or lifter loads across wind bands.\n",
    "They do not yet include blade integrity or lifter loads across wind bands.\n"
    "The next steps add the blade checks and the gust cases.\n",
)

D3 = (
    "The strip prints no power value and no airborne mass value.\n",
    "The strip prints no power value and no airborne mass value.\n"
    "The trace reads one island of the campaign.\n"
    "It does not prove a global optimum.\n"
    "A longer or broader run would extend the search.\n",
)

D4 = (
    "Conditional genes can improve the search efficiency without changing the machine problem.\n",
    "Conditional genes can improve the search efficiency without changing the machine problem.\n"
    "\n"
    "The implications hold under the modeled objective and gates.\n"
    "They do not prove an optimal gene set.\n",
)

T1_OLD = "No value moves.\n\n## 2. Working notes"
T1_NEW = (
    "No value moves.\n\n"
    "v0.40 pass by @author (2026-10-14).\n"
    "This pass folds the decision shape (PL13) across the later sections.\n"
    "The margin block takes its next-action line, and the evolution story takes its limit and next-read lines.\n"
    "The implications take their condition and limit, and the discussion re-reads with the shape standing.\n"
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

    # --- build the candidates ------------------------------------------
    cand_d = base_d
    pairs = [
        ("D1 version pin", D1[0], D1[1]),
        ("D2 section 3.4 next action", D2[0], D2[1]),
        ("D3 section 3.5 limit and next", D3[0], D3[1]),
        ("D4 section 3.6 condition and limit", D4[0], D4[1]),
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
    sec4_base = region(base_d, "## 4 Discussion", "## 5 Conclusion")
    sec4_cand = region(cand_d, "## 4 Discussion", "## 5 Conclusion")
    sec5_base = region(base_d, "## 5 Conclusion", "## 6 Nomenclature")
    sec5_cand = region(cand_d, "## 5 Conclusion", "## 6 Nomenclature")
    guards = [
        ("pin v0.40", "Draft v0.40" in cand_d and "Draft v0.39" not in cand_d),
        ("3.4 next line present",
         "The next steps add the blade checks and the gust cases." in cand_d),
        ("3.4 limit held",
         "They do not yet include blade integrity or lifter loads across wind bands." in cand_d),
        ("3.5 limit and next present",
         "The trace reads one island of the campaign." in cand_d
         and "It does not prove a global optimum." in cand_d
         and "A longer or broader run would extend the search." in cand_d),
        ("3.5 strip scope held",
         "The strip shows built geometry and the search objective only." in cand_d
         and "The strip prints no power value and no airborne mass value." in cand_d),
        ("3.6 condition and limit present",
         "The implications hold under the modeled objective and gates." in cand_d
         and "They do not prove an optimal gene set." in cand_d),
        ("3.6 implications held",
         "The record supports four implications." in cand_d
         and "Recommended next steps:" in cand_d
         and "Conditional genes can improve the search efficiency without changing the machine problem." in cand_d),
        ("frozen levers block held once", cand_d.count(block) == 1),
        ("section 4 unchanged", sec4_cand == sec4_base),
        ("section 5 unchanged", sec5_cand == sec5_base),
        ("safety forms held",
         "never allows breaks" in cand_d and "the check judges only real operation" in cand_d),
        ("no 14.97 print", "14.97" not in cand_d),
        ("no 14.972 print", "14.972" not in cand_d),
        ("no 3.816 print", "3.816" not in cand_d),
        ("no rounded 27.363 print", "27.363" not in cand_d),
        ("classified line present",
         "- Of the 930, 508 designs pass every gate. The other 422 designs read 301 reject, 110 clearance_reject and 11 reject_twist (NR-002)." in cand_d),
        ("rename held", "soft constraint penalties" in cand_d and "gate penalties" not in cand_d),
        ("objective block held",
         "`f = mass + 5.0 * max(P_score - 5.0, 0)^2 + 20.0 * (2.5 / FoS_min)^2 + 1.0 * (r / (1 - r))^2`" in cand_d),
        ("markers held",
         all(m in cand_d for m in [
             "figure-map row 2 (system anatomy plate",
             "figure-map row 6 (ring utilisation plate",
             "figure-map row 7 (twist limit plate",
             "figure-map row 9 (machine evolution strip",
             "figure-map row 20 (the levers landscape",
             "figure-map row 21 (the parameter atlas",
         ])),
        ("number-gate brackets held",
         "[2.24 holds a register row (NR-015). The other values need rows" in cand_d
         and "[Daisy values need register rows before the final report quotes" in cand_d),
        ("head status line held",
         "Sections 3.4 to 3.6 carry their text." in cand_d),
        ("tracker v0.40 entry", "v0.40 pass by @author" in cand_t),
        ("tracker history held", "v0.39 pass by @author" in cand_t and "v0.38 pass by @author" in cand_t),
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
              and tot_dc <= tot_db and tot_tc <= tot_tb
              and not gains_d and not gains_t)

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
