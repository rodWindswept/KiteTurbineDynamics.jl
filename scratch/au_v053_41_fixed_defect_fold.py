#!/usr/bin/env python3
"""Draft v0.53 — the rope-break fixed defect (author seat, 2026-10-15).

Folds the routed downstream item (aero receipt, section 4): "section 4.1
rewrites as a fixed defect (@author)". The placement fix landed at
`2bf76a3` (receipt `317d9cd`); the register extension NR-013 ext2 signed
at `fab730a` records the post-fix state.

The grep before the close surfaces the full fix-state set. This pass
reads the scope as: the fixed-defect rewrite at section 4.1 plus the
fix-state references across the draft — the abstract limitation, the
summary bullet, the next-steps item, the conclusion and the
claims-appendix row. Leaving any of them would contradict the fixed
section. Text-only; no value moves.

  D1  version pin v0.52 -> v0.53 (date held at 2026-10-15)
  D2  the reject pair to corrected history
  D3  the mechanism block to the as-run form
  D4  the standing state to the landed close (the ext2 cite)
  D5  the abstract limitation retires (the fix reads landed)
  D6  the summary bullet takes the placed fix
  D7  the next-steps item takes the screening form
  D8  the conclusion takes the placed fix
  D9  the claims-appendix row takes the corrected history
  T1  tracker v0.53 entry

Two-state, fail-closed (mirrors au_v052_trpt_basics_fold.py):
  - builds from `git show HEAD:<path>` (never the working file)
  - asserts every anchor exactly once
  - reconstruction: the candidate equals base plus the declared edits,
    and reverses exactly
  - changed-line census: the difflib opcode list must match exactly
  - STE: rc=0; no category gains; totals held
  - declared token diff must match exactly
  - register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v053_41_fixed_defect_fold.py          # build, gate, report
  python3 scratch/au_v053_41_fixed_defect_fold.py --write  # copy candidates over
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
BASE_D = ROOT / "scratch/au_v053_41_fixed_defect_draft_base.md"
CAND_D = ROOT / "scratch/au_v053_41_fixed_defect_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v053_41_fixed_defect_tracker_base.md"
CAND_T = ROOT / "scratch/au_v053_41_fixed_defect_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v053_41_fixed_defect_fold.log"

# Declared before the run. The pin moves (52 out, 53 in) on the draft.
# The tracker adds its v0.53 entry (53 and the section token 4.1). No
# value token moves; the ext2 cites add no token.
ASSERT_TOKENS = True
EXPECT_D_ADD = {"53": 1}
EXPECT_D_REM = {"52": 1}
EXPECT_T_ADD = {"53": 1, "4.1": 1}
EXPECT_T_REM = {}

# Expected difflib opcode list, base lines -> candidate lines (baked from
# the dry run; the dry run prints the live list when it disagrees).
EXPECT_OPCODES = [
    ("equal", 0, 2, 0, 2),
    ("replace", 2, 3, 2, 3),
    ("equal", 3, 48, 3, 48),
    ("replace", 48, 50, 48, 49),
    ("equal", 50, 80, 49, 79),
    ("replace", 80, 81, 79, 80),
    ("equal", 81, 742, 80, 741),
    ("replace", 742, 743, 741, 742),
    ("equal", 743, 763, 742, 762),
    ("replace", 763, 765, 762, 764),
    ("equal", 765, 767, 764, 766),
    ("replace", 767, 769, 766, 768),
    ("equal", 769, 778, 768, 777),
    ("replace", 778, 781, 777, 780),
    ("equal", 781, 895, 780, 894),
    ("replace", 895, 896, 894, 895),
    ("equal", 896, 945, 895, 944),
    ("replace", 945, 946, 944, 945),
    ("equal", 946, 1022, 945, 1021),
]

D1 = (
    "Internal engineering report. Draft v0.52. Date 2026-10-15.",
    "Internal engineering report. Draft v0.53. Date 2026-10-15.",
)

D2 = (
    "The rapid path rejects all three winners at the rope-break gate\n"
    "(NR-013). The cause is gate placement, not the machine.",
    "The rapid path once rejected all three winners at the rope-break gate\n"
    "(NR-013). The cause was gate placement, not the machine.",
)

D3 = (
    "The evaluator runs the rope-break gate across the relax run as well as\n"
    "the window. The injected transient over-strain trips the gate at once.",
    "The evaluator ran the rope-break gate across the relax run as well as\n"
    "the window. The injected transient over-strain tripped the gate at once.",
)

D4 = (
    "Until it lands, the discrepancy stands. The evaluator arms the\n"
    "rope-break check across the relax and the window. The ruling limits\n"
    "break detection to the measurement window.",
    "The fix has landed. The evaluator arms the\n"
    "rope-break check at the relax boundary (NR-013 ext2). Detection runs\n"
    "on the measurement window only.",
)

D5 = (
    "for steady lift tension across wind speeds remains an assumption. The\n"
    "rope-break gate placement fix stays open.",
    "for steady lift tension across wind speeds remains an assumption.",
)

D6 = (
    "- The ODE path reproduces every recorded winner field (NR-012).\n"
    "  The rapid path awaits its rope-break gate fix (NR-013).",
    "- The ODE path reproduces every recorded winner field (NR-012).\n"
    "  The rapid path takes the rope-break gate placement fix (NR-013 ext2).",
)

D7 = (
    "1. Fix the rapid-path rope-break gate before using the rapid path for screening (NR-013).",
    "1. Use the rapid path for screening under its fixed rope-break gate (NR-013 ext2).",
)

D8 = (
    "Blade integrity is not yet gated, and lifter modulation remains an assumption.\n"
    "The rapid path awaits its rope-break gate fix (NR-013).",
    "Blade integrity is not yet gated, and lifter modulation remains an assumption.\n"
    "The rapid path takes the rope-break gate placement fix (NR-013 ext2).",
)

D9 = (
    "| Instrument fidelity | The cold path reproduces the recorded winner fields. The rapid path rejects all three winners at the rope-break gate. | \u00a74.1 | NR-012, NR-013 |",
    "| Instrument fidelity | The cold path reproduces the recorded winner fields. The rapid path once rejected all three winners at the rope-break gate. The placement fix has landed. | \u00a74.1 | NR-012, NR-013 ext2 |",
)

T1_OLD = (
    "No value moves, and no figure byte moves.\n"
    "\n"
    "## 2. Working notes"
)
T1_NEW = (
    "No value moves, and no figure byte moves.\n"
    "\n"
    "v0.53 pass by @author (2026-10-15).\n"
    "This pass folds the rope-break fixed defect at section 4.1 and its fix-state references across the draft.\n"
    "The evaluator arms the rope-break check at the relax boundary, and detection runs on the measurement window only.\n"
    "The corrected history cites NR-013 ext2.\n"
    "No value moves, and no figure byte moves.\n"
    "\n"
    "## 2. Working notes"
)

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")

PAIRS = [
    ("D1 version pin", D1),
    ("D2 reject pair", D2),
    ("D3 mechanism block", D3),
    ("D4 standing state", D4),
    ("D5 abstract limitation", D5),
    ("D6 summary bullet", D6),
    ("D7 next-steps item", D7),
    ("D8 conclusion", D8),
    ("D9 claims-appendix row", D9),
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

    # --- guards ----------------------------------------------------------
    ops = opcodes(base_d, cand_d)
    say(f"draft opcodes: {ops}")
    b_lines, c_lines = base_d.splitlines(), cand_d.splitlines()

    recon = base_d
    for _, (old, new) in PAIRS:
        recon = recon.replace(old, new, 1)
    rev = cand_d
    for _, (old, new) in reversed(PAIRS):
        rev = rev.replace(new, old, 1)

    guards = [
        ("pin: v0.53 dated 2026-10-15",
         "Draft v0.53" in cand_d and "Draft v0.52" not in cand_d and "Date 2026-10-15" in cand_d),
        ("reconstruction: candidate == base plus declared edits", cand_d == recon),
        ("reverse: base == candidate minus declared edits", rev == base_d),
        ("D2 lands once, old gone", cand_d.count(D2[1]) == 1 and cand_d.count(D2[0]) == 0),
        ("D3 lands once, old gone", cand_d.count(D3[1]) == 1 and cand_d.count(D3[0]) == 0),
        ("D4 lands once, old block gone", cand_d.count(D4[1]) == 1 and cand_d.count(D4[0]) == 0),
        ("D5 lands once, old sentence gone", cand_d.count(D5[1]) == 1 and cand_d.count(D5[0]) == 0),
        ("D6 lands once, old sentence gone", cand_d.count(D6[1]) == 1 and cand_d.count(D6[0]) == 0),
        ("D7 lands once, old item gone", cand_d.count(D7[1]) == 1 and cand_d.count(D7[0]) == 0),
        ("D8 lands once, old sentence gone", cand_d.count(D8[1]) == 1 and cand_d.count(D8[0]) == 0),
        ("D9 lands once, old row gone", cand_d.count(D9[1]) == 1 and cand_d.count(D9[0]) == 0),
        ("line count: base - 1 == 1021", len(c_lines) == len(b_lines) - 1 == 1021),
        ("opcodes exact", ops == EXPECT_OPCODES),
        ("cite count: NR- reads base + 1 (the standing-state ext2 cite)",
         cand_d.count("NR-") == base_d.count("NR-") + 1),
        ("retired form zero: awaits sentence", cand_d.count("The rapid path awaits its rope-break gate fix (NR-013).") == 0),
        ("retired form zero: fix-stays-open", cand_d.count("stays open") == 0),
        ("retired form zero: old reject claim anywhere", cand_d.count("The rapid path rejects all three winners at the rope-break gate") == 0),
        ("retired form zero: old next-steps item", cand_d.count("Fix the rapid-path rope-break gate") == 0),
        ("new form count: placed-fix sentence == 2", cand_d.count("The rapid path takes the rope-break gate placement fix (NR-013 ext2).") == 2),
        ("new form count: screening item == 1", cand_d.count("Use the rapid path for screening under its fixed rope-break gate (NR-013 ext2).") == 1),
        ("new form count: placement-fix-landed == 1", cand_d.count("The placement fix has landed.") == 1),
        ("new form count: ext2 cites == 5", cand_d.count("NR-013 ext2") == 5 and base_d.count("NR-013 ext2") == 0),
        ("value holds: 22 degrees", cand_d.count("22 degrees") == base_d.count("22 degrees")),
        ("value holds: 0.75", cand_d.count("0.75") == base_d.count("0.75")),
        ("value holds: 0.113", cand_d.count("0.113") == base_d.count("0.113")),
        ("value holds: NR-049", cand_d.count("NR-049") == base_d.count("NR-049")),
        ("value holds: NR-050", cand_d.count("NR-050") == base_d.count("NR-050")),
        ("hold: study-is-simulation-only", cand_d.count("The study is simulation-only.") == base_d.count("The study is simulation-only.") == 1),
        ("hold: bridles-outside-model", cand_d.count("outer stiffening bridles sit outside the model.") == base_d.count("outer stiffening bridles sit outside the model.") == 1),
        ("hold: twice sentence",
         cand_d.count("The team has solved this pattern twice on record.") ==
         base_d.count("The team has solved this pattern twice on record.") == 1),
        ("hold: ruling quote",
         cand_d.count("On 2026-09-16 the ruling was: breaks on the measurement window only,") ==
         base_d.count("On 2026-09-16 the ruling was: breaks on the measurement window only,") == 1),
        ("hold: fix-here sentence",
         cand_d.count("The fix here is the same\npattern applied to the evaluator.") ==
         base_d.count("The fix here is the same\npattern applied to the evaluator.") == 1),
        ("hold: never-allows-breaks close",
         cand_d.count("The fix removes false rejections. It never allows breaks.") ==
         base_d.count("The fix removes false rejections. It never allows breaks.") == 1),
        ("hold: lesson close",
         cand_d.count("The lesson stands.") == base_d.count("The lesson stands.") == 1),
        ("hold: default-path close",
         cand_d.count("Every healthy winner reads reject on the default path.") ==
         base_d.count("Every healthy winner reads reject on the default path.") == 1),
        ("hold: cold-flag close",
         cand_d.count("every recorded winner field reproduces (NR-012).") ==
         base_d.count("every recorded winner field reproduces (NR-012).") == 1),
        ("region: 1 Introduction to 3 Results unchanged",
         region(cand_d, "## 1 Introduction", "## 3 Results") ==
         region(base_d, "## 1 Introduction", "## 3 Results")),
        ("region: 3 Results to next steps unchanged",
         region(cand_d, "## 3 Results", "Recommended next steps:") ==
         region(base_d, "## 3 Results", "Recommended next steps:")),
        ("region: next-steps items 2+ to 4.1 unchanged",
         region(cand_d, "2. Add blade root factor-of-safety checks to the structural gate set.", "### 4.1 Evaluation fidelity") ==
         region(base_d, "2. Add blade root factor-of-safety checks to the structural gate set.", "### 4.1 Evaluation fidelity")),
        ("region: 4.1 head to the reject pair unchanged",
         region(cand_d, "### 4.1 Evaluation fidelity", "The rapid path once") ==
         region(base_d, "### 4.1 Evaluation fidelity", "The rapid path rejects")),
        ("region: the twice paragraph unchanged",
         region(cand_d, "The team has solved this pattern twice on record.", "On 2026-09-16 the ruling was:") ==
         region(base_d, "The team has solved this pattern twice on record.", "On 2026-09-16 the ruling was:")),
        ("region: the closes unchanged",
         region(cand_d, "The fix removes false rejections.", "### 4.2 The failure ledger") ==
         region(base_d, "The fix removes false rejections.", "### 4.2 The failure ledger")),
        ("region: 4.2 to 5 unchanged",
         region(cand_d, "### 4.2 The failure ledger", "## 5 Conclusion") ==
         region(base_d, "### 4.2 The failure ledger", "## 5 Conclusion")),
        ("region: conclusion head to the assumption line unchanged",
         region(cand_d, "## 5 Conclusion", "Blade integrity is not yet gated, and lifter modulation remains an assumption.") ==
         region(base_d, "## 5 Conclusion", "Blade integrity is not yet gated, and lifter modulation remains an assumption.")),
        ("region: daisy anchor to 6 Nomenclature unchanged",
         region(cand_d, "The Daisy anchor ties the model to a measured flight reference.", "## 6 Nomenclature") ==
         region(base_d, "The Daisy anchor ties the model to a measured flight reference.", "## 6 Nomenclature")),
        ("region: 6 Nomenclature to Document control unchanged",
         region(cand_d, "## 6 Nomenclature", "## Document control") ==
         region(base_d, "## 6 Nomenclature", "## Document control")),
        ("region: Document control to claims appendix unchanged",
         region(cand_d, "## Document control", "## Appendix: Claims and evidence") ==
         region(base_d, "## Document control", "## Appendix: Claims and evidence")),
        ("region: claims rows before Instrument fidelity unchanged",
         region(cand_d, "## Appendix: Claims and evidence", "| Instrument fidelity |") ==
         region(base_d, "## Appendix: Claims and evidence", "| Instrument fidelity |")),
        ("region: claims rows after Instrument fidelity unchanged",
         region(cand_d, "| Model boundaries |", "## Appendix: Figure provenance") ==
         region(base_d, "| Model boundaries |", "## Appendix: Figure provenance")),
        ("tracker v0.53 entry", "v0.53 pass by @author" in cand_t),
        ("tracker history held",
         "v0.52 pass by @author" in cand_t and "v0.51 pass by @fig-img-diagrams" in cand_t
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
