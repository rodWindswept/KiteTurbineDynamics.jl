#!/usr/bin/env python3
"""Draft v0.39 — the k = 2.24 story folds at section 2.3 (author seat, 2026-10-14).

Folds the k-story plan into the operating-point block:
  queue item 7 (author leg, gate lifted by the k-sweep rows sign `07e2eb9`)
  story check `docs/reporting/room-responses/aero-worker-2026-10-14-kmppt-story-check.md` (`3b8e099`)
  counter-read `docs/reporting/room-responses/aero-validator-2026-10-14-kmppt-counter-...`.
  Register rows: NR-047 (display rows, tips, retirements), NR-048 (sizing pair),
  NR-046 (over-power tie-in).

Fail-closed, two-state (base read from `git show HEAD:<path>`):

  D1  version pin: v0.38 -> v0.39, date held 2026-10-14
  D2  the operating-point block expands after the two-ends summary:
      the two retirements, the six-row sweep table (split 3/3 to hold the
      STE paragraph count), one paragraph per side (tip ceiling, FoS fall
      with the over-power tie-in) and the sizing-side pair
  T1  tracker v0.39 entry

Gates: STE per file (rc=0; total must not exceed base; no category gains),
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
BASE_D = ROOT / "scratch/au_v039_draft_base.md"
CAND_D = ROOT / "scratch/au_v039_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v039_tracker_base.md"
CAND_T = ROOT / "scratch/au_v039_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v039_k_story_fold.log"

# Declared before the run — the full push delta against the tip. First pass
# runs with ASSERT_TOKENS False to print the live sets; the sets are baked
# here and the second pass asserts them exactly.
ASSERT_TOKENS = True
EXPECT_D_ADD = {'0.5': 2, '1.0': 2, '1.5': 2, '1.94': 2, '100': 1, '103': 1, '1278': 1, '14.42': 1, '15.3': 1, '15.34': 1, '15.80': 1, '16.59': 1, '17.6': 1, '17.64': 1, '19.14': 1, '2.24': 3, '24.3': 2, '3.0': 3, '3.49': 1, '3.55': 1, '36.4': 2, '39': 1, '40.1': 1, '42.8': 1, '47.8': 1, '5': 1, '5.0': 1, '5.39': 1, '5.45': 1, '51.8': 1, '6.78': 1, '7.56': 1, '73': 1, '78.8': 1, '8.00': 1, '8.89': 1, '85': 1, '87.9': 1, '9': 1}
EXPECT_D_REM = {'38': 1}
EXPECT_T_ADD = {'2.24': 1, '2.3': 1, '39': 1}
EXPECT_T_REM = {}

D1 = (
    "Internal engineering report. Draft v0.38. Date 2026-10-14.",
    "Internal engineering report. Draft v0.39. Date 2026-10-14.",
)

NEW_BLOCK = (
    "Two earlier anchors retired.\n"
    "3.55 was a mass-scaled value with no anchor.\n"
    "5.39 was the 3-blade anchor chosen on the broken machine.\n"
    "That load forces about 9 kW from the seed (NR-047).\n"
    "\n"
    "The sweep rows read as follows (NR-047).\n"
    "\n"
    "Rows k 0.5 to 1.5:\n"
    "\n"
    "| k | status | P_mean (kW) | omega_final (rad/s) | FoS_min |\n"
    "|---|---|---|---|---|\n"
    "| 0.5 | reject | 3.49 | 19.14 | 51.8 |\n"
    "| 1.0 | ok | 5.45 | 17.64 | 47.8 |\n"
    "| 1.5 | ok | 6.78 | 16.59 | 42.8 |\n"
    "\n"
    "Rows k 1.94 to 3.0:\n"
    "\n"
    "| k | status | P_mean (kW) | omega_final (rad/s) | FoS_min |\n"
    "|---|---|---|---|---|\n"
    "| 1.94 | ok | 7.56 | 15.80 | 40.1 |\n"
    "| 2.24 | ok | 8.00 | 15.34 | 36.4 |\n"
    "| 3.0 | ok | 8.89 | 14.42 | 24.3 |\n"
    "\n"
    "At the light end the seed spins up.\n"
    "The k 1.0 row settles at omega 17.6, tip about 85 m/s, near the 100 m/s ceiling.\n"
    "The ceiling is a hard evaluator gate (TIP_SPEED_CEILING_MPS, src/objective_evaluator.jl:103).\n"
    "The selected k 2.24 settles at omega 15.3, tip about 73 m/s (NR-047).\n"
    "\n"
    "At the heavy end the load raises the torque and the line tension, so FoS falls.\n"
    "The FoS_min column reads 36.4 at k 2.24, down to 24.3 at k 3.0 (NR-047).\n"
    "The heavy end also carries a score cost.\n"
    "The objective charges 5 kg-equivalent per excess kW squared above the 5.0 kW ceiling (NR-046).\n"
    "\n"
    "The load choice also has a structural side.\n"
    "The beam sizes on a bounded generator load step, twice the nominal load (NR-048).\n"
    "The hub-segment helix force reads about 1278 N/vertex (NR-048).\n"
    "The low-wind lull is benign under the load law.\n"
    "The record refuses k easing as the high-wind substitute.\n"
    "The rotor spins up to 87.9\u00b0 of twist against the 78.8\u00b0 collapse limit (NR-048)."
)

D2 = (
    "the working range\nbetween them.\n\nThe campaign also fixed the shaft length.",
    "the working range\nbetween them.\n\n" + NEW_BLOCK + "\n\nThe campaign also fixed the shaft length.",
)

T1_OLD = "No value moves.\n\n## 2. Working notes"
T1_NEW = (
    "No value moves.\n\n"
    "v0.39 pass by @author (2026-10-14).\n"
    "This pass folds the k = 2.24 story at section 2.3.\n"
    "The two retirements, the sweep table and one paragraph per side land, with the sizing-side pair and the over-power tie-in.\n"
    "The values read NR-047 and NR-048, and the tie-in rides NR-046.\n"
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
        ("D2 k-story block", D2[0], D2[1]),
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
        ("pin v0.39", "Draft v0.39" in cand_d and "Draft v0.38" not in cand_d),
        ("retire block present",
         "Two earlier anchors retired." in cand_d
         and "3.55 was a mass-scaled value with no anchor." in cand_d
         and "5.39 was the 3-blade anchor chosen on the broken machine." in cand_d
         and "That load forces about 9 kW from the seed (NR-047)." in cand_d),
        ("table present",
         "| 0.5 | reject | 3.49 | 19.14 | 51.8 |" in cand_d
         and "| 2.24 | ok | 8.00 | 15.34 | 36.4 |" in cand_d
         and "| 3.0 | ok | 8.89 | 14.42 | 24.3 |" in cand_d),
        ("light side present",
         "The k 1.0 row settles at omega 17.6, tip about 85 m/s, near the 100 m/s ceiling." in cand_d
         and "TIP_SPEED_CEILING_MPS" in cand_d
         and "tip about 73 m/s" in cand_d),
        ("heavy side present",
         "The FoS_min column reads 36.4 at k 2.24, down to 24.3 at k 3.0 (NR-047)." in cand_d
         and "5 kg-equivalent per excess kW squared above the 5.0 kW ceiling (NR-046)" in cand_d),
        ("sizing pair present",
         "1278 N/vertex" in cand_d and "87.9\u00b0" in cand_d and "78.8\u00b0" in cand_d
         and "twice the nominal load" in cand_d),
        ("split labels present", "Rows k 0.5 to 1.5:" in cand_d and "Rows k 1.94 to 3.0:" in cand_d),
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
        ("tracker v0.39 entry", "v0.39 pass by @author" in cand_t),
        ("tracker history held", "v0.38 pass by @author" in cand_t and "v0.37 pass by @author" in cand_t),
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
