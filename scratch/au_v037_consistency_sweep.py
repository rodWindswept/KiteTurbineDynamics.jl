#!/usr/bin/env python3
"""Draft v0.37 — the consistency sweep, PL9 (author seat, 2026-10-14).

Applies to the tip (9ae8097), fail-closed, two-state (base read from
`git show HEAD:<path>`; never from the working file):

  D1  version pin: v0.36 -> v0.37, date held 2026-10-14
  D2  abstract: "candidate kite turbine designs" -> "candidate designs"
  D3  abstract: "candidate kite turbine" -> "candidate"; "5.309 kilowatts" -> kW
  D4  keywords: "ground generation" -> "ground-generation"
  D5  summary: "422 fail one gate" -> the classified fail counts (NR-002)
  D6  summary bullet: "5.309 kilowatts" -> kW
  D7  section 2.4 statuses: the stacked "The" openings vary
  D8-D16  unit forms: kilowatts -> kW (prose), "radians per second" -> rad/s,
      "revolutions per minute" -> rpm, "percent" -> "per cent"
  D17 the section 2.2.2 build request retires from the body
      (the tracker section-4 line stands)
  T1  tracker v0.37 entry

Gates: STE per file (rc=0; total must not exceed base; no category
gains), declared token diff (draft, tracker), the register-seat
citation checker. --write copies candidates over the repo files only
when every gate is green.

Usage:
  python3 scratch/au_v037_consistency_sweep.py          # build, gate, report
  python3 scratch/au_v037_consistency_sweep.py --write  # copy candidates over repo files
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
BASE_D = ROOT / "scratch/au_v037_draft_base.md"
CAND_D = ROOT / "scratch/au_v037_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v037_tracker_base.md"
CAND_T = ROOT / "scratch/au_v037_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v037_consistency_sweep.log"

# Declared before the run — the full push delta against the tip.
# First pass runs with ASSERT_TOKENS False to print the live sets; the
# sets are baked here and the second pass asserts them exactly.
ASSERT_TOKENS = True
EXPECT_D_ADD = {"11": 1, "110": 1, "301": 1, "37": 1, "5": 1, "50": 1}
EXPECT_D_REM = {"19": 1, "36": 1}
EXPECT_T_ADD = {"2": 1, "2.2": 1, "37": 1}
EXPECT_T_REM = {}

D1 = (
    "Internal engineering report. Draft v0.36. Date 2026-10-14.",
    "Internal engineering report. Draft v0.37. Date 2026-10-14.",
)

D2 = (
    "A differential-evolution campaign evaluated 930 candidate kite turbine\ndesigns under one fixed power-law generator load, each on the measurement\nwindow (NR-001).",
    "A differential-evolution campaign evaluated 930 candidate designs under\none fixed power-law generator load, each on the measurement window\n(NR-001).",
)

D3 = (
    "The campaign winner is the best feasible candidate kite turbine under the\nmodeled objective and gates. Its mean power is 5.309 kilowatts at the\nsite wind, 11.01 m/s at 9.41 m (NR-008, NR-032).",
    "The campaign winner is the best feasible candidate under the modeled\nobjective and gates. Its mean power is 5.309 kW at the site wind,\n11.01 m/s at 9.41 m (NR-008, NR-032).",
)

D4 = (
    "**Keywords.** airborne wind energy, kite turbine, ground generation,",
    "**Keywords.** airborne wind energy, kite turbine, ground-generation,",
)

D5 = (
    "- Of the 930, 508 designs pass every gate and 422 fail one gate (NR-002).",
    "- Of the 930, 508 designs pass every gate. The other 422 designs read 301 reject, 110 clearance_reject and 11 reject_twist (NR-002).",
)

D6 = (
    "  Its mean power is 5.309 kilowatts and its airborne mass 25.698 kilograms (NR-008, NR-018).",
    "  Its mean power is 5.309 kW and its airborne mass 25.698 kilograms (NR-008, NR-018).",
)

D7 = (
    "The ok designs pass every gate. The rejects fail a gate. The\nclearance rejects fail the clearance gate. The twist rejects fail the\ntwist gate.",
    "The ok designs pass every gate. The rejects fail a gate.\nClearance rejects fail the clearance gate. Twist rejects fail the twist gate.",
)

D8 = (
    "The surviving ok designs hold a mean power between 5.02 and 6.32\nkilowatts (NR-007).",
    "The surviving ok designs hold a mean power between 5.02 and 6.32 kW\n(NR-007).",
)

D9 = (
    "Island 3 carries the winner. Its mean power reads 5.309 kilowatts and\nits end power 5.314 kilowatts (NR-008).",
    "Island 3 carries the winner. Its mean power reads 5.309 kW and\nits end power 5.314 kW (NR-008).",
)

D10 = (
    "The settle state starts the machine at 10.170 radians per second\n(NR-016). The machine accelerates through the relax run.",
    "The settle state starts the machine at 10.170 rad/s (NR-016).\nThe machine accelerates through the relax run.",
)

D11 = (
    "Its window-mean speed reads 13.38 radians per second, 127.772\nrevolutions per minute (NR-029). Its airborne mass reads 25.698\nkilograms (NR-018).",
    "Its window-mean speed reads 13.38 rad/s, 127.772 rpm (NR-029).\nIts airborne mass reads 25.698 kilograms (NR-018).",
)

D12 = (
    "Its window swing reads 0.029 kilowatts on 5.309 kilowatts, half a\npercent (NR-014).",
    "Its window swing reads 0.029 kW on 5.309 kW, half a per cent (NR-014).",
)

D13 = (
    "The winner produces 5.309 kilowatts of mean power with an airborne mass of 25.698 kilograms (NR-008, NR-018).",
    "The winner produces 5.309 kW of mean power with an airborne mass of 25.698 kilograms (NR-008, NR-018).",
)

D14 = (
    "  On 2026-08-13 the evaluator ran 5-kilowatt designs at the 50-kilowatt\n  default gain.",
    "  On 2026-08-13 the evaluator ran 5 kW designs at the 50 kW\n  default gain.",
)

D15 = (
    "  the campaign gain returned 5.18 kilowatts.",
    "  the campaign gain returned 5.18 kW.",
)

D16 = (
    "Its mean power is 5.309 kilowatts and its airborne mass is 25.698 kilograms (NR-008, NR-018).",
    "Its mean power is 5.309 kW and its airborne mass is 25.698 kilograms (NR-008, NR-018).",
)

D17 = (
    "in the decode fields (NR-011).\n\n[Systems block diagram requested: figure-map row 19 (the simulation\nanalysis pipeline instrument). Gate: the pipeline schema extract.]\n\n#### 2.2.2 The evaluator",
    "in the decode fields (NR-011).\n\n#### 2.2.2 The evaluator",
)

T1_OLD = (
    "The objective sentence renames to soft constraint penalties, with the glossary row.\n"
    "No value moves.\n\n## 2. Working notes"
)
T1_NEW = (
    "The objective sentence renames to soft constraint penalties, with the glossary row.\n"
    "No value moves.\n\n"
    "v0.37 pass by @author (2026-10-14).\n"
    "This pass runs the consistency sweep (PL9).\n"
    "The summary line takes the classified fail counts (NR-002), and the unit forms read kW, rad/s, rpm and ground-generation.\n"
    "The phrase forms tighten, and the section 2.2.2 build request retires from the body.\n"
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
        ("D2 abstract candidate form", D2[0], D2[1]),
        ("D3 abstract winner form", D3[0], D3[1]),
        ("D4 keywords ground-generation", D4[0], D4[1]),
        ("D5 classified fail counts", D5[0], D5[1]),
        ("D6 summary bullet kW", D6[0], D6[1]),
        ("D7 statuses openings", D7[0], D7[1]),
        ("D8 NR-007 kW", D8[0], D8[1]),
        ("D9 NR-008 kW pair", D9[0], D9[1]),
        ("D10 settle rad/s", D10[0], D10[1]),
        ("D11 window-mean rad/s rpm", D11[0], D11[1]),
        ("D12 swing kW per cent", D12[0], D12[1]),
        ("D13 implication kW", D13[0], D13[1]),
        ("D14 ledger kW pair", D14[0], D14[1]),
        ("D15 ledger kW", D15[0], D15[1]),
        ("D16 conclusion kW", D16[0], D16[1]),
        ("D17 request bracket retires", D17[0], D17[1]),
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
        ("pin v0.37", "Draft v0.37" in cand_d and "Draft v0.36" not in cand_d),
        ("no kilowatt prints", "kilowatt" not in cand_d),
        ("no radians per second", "radians per second" not in cand_d),
        ("no lone percent word", "percent" not in cand_d),
        ("no spaced ground generation", "ground generation" not in cand_d),
        ("no candidate kite turbine", "candidate kite turbine" not in cand_d),
        ("no row 19 in body", "figure-map row 19" not in cand_d),
        ("classified line present",
         "- Of the 930, 508 designs pass every gate. The other 422 designs read 301 reject, 110 clearance_reject and 11 reject_twist (NR-002)." in cand_d),
        ("unit forms present",
         "5.309 kW" in cand_d and "10.170 rad/s" in cand_d and "127.772 rpm" in cand_d
         and "half a per cent" in cand_d and "ground-generation" in cand_d),
        ("statuses varied",
         "Clearance rejects fail the clearance gate. Twist rejects fail the twist gate." in cand_d),
        ("rename held", "soft constraint penalties" in cand_d and "gate penalties" not in cand_d),
        ("no 14.97 print", "14.97" not in cand_d),
        ("no 14.972 print", "14.972" not in cand_d),
        ("no 3.816 print", "3.816" not in cand_d),
        ("config table held", "| Load constant k | 2.24 N·m/(rad/s)² | NR-015 |" in cand_d),
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
        ("objective block held",
         "`f = mass + 5.0 * max(P_score - 5.0, 0)^2 + 20.0 * (2.5 / FoS_min)^2 + 1.0 * (r / (1 - r))^2`" in cand_d),
        ("tracker v0.37 entry", "v0.37 pass by @author" in cand_t),
        ("tracker history held", "v0.36 pass by @author" in cand_t and "v0.35 pass by @fig-img-diagrams" in cand_t),
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
