#!/usr/bin/env python3
"""Draft v0.50 — the kMppt plain pass (author seat, 2026-10-15).

Folds the author leg of the founder kMppt ask as the routing record
scopes it: "a plainer pass on the structural-side sentence"
(queue page at `4a7cc8d`; seat page item 2; the aero-worker inventory
"Structural sentence pass"). Target: the section 2.3 structural-side
block of the load story.

  D1  version pin v0.49 -> v0.50 (date held at 2026-10-15)
  D2  the beam-sizing sentence: plainer parse, claims held
  D3  the lull sentence: the plainer word (harmless), claims held
  D4  the ease refusal: actor-side plain form, claims held
  T1  tracker v0.50 entry

Held byte-identical: the block's frame sentence, the helix-force
sentence and the twist sentence; every signed value form
("twice the nominal load", "1278 N/vertex", "87.9", "78.8") and all
three NR-048 cites. No era cite sits anywhere in the draft; the
era-fit flag stays parked.

Two-state, fail-closed (mirrors au_v049_rekeys_fold.py):
  - builds from `git show HEAD:<path>` (never the working file)
  - asserts every anchor exactly once
  - changed-line census: only the declared lines may differ
  - STE: rc=0; no category gains; totals held
  - declared token diff must match exactly
  - register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v050_kmppt_plain_fold.py          # build, gate, report
  python3 scratch/au_v050_kmppt_plain_fold.py --write  # copy candidates over
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
BASE_D = ROOT / "scratch/au_v050_draft_base.md"
CAND_D = ROOT / "scratch/au_v050_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v050_tracker_base.md"
CAND_T = ROOT / "scratch/au_v050_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v050_kmppt_plain_fold.log"

# Declared before the run. The pin moves (49 out, 50 in) on the draft
# and the tracker. No value token moves.
ASSERT_TOKENS = True
EXPECT_D_ADD = {"50": 1}
EXPECT_D_REM = {"49": 1}
EXPECT_T_ADD = {"50": 1}
EXPECT_T_REM = {}

D1 = (
    "Internal engineering report. Draft v0.49. Date 2026-10-15.",
    "Internal engineering report. Draft v0.50. Date 2026-10-15.",
)

D2 = (
    "The beam sizes on a bounded generator load step, twice the nominal load (NR-048).",
    "The team sizes the beam for a bounded generator load step: twice the nominal load (NR-048).",
)

D3 = (
    "The low-wind lull is benign under the load law.",
    "A low-wind lull is harmless under the load law.",
)

D4 = (
    "The record refuses k easing as the high-wind substitute.",
    "The team refuses to ease k as the high-wind substitute.",
)

T1_OLD = (
    "No value moves, and no figure byte moves.\n"
    "\n"
    "## 2. Working notes"
)
T1_NEW = (
    "No value moves, and no figure byte moves.\n"
    "\n"
    "v0.50 pass by @author (2026-10-15).\n"
    "This pass gives the structural side of the load story a plainer form.\n"
    "The beam-sizing sentence, the lull sentence and the refusal sentence take plainer forms.\n"
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


def changed_lines(base, cand):
    b, c = base.splitlines(), cand.splitlines()
    if len(b) != len(c):
        return None
    return [i + 1 for i, (x, y) in enumerate(zip(b, c)) if x != y]


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
    pairs = [("D1 version pin", D1[0], D1[1]), ("D2 beam sizing", D2[0], D2[1]),
             ("D3 lull", D3[0], D3[1]), ("D4 ease refusal", D4[0], D4[1])]
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
    ch_d = changed_lines(base_d, cand_d)
    INSERT_T = (
        "\nv0.50 pass by @author (2026-10-15).\n"
        "This pass gives the structural side of the load story a plainer form.\n"
        "The beam-sizing sentence, the lull sentence and the refusal sentence take plainer forms.\n"
        "No value moves, and no figure byte moves.\n"
    )
    guards = [
        ("pin: v0.50 dated 2026-10-15",
         "Draft v0.50" in cand_d and "Draft v0.49" not in cand_d and "Date 2026-10-15" in cand_d),
        ("changed-line census: draft exactly 3, 318, 320, 321",
         ch_d == [3, 318, 320, 321]),
        ("D2 lands once, old form gone",
         cand_d.count(D2[1]) == 1 and cand_d.count(D2[0]) == 0),
        ("D3 lands once, old form gone",
         cand_d.count(D3[1]) == 1 and cand_d.count(D3[0]) == 0),
        ("D4 lands once, old form gone",
         cand_d.count(D4[1]) == 1 and cand_d.count(D4[0]) == 0),
        ("held: frame sentence", "The load choice also has a structural side." in cand_d),
        ("held: helix force sentence",
         "The top-segment helix force reads about 1278 N/vertex (NR-048)." in cand_d),
        ("held: twist sentence",
         "The rotor spins up to 87.9° of twist against the 78.8° collapse limit (NR-048)." in cand_d),
        ("value holds: NR-048 count", cand_d.count("NR-048") == base_d.count("NR-048") == 3),
        ("value holds: twice the nominal load",
         cand_d.count("twice the nominal load") == base_d.count("twice the nominal load") == 1),
        ("value holds: 1278", cand_d.count("1278") == base_d.count("1278")),
        ("value holds: 87.9", cand_d.count("87.9") == base_d.count("87.9")),
        ("value holds: 78.8", cand_d.count("78.8") == base_d.count("78.8")),
        ("value holds: 2.24", cand_d.count("2.24") == base_d.count("2.24")),
        ("value holds: 36.4", cand_d.count("36.4") == base_d.count("36.4")),
        ("value holds: 24.3", cand_d.count("24.3") == base_d.count("24.3")),
        ("no era cite: mppt reads zero",
         len(re.findall(r"(?i)mppt", cand_d)) == 0),
        ("region: block lead to 2.4 unchanged",
         region(cand_d, "#### 2.2.2 The evaluator", "The load choice also has a structural side.")
         == region(base_d, "#### 2.2.2 The evaluator", "The load choice also has a structural side.")),
        ("region: block tail to 2.4 unchanged",
         region(cand_d, "The rotor spins up to 87.9° of twist against the 78.8° collapse limit (NR-048).",
                "### 2.4 The campaign")
         == region(base_d, "The rotor spins up to 87.9° of twist against the 78.8° collapse limit (NR-048).",
                   "### 2.4 The campaign")),
        ("region: 3 Results to 4 Discussion unchanged",
         region(cand_d, "## 3 Results", "## 4 Discussion")
         == region(base_d, "## 3 Results", "## 4 Discussion")),
        ("region: 4 Discussion to 5 Conclusion unchanged",
         region(cand_d, "## 4 Discussion", "## 5 Conclusion")
         == region(base_d, "## 4 Discussion", "## 5 Conclusion")),
        ("region: 5 Conclusion to 6 Nomenclature unchanged",
         region(cand_d, "## 5 Conclusion", "## 6 Nomenclature")
         == region(base_d, "## 5 Conclusion", "## 6 Nomenclature")),
        ("region: 6 Nomenclature to provenance appendix unchanged",
         region(cand_d, "## 6 Nomenclature", "## Appendix: Figure provenance")
         == region(base_d, "## 6 Nomenclature", "## Appendix: Figure provenance")),
        ("tracker v0.50 entry", "v0.50 pass by @author" in cand_t),
        ("tracker history held",
         "v0.49 pass by @author" in cand_t and "v0.48 pass by @fig-img-diagrams" in cand_t
         and "v0.47 pass by @author" in cand_t),
        ("tracker insertion carries no old form",
         INSERT_T in cand_t and "benign" not in INSERT_T and "beam sizes" not in INSERT_T),
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

    # --- citation gate -----------------------------------------------------
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
