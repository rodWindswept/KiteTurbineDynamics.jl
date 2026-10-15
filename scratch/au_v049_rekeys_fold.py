#!/usr/bin/env python3
"""Draft v0.49 — the re-keys (author seat, 2026-10-15).

Folds the founder's two term notes of 2026-10-15 at the author surfaces,
keyed on the figures landing (`6f19eee`, the lifting-bridles relabel;
receipt docs/reporting/room-responses/
figures-images-diagrams-2026-10-15-lifting-bridles-relabel.md):

  D1  version pin v0.48 -> v0.49, date refreshed to the pass day
  D2  the load-path sentence: "down the bridles" -> "down the lifting
      bridles" (section 3.3)
  D3  the section 3.3 marker: the winner-form re-key
  D4  the appendix exhibit row: the winner-form re-key
  D5  the appendix caption lead: the winner-form re-key
  C1  captions.md: "Three bridles run" -> "Three lifting bridles run"
  C2  captions-draft.md: the same caption form
  T1  tracker v0.49 entry

Routing: the figures receipt, section 7, "@author: the caption text
(two kit files), the draft caption embed, the section 2.1 sentence, the
section 3.3 marker and the appendix exhibit name"; the science-validator
scope read (re-key sites L484, L946, L994); the map row 10 title already
took the winner form at the figures pass.

Two-state, fail-closed (mirrors au_v047_round6_fold.py):
  - builds from `git show HEAD:<path>` (never the working file)
  - asserts every anchor exactly once
  - changed-line census: only the declared lines may differ
  - STE: rc=0; no category gains; totals held
  - declared token diff must match exactly
  - register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v049_rekeys_fold.py          # build, gate, report
  python3 scratch/au_v049_rekeys_fold.py --write  # copy candidates over
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
CAP_REL = "docs/reporting/figures/system-anatomy/captions.md"
CAPD_REL = "docs/reporting/figures/system-anatomy/captions-draft.md"
REG = "docs/reporting/numbers-register.md"
BASE_D = ROOT / "scratch/au_v049_draft_base.md"
CAND_D = ROOT / "scratch/au_v049_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v049_tracker_base.md"
CAND_T = ROOT / "scratch/au_v049_tracker_candidate.md"
BASE_C = ROOT / "scratch/au_v049_captions_base.md"
CAND_C = ROOT / "scratch/au_v049_captions_candidate.md"
BASE_CD = ROOT / "scratch/au_v049_captionsdraft_base.md"
CAND_CD = ROOT / "scratch/au_v049_captionsdraft_candidate.md"
LOG_P = ROOT / "scratch/au_v049_rekeys_fold.log"

# Declared before the run. The pin moves (48 out, 49 in) on the draft
# and the tracker. No other token moves on any of the four files.
ASSERT_TOKENS = True
EXPECT_D_ADD = {"49": 1}
EXPECT_D_REM = {"48": 1}
EXPECT_T_ADD = {"49": 1}
EXPECT_T_REM = {}
EXPECT_C_ADD = {}
EXPECT_C_REM = {}
EXPECT_CD_ADD = {}
EXPECT_CD_REM = {}

D1 = (
    "Internal engineering report. Draft v0.48. Date 2026-10-14.",
    "Internal engineering report. Draft v0.49. Date 2026-10-15.",
)

D2 = (
    "bearing, and down the bridles to the main rotor.",
    "bearing, and down the lifting bridles to the main rotor.",
)

D3 = (
    "[Figure seated: figure-map row 10 (machine winner hero, slug `machine-winner-hero`). "
    "Values cite NR-011, NR-017, NR-021, NR-022 and NR-043.]",
    "[Figure seated: figure-map row 10 (machine winner, slug `machine-winner-hero`). "
    "Values cite NR-011, NR-017, NR-021, NR-022 and NR-043.]",
)

D4 = (
    "| Machine winner hero | `strip-extract-2026-10-09-best-so-far` \u00b7 `pair-extract-2026-10-08-winner-ops` | "
    "NR-011, NR-017, NR-021, NR-022, NR-043 | `1af63fc` | `post-95c385d_wind-authority` |",
    "| Machine winner | `strip-extract-2026-10-09-best-so-far` \u00b7 `pair-extract-2026-10-08-winner-ops` | "
    "NR-011, NR-017, NR-021, NR-022, NR-043 | `1af63fc` | `post-95c385d_wind-authority` |",
)

D5 = (
    "Machine winner hero:",
    "Machine winner:",
)

C1 = (
    "the sky anchor and the cyan line, to the lift bearing. Three bridles run\n"
    "from the bearing into the main rotor.",
    "the sky anchor and the cyan line, to the lift bearing. Three lifting bridles run\n"
    "from the bearing into the main rotor.",
)

C2 = (
    "sky anchor and the cyan line, to the lift bearing. Three bridles run from\n"
    "the bearing into the main rotor.",
    "sky anchor and the cyan line, to the lift bearing. Three lifting bridles run from\n"
    "the bearing into the main rotor.",
)

T1_OLD = (
    "The re-cut takes the chain label \"lifting bridles (three)\" (figure-map row 2; the founder note of 2026-10-15).\n"
    "No value moves.\n"
    "\n"
    "## 2. Working notes"
)
T1_NEW = (
    "The re-cut takes the chain label \"lifting bridles (three)\" (figure-map row 2; the founder note of 2026-10-15).\n"
    "No value moves.\n"
    "\n"
    "v0.49 pass by @author (2026-10-15).\n"
    "This pass re-keys the two founder term notes at the copy surfaces.\n"
    "The two system-anatomy caption files and the draft lift-path sentence take the lifting-bridles form.\n"
    "The figure marker, the appendix exhibit row and the caption lead take the winner form.\n"
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
    base_c = run(["git", "show", f"HEAD:{CAP_REL}"]).stdout
    base_cd = run(["git", "show", f"HEAD:{CAPD_REL}"]).stdout
    BASE_D.write_text(base_d)
    BASE_T.write_text(base_t)
    BASE_C.write_text(base_c)
    BASE_CD.write_text(base_cd)
    say(f"base draft sha256: {sh256(BASE_D)}")
    say(f"base tracker sha256: {sh256(BASE_T)}")
    say(f"base captions sha256: {sh256(BASE_C)}")
    say(f"base captions-draft sha256: {sh256(BASE_CD)}")

    # --- build the candidates -------------------------------------------
    cand_d = base_d
    pairs = [("D1 version pin", D1[0], D1[1]), ("D2 load path", D2[0], D2[1]),
             ("D3 marker", D3[0], D3[1]), ("D4 appendix row", D4[0], D4[1]),
             ("D5 caption lead", D5[0], D5[1])]
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

    cand_c = base_c
    c = cand_c.count(C1[0])
    if c != 1:
        say(f"ANCHOR FAIL C1 captions: count={c}")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    cand_c = cand_c.replace(C1[0], C1[1], 1)
    say("ok C1 captions caption form")

    cand_cd = base_cd
    c = cand_cd.count(C2[0])
    if c != 1:
        say(f"ANCHOR FAIL C2 captions-draft: count={c}")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    cand_cd = cand_cd.replace(C2[0], C2[1], 1)
    say("ok C2 captions-draft caption form")

    # --- guards ----------------------------------------------------------
    ch_d = changed_lines(base_d, cand_d)
    ch_c = changed_lines(base_c, cand_c)
    ch_cd = changed_lines(base_cd, cand_cd)
    INSERT_T = (
        "\nv0.49 pass by @author (2026-10-15).\n"
        "This pass re-keys the two founder term notes at the copy surfaces.\n"
        "The two system-anatomy caption files and the draft lift-path sentence take the lifting-bridles form.\n"
        "The figure marker, the appendix exhibit row and the caption lead take the winner form.\n"
        "No value moves, and no figure byte moves.\n"
    )
    hero_b = len(re.findall(r"(?i)hero", base_d))
    hero_c = len(re.findall(r"(?i)hero", cand_d))
    hero_line = [ln for ln in cand_d.splitlines() if re.search(r"(?i)hero", ln)]
    markers_b = re.findall(r"^\[Figure seated:.*$", base_d, re.M)
    markers_c = re.findall(r"^\[Figure seated:.*$", cand_d, re.M)
    sec33 = region(cand_d, "### 3.3 The winner", "### 3.4 The levers of Performance")
    guards = [
        ("pin: v0.49 dated 2026-10-15",
         "Draft v0.49" in cand_d and "Draft v0.48" not in cand_d and "Date 2026-10-15" in cand_d),
        ("changed-line census: draft exactly 3, 484, 539, 946, 994",
         ch_d == [3, 484, 539, 946, 994]),
        ("load path: old form gone, new form once",
         cand_d.count("down the bridles") == 0 and cand_d.count("down the lifting bridles") == 1),
        ("hero census: base 4, candidate 1", hero_b == 4 and hero_c == 1),
        ("candidate hero hit sits in the slug",
         len(hero_line) == 1 and "machine-winner-hero" in hero_line[0]),
        ("'Machine winner hero' reads zero",
         cand_d.count("Machine winner hero") == 0 and cand_d.count("machine winner hero") == 0),
        ("winner form lands: marker once", cand_d.count(D3[1]) == 1 and cand_d.count(D3[0]) == 0),
        ("winner form lands: appendix row once", cand_d.count(D4[1]) == 1 and cand_d.count(D4[0]) == 0),
        ("winner form lands: caption lead once",
         cand_d.count("Machine winner:\n") == 1 and cand_d.count("Machine winner hero:") == 0),
        ("seven seated markers hold", len(markers_c) == 7 and len(markers_b) == 7),
        ("hold: stiffening bridles", "outer stiffening bridles sit outside the model." in cand_d),
        ("hold: tether or a bridle", "like a tether or a bridle." in cand_d),
        ("hold: blade bridling", "tether-to-blade bridling" in cand_d),
        ("value holds: 4.580", cand_d.count("4.580") == base_d.count("4.580")),
        ("value holds: 25.698", cand_d.count("25.698") == base_d.count("25.698")),
        ("value holds: 5.309", cand_d.count("5.309") == base_d.count("5.309")),
        ("value holds: 508", cand_d.count("508") == base_d.count("508")),
        ("value holds: 15.033", cand_d.count("15.033") == base_d.count("15.033")),
        ("value holds: 930", cand_d.count("930") == base_d.count("930")),
        ("section 3.3 carries the marker and the sentence",
         D3[1] in sec33 and "down the lifting bridles" in sec33),
        ("region 1 to 3.3 unchanged",
         region(cand_d, "## 1 Introduction", "### 3.3 The winner")
         == region(base_d, "## 1 Introduction", "### 3.3 The winner")),
        ("region 3.4 to 3.6 unchanged",
         region(cand_d, "### 3.4 The levers of Performance", "### 3.6 Design implications")
         == region(base_d, "### 3.4 The levers of Performance", "### 3.6 Design implications")),
        ("region 3.6 to 4.2 unchanged",
         region(cand_d, "### 3.6 Design implications", "### 4.2 The failure ledger")
         == region(base_d, "### 3.6 Design implications", "### 4.2 The failure ledger")),
        ("region 4.2 to 4.3 unchanged",
         region(cand_d, "### 4.2 The failure ledger", "### 4.3 Model boundaries")
         == region(base_d, "### 4.2 The failure ledger", "### 4.3 Model boundaries")),
        ("region 4.3 to 5 unchanged",
         region(cand_d, "### 4.3 Model boundaries", "## 5 Conclusion")
         == region(base_d, "### 4.3 Model boundaries", "## 5 Conclusion")),
        ("region 5 to 6 unchanged",
         region(cand_d, "## 5 Conclusion", "## 6 Nomenclature")
         == region(base_d, "## 5 Conclusion", "## 6 Nomenclature")),
        ("region 6 to the provenance appendix unchanged",
         region(cand_d, "## 6 Nomenclature", "## Appendix: Figure provenance")
         == region(base_d, "## 6 Nomenclature", "## Appendix: Figure provenance")),
        ("changed-line census: captions exactly 39", ch_c == [39]),
        ("changed-line census: captions-draft exactly 23", ch_cd == [23]),
        ("captions: old form gone, new form once",
         cand_c.count("Three bridles run") == 0
         and cand_c.count("Three lifting bridles run\nfrom the bearing into the main rotor.") == 1),
        ("captions-draft: old form gone, new form once",
         cand_cd.count("Three bridles run") == 0
         and cand_cd.count("Three lifting bridles run from\nthe bearing into the main rotor.") == 1),
        ("captions: relabel note holds", "The caption text re-keys at the author pass." in cand_c),
        ("captions: ledger strings held", "lifting bridles (three)" in
         (ROOT / "docs/reporting/figures/system-anatomy/label-ledger.txt").read_text()),
        ("tracker v0.49 entry", "v0.49 pass by @author" in cand_t),
        ("tracker history held",
         "v0.48 pass by @fig-img-diagrams" in cand_t and "v0.47 pass by @author" in cand_t),
        ("tracker hero records untouched",
         len(re.findall(r"(?i)hero", cand_t)) == len(re.findall(r"(?i)hero", base_t))),
        ("tracker insertion carries no old form",
         INSERT_T in cand_t and "winner hero" not in INSERT_T
         and "bridles (three)" not in INSERT_T and "hub" not in INSERT_T.lower()),
    ]
    for label, ok in guards:
        say(f"guard {label}: {'ok' if ok else 'FAIL'}")
        if not ok:
            LOG_P.write_text("\n".join(log))
            sys.exit(1)

    CAND_D.write_text(cand_d)
    CAND_T.write_text(cand_t)
    CAND_C.write_text(cand_c)
    CAND_CD.write_text(cand_cd)
    say(f"candidate draft sha256: {sh256(CAND_D)}")
    say(f"candidate tracker sha256: {sh256(CAND_T)}")
    say(f"candidate captions sha256: {sh256(CAND_C)}")
    say(f"candidate captions-draft sha256: {sh256(CAND_CD)}")

    # --- STE gates --------------------------------------------------------
    rc_db, w_db, tot_db, cats_db = lint(BASE_D)
    rc_dc, w_dc, tot_dc, cats_dc = lint(CAND_D)
    rc_tb, w_tb, tot_tb, cats_tb = lint(BASE_T)
    rc_tc, w_tc, tot_tc, cats_tc = lint(CAND_T)
    rc_cb, w_cb, tot_cb, cats_cb = lint(BASE_C)
    rc_cc, w_cc, tot_cc, cats_cc = lint(CAND_C)
    rc_xb, w_xb, tot_xb, cats_xb = lint(BASE_CD)
    rc_xc, w_xc, tot_xc, cats_xc = lint(CAND_CD)
    say(f"STE draft base: rc={rc_db} words={w_db} total={tot_db} {cats_db}")
    say(f"STE draft candidate: rc={rc_dc} words={w_dc} total={tot_dc} {cats_dc}")
    say(f"STE tracker base: rc={rc_tb} words={w_tb} total={tot_tb} {cats_tb}")
    say(f"STE tracker candidate: rc={rc_tc} words={w_tc} total={tot_tc} {cats_tc}")
    say(f"STE captions base: rc={rc_cb} words={w_cb} total={tot_cb} {cats_cb}")
    say(f"STE captions candidate: rc={rc_cc} words={w_cc} total={tot_cc} {cats_cc}")
    say(f"STE captions-draft base: rc={rc_xb} words={w_xb} total={tot_xb} {cats_xb}")
    say(f"STE captions-draft candidate: rc={rc_xc} words={w_xc} total={tot_xc} {cats_xc}")

    def gains(cb, cc):
        return {k: v - cb.get(k, 0) for k, v in cc.items()
                if v > cb.get(k, 0) and not k.startswith("_")}

    gained = {"draft": gains(cats_db, cats_dc), "tracker": gains(cats_tb, cats_tc),
              "captions": gains(cats_cb, cats_cc), "captions-draft": gains(cats_xb, cats_xc)}
    for name, g in gained.items():
        if g:
            say(f"{name} category gains: {g}")
    ste_ok = (rc_dc == 0 and rc_tc == 0 and rc_cc == 0 and rc_xc == 0
              and None not in (tot_db, tot_dc, tot_tb, tot_tc, tot_cb, tot_cc, tot_xb, tot_xc)
              and tot_dc == tot_db and tot_tc == tot_tb
              and tot_cc == tot_cb and tot_xc == tot_xb
              and not gains(cats_db, cats_dc) and not gains(cats_tb, cats_tc)
              and not gains(cats_cb, cats_cc) and not gains(cats_xb, cats_xc))

    # --- token diff -------------------------------------------------------
    def tokdiff(base, cand):
        a, b = Counter(TOK.findall(base)), Counter(TOK.findall(cand))
        return dict(b - a), dict(a - b)

    add_d, rem_d = tokdiff(base_d, cand_d)
    add_t, rem_t = tokdiff(base_t, cand_t)
    add_c, rem_c = tokdiff(base_c, cand_c)
    add_x, rem_x = tokdiff(base_cd, cand_cd)
    tok_ok = True
    for name, add, rem, ea, er in [
        ("draft", add_d, rem_d, EXPECT_D_ADD, EXPECT_D_REM),
        ("tracker", add_t, rem_t, EXPECT_T_ADD, EXPECT_T_REM),
        ("captions", add_c, rem_c, EXPECT_C_ADD, EXPECT_C_REM),
        ("captions-draft", add_x, rem_x, EXPECT_CD_ADD, EXPECT_CD_REM),
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
        shutil.copyfile(CAND_C, ROOT / CAP_REL)
        shutil.copyfile(CAND_CD, ROOT / CAPD_REL)
        say(f"draft written: {DRAFT_REL}")
        say(f"tracker written: {TRACKER_REL}")
        say(f"captions written: {CAP_REL}")
        say(f"captions-draft written: {CAPD_REL}")


if __name__ == "__main__":
    main()
