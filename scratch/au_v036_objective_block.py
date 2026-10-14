#!/usr/bin/env python3
"""Draft v0.36 — the round-4 objective block and the soft constraint rename (author seat, 2026-10-14).

Applies to the tip (ef36c6c), fail-closed, two-state (base read from
`git show HEAD:<path>`; never from the working file):

  D1  version pin: v0.35 -> v0.36, date held 2026-10-14
  D2  section 2.4 rename: "the gate penalties" -> "the soft constraint penalties"
  D3  section 2.4: the objective block lands after the objective definition
      (the unit sentence, the scoring chain, the three soft constraint
      penalty forms with weights and thresholds, the stationarity add-on,
      and the reject placement; cites NR-046)
  G1  glossary status: PREP v14 -> PREP v15
  G2  glossary rename: the kg-equivalent row takes "soft constraint penalties"
  G3  glossary delta v15 entry
  T1  tracker v0.36 entry

Gates: STE per file (rc=0; total must not exceed base; no category
gains), declared token diff (draft, tracker, glossary), the register-seat
citation checker. --write copies candidates over the repo files only
when every gate is green.

Usage:
  python3 scratch/au_v036_objective_block.py          # build, gate, report
  python3 scratch/au_v036_objective_block.py --write  # copy candidates over repo files
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
GLOSS_REL = "docs/reporting/glossary-candidates.md"
REG = "docs/reporting/numbers-register.md"
BASE_D = ROOT / "scratch/au_v036_draft_base.md"
CAND_D = ROOT / "scratch/au_v036_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v036_tracker_base.md"
CAND_T = ROOT / "scratch/au_v036_tracker_candidate.md"
BASE_G = ROOT / "scratch/au_v036_gloss_base.md"
CAND_G = ROOT / "scratch/au_v036_gloss_candidate.md"
LOG_P = ROOT / "scratch/au_v036_objective_block.log"

# Declared before the run — the full push delta against the tip.
# First pass runs with ASSERT_TOKENS False to print the live sets; the
# sets are baked here and the second pass asserts them exactly.
ASSERT_TOKENS = True
EXPECT_D_ADD = {
    "0": 2, "0.20": 1, "1": 2, "1.0": 2, "10.0": 1, "2": 3,
    "2.5": 2, "20": 1, "20.0": 1, "36": 1, "5.0": 3,
}
EXPECT_D_REM = {"35": 1}
EXPECT_T_ADD = {"2.4": 1, "36": 1}
EXPECT_T_REM = {}
EXPECT_G_ADD = {"2.4": 1}
EXPECT_G_REM = {}

D1 = (
    "Internal engineering report. Draft v0.35. Date 2026-10-14.",
    "Internal engineering report. Draft v0.36. Date 2026-10-14.",
)

D2 = (
    "The campaign minimizes a kg-equivalent objective score: the airborne mass plus the gate penalties.",
    "The campaign minimizes a kg-equivalent objective score: the airborne mass plus the soft constraint penalties.",
)

D3_OLD = (
    "The objective score is not the physical airborne mass.\n"
    "\n"
    "The differential-evolution campaign fixed the configuration below."
)

D3_NEW = (
    "The objective score is not the physical airborne mass.\n"
    "\n"
    "One kilogram of airborne mass adds 1.0 to the score (NR-046).\n"
    "The penalty charges read in kg-equivalent.\n"
    "\n"
    "The score builds along one chain.\n"
    "The chain runs genome, decoder, builder, evaluator, window statistics, gate status, soft constraint penalties, score and rank.\n"
    "\n"
    "The score adds three soft constraint penalties to the airborne mass (NR-046):\n"
    "`f = mass + 5.0 * max(P_score - 5.0, 0)^2 + 20.0 * (2.5 / FoS_min)^2 + 1.0 * (r / (1 - r))^2`\n"
    "with `r = min(twist_ratio, 1)`, plus the stationarity add-on `10.0 * max(0, swing - 0.20)`.\n"
    "\n"
    "The over-power charge reads P_score, the end power, against the 5.0 kW ceiling (NR-046).\n"
    "The utilisation charge reads the window-minimum factor of safety against the 2.5 floor (NR-046).\n"
    "The twist charge reads the worst segment twist ratio against the crossing limit (NR-046).\n"
    "The stationarity add-on reads the window swing against 20 per cent (NR-046).\n"
    "\n"
    "Every charge is continuous. None is step-like (NR-046).\n"
    "\n"
    "Rejected designs carry no score.\n"
    "The evaluator carries Inf for a rejected design.\n"
    "The runner stamps the search cost `1e9` on every non-ok design (NR-046).\n"
    "No reject ranks above an ok design.\n"
    "The search cannot trade power or safety against mass.\n"
    "\n"
    "The differential-evolution campaign fixed the configuration below."
)

G1 = (
    "**Status** PREP v14, numbers-free by construction (no measurement values, no",
    "**Status** PREP v15, numbers-free by construction (no measurement values, no",
)

G2 = (
    "| kg-equivalent | The unit the objective score reads in: the airborne mass plus the gate penalties, read as a mass.",
    "| kg-equivalent | The unit the objective score reads in: the airborne mass plus the soft constraint penalties, read as a mass.",
)

G3 = (
    "  Track D rewrites the three at ratification. No other change.",
    "  Track D rewrites the three at ratification. No other change.\n"
    "\n"
    "- **v15 (2026-10-14):** the kg-equivalent row takes the renamed\n"
    "  form, \"soft constraint penalties\". The rename lands with the draft\n"
    "  section 2.4 sentence, so the term gate reads one form. No other\n"
    "  change.",
)

T1_OLD = "No drawn value and no kit byte moves.\n\n## 2. Working notes"
T1_NEW = (
    "No drawn value and no kit byte moves.\n\n"
    "v0.36 pass by @author (2026-10-14).\n"
    "This pass folds the round-4 objective block at section 2.4.\n"
    "The block states the scoring chain, the three soft constraint penalty forms and the reject placement from NR-046.\n"
    "The objective sentence renames to soft constraint penalties, with the glossary row.\n"
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
    base_g = run(["git", "show", f"HEAD:{GLOSS_REL}"]).stdout
    BASE_D.write_text(base_d)
    BASE_T.write_text(base_t)
    BASE_G.write_text(base_g)
    say(f"base draft sha256: {sh256(BASE_D)}")
    say(f"base tracker sha256: {sh256(BASE_T)}")
    say(f"base gloss sha256: {sh256(BASE_G)}")

    # --- build the candidates ------------------------------------------
    cand_d = base_d
    pairs = [
        ("D1 version pin", D1[0], D1[1]),
        ("D2 section 2.4 rename", D2[0], D2[1]),
        ("D3 objective block", D3_OLD, D3_NEW),
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

    cand_g = base_g
    gpairs = [
        ("G1 glossary status", G1[0], G1[1]),
        ("G2 glossary rename", G2[0], G2[1]),
        ("G3 glossary delta", G3[0], G3[1]),
    ]
    for name, old, new in gpairs:
        c = cand_g.count(old)
        if c != 1:
            say(f"ANCHOR FAIL {name}: count={c}")
            LOG_P.write_text("\n".join(log))
            sys.exit(1)
        cand_g = cand_g.replace(old, new, 1)
        say(f"ok {name}")

    # --- guards ---------------------------------------------------------
    guards = [
        ("pin v0.36", "Draft v0.36" in cand_d and "Draft v0.35" not in cand_d),
        ("rename in draft", "the airborne mass plus the soft constraint penalties." in cand_d
         and "gate penalties" not in cand_d),
        ("block unit line", "One kilogram of airborne mass adds 1.0 to the score (NR-046)." in cand_d),
        ("block chain", "The score builds along one chain." in cand_d
         and "window statistics, gate status, soft constraint penalties, score and rank." in cand_d),
        ("block form", "`f = mass + 5.0 * max(P_score - 5.0, 0)^2 + 20.0 * (2.5 / FoS_min)^2 + 1.0 * (r / (1 - r))^2`" in cand_d
         and "10.0 * max(0, swing - 0.20)`" in cand_d),
        ("block charges", "The over-power charge reads P_score, the end power, against the 5.0 kW ceiling (NR-046)." in cand_d
         and "The stationarity add-on reads the window swing against 20 per cent (NR-046)." in cand_d),
        ("block rejects", "Rejected designs carry no score." in cand_d
         and "No reject ranks above an ok design." in cand_d
         and "The search cannot trade power or safety against mass." in cand_d),
        ("no 14.97 print", "14.97" not in cand_d),
        ("no 14.972 print", "14.972" not in cand_d),
        ("no 3.816 print", "3.816" not in cand_d),
        ("config table held", "| Load constant k | 2.24 N·m/(rad/s)² | NR-015 |" in cand_d),
        ("section 2.5 intact", "The rapid path pre-solves a static state and starts from it." in cand_d),
        ("markers held",
         all(m in cand_d for m in [
             "figure-map row 2 (system anatomy plate",
             "figure-map row 6 (ring utilisation plate",
             "figure-map row 7 (twist limit plate",
             "figure-map row 9 (machine evolution strip",
             "figure-map row 19 (the simulation",
             "figure-map row 20 (the levers landscape",
             "figure-map row 21 (the parameter atlas",
         ])),
        ("glossary rename", "soft constraint penalties" in cand_g and "gate penalties" not in cand_g),
        ("glossary v15", "- **v15 (2026-10-14):**" in cand_g and "**Status** PREP v15" in cand_g),
        ("glossary rows held", "| Daisy |" in cand_g and "| fitness |" in cand_g),
        ("tracker v0.36 entry", "v0.36 pass by @author" in cand_t),
        ("tracker history held", "v0.35 pass by @fig-img-diagrams" in cand_t and "v0.34 pass by @author" in cand_t),
        ("tracker no-change line", "No drawn value and no kit byte moves." in cand_t),
    ]
    for label, ok in guards:
        say(f"guard {label}: {'ok' if ok else 'FAIL'}")
        if not ok:
            LOG_P.write_text("\n".join(log))
            sys.exit(1)

    CAND_D.write_text(cand_d)
    CAND_T.write_text(cand_t)
    CAND_G.write_text(cand_g)
    say(f"candidate draft sha256: {sh256(CAND_D)}")
    say(f"candidate tracker sha256: {sh256(CAND_T)}")
    say(f"candidate gloss sha256: {sh256(CAND_G)}")

    # --- STE gates ------------------------------------------------------
    rc_db, w_db, tot_db, cats_db = lint(BASE_D)
    rc_dc, w_dc, tot_dc, cats_dc = lint(CAND_D)
    rc_tb, w_tb, tot_tb, cats_tb = lint(BASE_T)
    rc_tc, w_tc, tot_tc, cats_tc = lint(CAND_T)
    rc_gb, w_gb, tot_gb, cats_gb = lint(BASE_G)
    rc_gc, w_gc, tot_gc, cats_gc = lint(CAND_G)
    say(f"STE draft base: rc={rc_db} words={w_db} total={tot_db} {cats_db}")
    say(f"STE draft candidate: rc={rc_dc} words={w_dc} total={tot_dc} {cats_dc}")
    say(f"STE tracker base: rc={rc_tb} words={w_tb} total={tot_tb} {cats_tb}")
    say(f"STE tracker candidate: rc={rc_tc} words={w_tc} total={tot_tc} {cats_tc}")
    say(f"STE gloss base: rc={rc_gb} words={w_gb} total={tot_gb} {cats_gb}")
    say(f"STE gloss candidate: rc={rc_gc} words={w_gc} total={tot_gc} {cats_gc}")
    gains_d = {k: v - cats_db.get(k, 0) for k, v in cats_dc.items() if v > cats_db.get(k, 0) and not k.startswith("_")}
    gains_t = {k: v - cats_tb.get(k, 0) for k, v in cats_tc.items() if v > cats_tb.get(k, 0) and not k.startswith("_")}
    gains_g = {k: v - cats_gb.get(k, 0) for k, v in cats_gc.items() if v > cats_gb.get(k, 0) and not k.startswith("_")}
    if gains_d:
        say(f"draft category gains: {gains_d}")
    if gains_t:
        say(f"tracker category gains: {gains_t}")
    if gains_g:
        say(f"gloss category gains: {gains_g}")
    ste_ok = (rc_dc == 0 and rc_tc == 0 and rc_gc == 0
              and None not in (tot_db, tot_dc, tot_tb, tot_tc, tot_gb, tot_gc)
              and tot_dc <= tot_db and tot_tc <= tot_tb and tot_gc <= tot_gb
              and not gains_d and not gains_t and not gains_g)

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

    tga, tgb = Counter(TOK.findall(base_g)), Counter(TOK.findall(cand_g))
    add_g, rem_g = dict(tgb - tga), dict(tga - tgb)
    if ASSERT_TOKENS:
        tok_ok_g = (add_g == EXPECT_G_ADD and rem_g == EXPECT_G_REM)
    else:
        tok_ok_g = True
    say(f"gloss token delta add: {dict(sorted(add_g.items()))}")
    say(f"gloss token delta rem: {dict(sorted(rem_g.items()))}")
    say(f"gloss token check: {'PASS' if tok_ok_g else 'FAIL'}")

    # --- citation gate --------------------------------------------------
    r = run(["python3", "scratch/sv_check_draft_citations.py", str(CAND_D), REG])
    cite_ok = r.returncode == 0
    for line in r.stdout.splitlines()[:8]:
        say(line)
    say(f"citation checker: rc={r.returncode}")

    all_ok = ste_ok and tok_ok_d and tok_ok_t and tok_ok_g and cite_ok
    say(f"GATES: ste={'pass' if ste_ok else 'fail'} tokens_d={'pass' if tok_ok_d else 'fail'} "
        f"tokens_t={'pass' if tok_ok_t else 'fail'} tokens_g={'pass' if tok_ok_g else 'fail'} "
        f"citations={'pass' if cite_ok else 'fail'}")
    LOG_P.write_text("\n".join(log))

    if write:
        if not all_ok:
            say("--write refused: gates not green")
            sys.exit(1)
        shutil.copyfile(CAND_D, ROOT / DRAFT_REL)
        shutil.copyfile(CAND_T, ROOT / TRACKER_REL)
        shutil.copyfile(CAND_G, ROOT / GLOSS_REL)
        say(f"draft written: {DRAFT_REL}")
        say(f"tracker written: {TRACKER_REL}")
        say(f"gloss written: {GLOSS_REL}")


if __name__ == "__main__":
    main()
