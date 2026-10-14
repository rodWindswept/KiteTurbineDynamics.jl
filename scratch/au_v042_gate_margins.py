#!/usr/bin/env python3
"""Draft v0.42 — the gate-margin column folds at section 3.3 (AU9, author seat, 2026-10-14).

Folds the SW2d gate-margin column once with the two corrected cells, per
the SV5 receipt section 3 and the display-form note (NR-009 on NR-015):

  D1  version pin: v0.41 -> v0.42, date held 2026-10-14
  D2  section 3.3: the gate table gains the margin column, the corrected
      power-floor and clearance cells, the display-form FoS row, the
      torsional capacity row and the rope-break margin cell
  T1  tracker v0.42 entry

Supplies: SV5 margin block (science-validator-2026-10-13-sv5-...),
W7 clearance read (aero-validator-2026-10-13-w7-...), display-form note
(science-validator-2026-10-14-gate-margin-display-forms), founder
feedback part 7.4 (the six-row shape).

Sections 4 and 5 and the appendix regions re-read unchanged (asserted).

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
BASE_D = ROOT / "scratch/au_v042_draft_base.md"
CAND_D = ROOT / "scratch/au_v042_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v042_tracker_base.md"
CAND_T = ROOT / "scratch/au_v042_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v042_gate_margins.log"

# Declared before the run. First pass runs with ASSERT_TOKENS False to print
# the live sets; the sets are baked here and the second pass asserts exactly.
ASSERT_TOKENS = True
EXPECT_D_ADD = {
    '42': 1, '5.314': 1, '0.314': 1, '6.28': 1, '12.5': 1, '500.0': 1,
    '6.00': 1, '5.468': 1, '3.968': 1, '264.5': 1, '3.65': 1, '64.913': 1,
    '65.7': 1, '2.91': 1, '2.03': 2, '102.9': 1, '15.0': 1, '2.5': 1,
}
EXPECT_D_REM = {'41': 1, '5.309': 1}
EXPECT_T_ADD = {'42': 1, '3.3': 1}
EXPECT_T_REM = {}

D1 = (
    "Internal engineering report. Draft v0.41. Date 2026-10-14.",
    "Internal engineering report. Draft v0.42. Date 2026-10-14.",
)

D2_OLD = (
    "| Gate | Threshold | Winner outcome | Source |\n"
    "|---|---|---|---|\n"
    "| Power floor | 5.0 kW | pass, P_mean 5.309 kW | NR-008, NR-027, NR-039 |\n"
    "| Structural FoS floor | 2.5 | pass, 15.0 minimum | NR-009, NR-015 |\n"
    "| Clearance | blade-tip gate | pass | NR-036 |\n"
    "| Twist | per-segment limit \u03b4crit | pass, all five segments within limit | NR-022 |\n"
    "| Rope break | none on the window | pass on the cold path | NR-012, NR-013 |\n"
)

D2_NEW = (
    "| Gate | Threshold | Winner outcome | Margin | Source |\n"
    "|---|---|---|---|---|\n"
    "| Power floor | 5.0 kW | pass, P_end 5.314 kW. Margin +0.314 kW / +6.28 per cent | NR-008, NR-027, NR-039 |\n"
    "| Structural FoS floor | 2.5 | pass, 15.0 minimum. 15.0 on 2.5, margin +12.5 / +500.0 per cent, 6.00 times | NR-009, NR-015 |\n"
    "| Clearance | blade-tip gate | pass, 5.468 m, margin +3.968 m | +264.5 per cent, 3.65 times | NR-042 |\n"
    "| Twist | per-segment limit \u03b4crit | pass, all five segments within limit | Least margin at S1. It reads +64.913 deg / +65.7 per cent, 2.91 times | NR-022 |\n"
    "| Torsional capacity | capacity/demand | least margin 2.03 at S1 | +102.9 per cent above unity, 2.03 times | NR-040 |\n"
    "| Rope break | none on the window | pass on the cold path | the warm path rejects healthy winners | NR-012, NR-013 |\n"
)

T1_OLD = "stay open for the visual pass.\nNo value moves.\n\n## 2. Working notes"
T1_NEW = (
    "stay open for the visual pass.\n"
    "No value moves.\n\n"
    "v0.42 pass by @author (2026-10-14).\n"
    "This pass folds the gate-margin column at section 3.3 (AU9).\n"
    "The gate table gains the margin column and the torsional capacity row.\n"
    "The power-floor and clearance cells take their corrected forms.\n"
    "The factor of safety row takes its display forms.\n"
    "No signed value changes.\n\n## 2. Working notes"
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
        ("D2 gate-margin table", D2_OLD, D2_NEW),
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
        ("pin v0.42", "Draft v0.42" in cand_d and "Draft v0.41" not in cand_d),
        ("new header once", cand_d.count("| Gate | Threshold | Winner outcome | Margin | Source |") == 1),
        ("old header gone", "| Gate | Threshold | Winner outcome | Source |" not in cand_d),
        ("power cell corrected", "pass, P_end 5.314 kW" in cand_d and "pass, P_mean 5.309 kW" not in cand_d),
        ("clearance cell corrected", "pass, 5.468 m, margin +3.968 m" in cand_d and "| Clearance | blade-tip gate | pass |" not in cand_d),
        ("clearance source moved", "margin +3.968 m | +264.5 per cent, 3.65 times | NR-042 |" in cand_d),
        ("fos outcome held", "pass, 15.0 minimum" in cand_d),
        ("fos row display forms", "15.0 on 2.5, margin +12.5 / +500.0 per cent, 6.00 times" in cand_d),
        ("twist margin row", "+64.913 deg / +65.7 per cent, 2.91 times" in cand_d),
        ("torque row", "| Torsional capacity | capacity/demand | least margin 2.03 at S1 | +102.9 per cent above unity, 2.03 times | NR-040 |" in cand_d),
        ("rope margin cell", "the warm path rejects healthy winners" in cand_d),
        ("internal forms absent",
         all(x not in cand_d for x in ["14.972", "14.97", "3.816", "27.363", "5.99 times", "+498.9", "+12.472"])),
        ("frozen levers block held once", cand_d.count(block) == 1),
        ("section 4 unchanged", sec4_cand == sec4_base),
        ("section 5 unchanged", sec5_cand == sec5_base),
        ("safety forms held",
         "never allows breaks" in cand_d and "the check judges only real operation" in cand_d),
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
             "figure-map row 10 (machine winner hero",
             "figure-map row 20 (the levers landscape",
             "figure-map row 21 (the parameter atlas",
         ])),
        ("number-gate brackets held",
         "[2.24 holds a register row (NR-015). The other values need rows" in cand_d
         and "[Daisy values need register rows before the final report quotes" in cand_d),
        ("head status line held",
         "Sections 3.4 to 3.6 carry their text." in cand_d),
        ("tracker v0.42 entry", "v0.42 pass by @author" in cand_t),
        ("tracker history held",
         "v0.41 fold pass by @figures-images-diagrams" in cand_t and "v0.40 pass by @author" in cand_t),
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
