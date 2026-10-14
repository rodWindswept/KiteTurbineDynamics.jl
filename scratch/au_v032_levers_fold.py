#!/usr/bin/env python3
"""Draft v0.32 — the levers reading fold and the claim-evidence matrix (author seat, 2026-10-14).

Applies to the tip (60ee728), fail-closed, two-state (base read from
`git show HEAD:<path>`; never from the working file):

  D1  version pin: v0.31 -> v0.32, date 2026-10-13 -> 2026-10-14
  D2  section 3.4: retires the pending bracket, seats the rows 20/21
      pointers (figure-map markers, the [6]/[7] style), and lands the
      frozen levers reading block byte-exact (receipt md5 7bbd964d...)
  D3  the claim-evidence matrix lands as the first appendix, from the
      audited supply block (two cells re-voice active for the STE hold;
      the search-improvement row splits into two sentences for the same)
  D4  one linebreak-only split in the winner-intro block (STE hold,
      following the v0.18 split technique)
  T1  tracker v0.32 entry

Gates: STE per file (rc=0; total must not exceed base; no category
gains), declared token diff (draft + tracker), the register-seat
citation checker. --write copies candidates over the repo files only
when every gate is green.

Usage:
  python3 scratch/au_v032_levers_fold.py          # build, gate, report
  python3 scratch/au_v032_levers_fold.py --write  # copy candidates over repo files
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
RECEIPT = ROOT / "docs/reporting/room-responses/science-writer-2026-10-14-levers-reading.md"
AU2 = ROOT / "docs/reporting/room-responses/author-2026-10-14-au2-claim-evidence-matrix.md"
BASE_D = ROOT / "scratch/au_v032_draft_base.md"
CAND_D = ROOT / "scratch/au_v032_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v032_tracker_base.md"
CAND_T = ROOT / "scratch/au_v032_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v032_levers_fold.log"

BLOCK_MD5 = "7bbd964db09d2b33269ce5cb8c334054"

# Declared before the run — the full push delta against the tip.
EXPECT_D_ADD = {
    "0.5180": 1, "0.5621": 1, "17.3": 1, "20": 1, "21": 1, "22.4": 1,
    "25.698": 1, "26": 1, "2.03": 1, "27.364": 2, "3": 1, "3.1": 1,
    "3.2": 1, "3.3": 3, "3.4": 2, "301": 1, "32": 1, "36.109": 2,
    "39.7": 1, "4.1": 1, "4.3": 1, "5.309": 1, "5018": 1, "508": 1,
    "5222": 1, "5385": 1, "5605": 1, "930": 2, "11": 1, "110": 1,
    "15.0": 1, "147": 1, "0006": 1,
}
EXPECT_D_REM = {}
EXPECT_T_ADD = {"32": 1, "3.4": 1, "20": 1, "21": 1}
EXPECT_T_REM = {}

D1 = (
    "Internal engineering report. Draft v0.31. Date 2026-10-13.",
    "Internal engineering report. Draft v0.32. Date 2026-10-14.",
)

D2_OLD = (
    "### 3.4 The levers [PENDING. Landscape Phases 1 to 2 supply this section.]\n\n"
    "[Figure seated: figure-map row 6 (ring utilisation plate, slug `ring-utilisation`). Values cite NR-021.]\n\n"
    "[Figure seated: figure-map row 7 (twist limit plate, slug `twist-limit`). Values cite NR-022 and NR-023.]"
)
D2_NEW_HEAD = (
    "### 3.4 The levers\n\n"
    "[Figure seated: figure-map row 6 (ring utilisation plate, slug `ring-utilisation`). Values cite NR-021.]\n\n"
    "[Figure seated: figure-map row 7 (twist limit plate, slug `twist-limit`). Values cite NR-022 and NR-023.]\n\n"
    "[Figure seated: figure-map row 20 (the levers landscape, slug `pca-landscape`). Values cite NR-001, NR-005, NR-006, NR-044 and NR-045.]\n\n"
    "[Figure seated: figure-map row 21 (the parameter atlas, slug `pca-atlas`). Values cite NR-001, NR-005, NR-006 and NR-044.]"
)

D4 = (
    "That value is the window minimum. The capture hub\nring reads",
    "That value is the window minimum.\n\nThe capture hub\nring reads",
)

T1_OLD = (
    "The era sentence and the wind bullet take their clarity forms.\n"
    "No value moves.\n\n## 2. Working notes"
)
T1_NEW = (
    "The era sentence and the wind bullet take their clarity forms.\n"
    "No value moves.\n\n"
    "v0.32 pass by @author (2026-10-14).\n"
    "This pass folds the levers reading at section 3.4, with the rows 20 and 21 pointers.\n"
    "It also lands the claim\u2013evidence matrix as the first appendix.\n"
    "The reading prints signed rows NR-001, NR-005, NR-006, NR-044 and NR-045.\n"
    "No value moves.\n\n## 2. Working notes"
)

APPENDIX_ANCHOR = "## Appendix: Figure provenance"

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


def md5(s):
    return hashlib.md5(s.encode()).hexdigest()


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

    # --- frozen block from the science-writer receipt ------------------
    rtext = RECEIPT.read_text()
    block = rtext.split("<!-- LEVERS-READING-START -->\n")[1].split("<!-- LEVERS-READING-END -->")[0]
    say(f"block md5: {md5(block)} (declared {BLOCK_MD5})")
    if md5(block) != BLOCK_MD5:
        say("ABORT: block md5 mismatch")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    sim = (ROOT / "scratch/sw_levers_fold_sim.md").read_text()
    if block not in sim:
        say("ABORT: block not byte-present in the sim")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    say("block verified: receipt md5 ok, byte-present in the sim")

    # --- matrix table from the audited supply --------------------------
    atext = AU2.read_text()
    table = atext.split("| Claim | Evidence | Report location | Register rows |", 1)[1]
    table = table.split("## Row map", 1)[0]
    table = ("| Claim | Evidence | Report location | Register rows |" + table).rstrip() + "\n"
    # Re-voice two cells active (STE hold) and split the row-6 sentence.
    reps = [
        ("Lifter modulation is assumed.", "The report assumes lifter modulation."),
        ("Launch and recovery are excluded.", "Launch and recovery sit outside this report."),
        ("The search improved the best objective from the common seed to the winner, 36.109 to 27.364 kg-equivalent.",
         "The search improved the best objective from the common seed to the winner. It reads 36.109 to 27.364 kg-equivalent."),
    ]
    for old, new in reps:
        c = table.count(old)
        if c != 1:
            say(f"ABORT: matrix cell matched {c} times: {old[:60]}")
            LOG_P.write_text("\n".join(log))
            sys.exit(1)
        table = table.replace(old, new, 1)
    say("matrix table extracted from the audited supply; three cells re-voiced")

    matrix = (
        "## Appendix: Claims and evidence\n\n"
        "The table ties each headline claim of this report to its evidence and its signed register rows.\n\n"
        + table.rstrip() + "\n"
    )

    # --- build the candidates ------------------------------------------
    cand_d = base_d
    pairs = [
        ("D1 version pin", D1[0], D1[1]),
        ("D2 section 3.4 fold", D2_OLD, D2_NEW_HEAD + "\n\n" + block.rstrip("\n")),
        ("D3 appendix matrix", APPENDIX_ANCHOR, matrix + "\n" + APPENDIX_ANCHOR),
        ("D4 winner-intro split", D4[0], D4[1]),
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
        ("pin v0.32", "Draft v0.32" in cand_d and "Draft v0.31" not in cand_d),
        ("bracket retired", "[PENDING. Landscape Phases 1 to 2 supply this section.]" not in cand_d),
        ("heading form", "### 3.4 The levers\n" in cand_d),
        ("rows 20/21 pointers",
         "figure-map row 20 (the levers landscape, slug `pca-landscape`)" in cand_d
         and "figure-map row 21 (the parameter atlas, slug `pca-atlas`)" in cand_d),
        ("block bytes in candidate", block in cand_d),
        ("matrix appendix heading", "## Appendix: Claims and evidence" in cand_d),
        ("matrix before provenance appendix",
         cand_d.index("## Appendix: Claims and evidence") < cand_d.index("## Appendix: Figure provenance")),
        ("old markers held", "[Figure seated: figure-map row 6" in cand_d and "[Figure seated: figure-map row 7" in cand_d),
        ("no 14.972 print", "14.972" not in cand_d),
        ("split in place", "That value is the window minimum.\n\nThe capture hub\nring reads" in cand_d),
        ("tracker v0.32 entry", "v0.32 pass by @author" in cand_t),
        ("tracker history held", "v0.31 pass by @author" in cand_t and "v0.29 pass by @author" in cand_t),
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
    tok_ok_d = (add_d == EXPECT_D_ADD and rem_d == EXPECT_D_REM)
    say(f"draft token delta add: {dict(sorted(add_d.items()))}")
    say(f"draft token delta rem: {rem_d}")
    say(f"draft token check: {'PASS' if tok_ok_d else 'FAIL'}")

    tta, ttb = Counter(TOK.findall(base_t)), Counter(TOK.findall(cand_t))
    add_t, rem_t = dict(ttb - tta), dict(tta - ttb)
    tok_ok_t = (add_t == EXPECT_T_ADD and rem_t == EXPECT_T_REM)
    say(f"tracker token delta add: {add_t}")
    say(f"tracker token delta rem: {rem_t}")
    say(f"tracker token check: {'PASS' if tok_ok_t else 'FAIL'}")

    # --- citation gate --------------------------------------------------
    r = run(["python3", "scratch/sv_check_draft_citations.py", str(CAND_D), REG])
    cite_ok = r.returncode == 0
    for line in r.stdout.splitlines()[:5]:
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
