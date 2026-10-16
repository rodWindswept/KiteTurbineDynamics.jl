#!/usr/bin/env python3
"""Draft v0.57 — the winner bow read folds at the author seat (2026-10-16).

The founder word "up" (2026-10-15) closed the bow call; NR-059 signs the
winner read (science-validator, 2026-10-16); this pass lands the section
3.3 block beside the settle-state read, per the room's chain:

  D1  version pin v0.56 -> v0.57 (date to 2026-10-16)
  D2  the bow block inserts after the settle paragraph, ahead of the
      window-mean speed sentence (thirteen added lines: three
      paragraphs)
  T1  tracker v0.57 entry

The block carries value + station + state (NR-059): midpoint ring settle
0.002 m, window 0.105 to 0.310 m; hub max 0.209 to 0.613 m; extension
end 0.422 m midpoint, 0.833 m hub; the 1.5 m line met at the midpoint
station; the settle/run disagreement read as an instrument finding.

Two-state, fail-closed (mirrors au_v056_era_pack_fold.py).

Usage:
  python3 scratch/au_v057_bow_read_fold.py          # build, gate, report
  python3 scratch/au_v057_bow_read_fold.py --write  # copy candidates over
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
BASE_D = ROOT / "scratch/au_v057_bow_draft_base.md"
CAND_D = ROOT / "scratch/au_v057_bow_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v057_bow_tracker_base.md"
CAND_T = ROOT / "scratch/au_v057_bow_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v057_bow_read_fold.log"

ASSERT_TOKENS = "--dry" not in sys.argv
EXPECT_D_ADD = {"57": 1, "0.002": 1, "0.105": 1, "0.310": 1, "0.209": 1,
                "0.613": 1, "0.422": 1, "0.833": 1, "1.5": 1}
EXPECT_D_REM = {"56": 1}
EXPECT_T_ADD = {"57": 1, "3.3": 1}
EXPECT_T_REM = {}

EXPECT_OPCODES = [
    ("equal", 0, 2, 0, 2),
    ("replace", 2, 3, 2, 3),
    ("equal", 3, 547, 3, 547),
    ("insert", 547, 547, 547, 560),
    ("equal", 547, 1063, 560, 1076),
]
EXPECT_OPCODES_T = [
    ("equal", 0, 328, 0, 328),
    ("insert", 328, 328, 328, 333),
    ("equal", 328, 446, 333, 451),
]

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")

PIN_OLD = "Internal engineering report. Draft v0.56. Date 2026-10-15."
PIN_NEW = "Internal engineering report. Draft v0.57. Date 2026-10-16."

P1 = ("The shaft axis bows off its design line, sagging straight down under gravity.\n"
      "At the midpoint ring the bow reads 0.002 m at settle, and\n"
      "0.105 to 0.310 m through the measurement window (NR-059).\n"
      "The maximum sits at the hub and reads 0.209 to 0.613 m through the window (NR-059).")
P2 = ("An extension run past the window ends at 0.422 m at the midpoint\n"
      "and 0.833 m at the hub (NR-059).\n"
      "Every state at the midpoint ring reads below the 1.5 m line (NR-059).")
P3 = ("The settle hands off a straight stack while the run bows it.\n"
      "The two do not agree on the bowed shape.\n"
      "The disagreement reads as an instrument finding, not a design question (NR-059).")
BLOCK = P1 + "\n\n" + P2 + "\n\n" + P3

INS_ANCHOR = ("The machine accelerates through the relax run.\n"
              "\n"
              "Its window-mean speed reads 13.38 rad/s, 127.772 rpm (NR-029).")
INS_NEW = ("The machine accelerates through the relax run.\n"
           "\n"
           + BLOCK +
           "\n"
           "\n"
           "Its window-mean speed reads 13.38 rad/s, 127.772 rpm (NR-029).")

T1_OLD = ("No value moves, and no figure byte moves.\n"
          "\n"
          "## 2. Working notes")
T1_NEW = ("No value moves, and no figure byte moves.\n"
          "\n"
          "v0.57 pass by @author (2026-10-16).\n"
          "This pass folds the winner bow read.\n"
          "The bow block lands at section 3.3, after the settle-state read (NR-059).\n"
          "No value moves, and no figure byte moves.\n"
          "\n"
          "## 2. Working notes")


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


def tail_from(text, start):
    i = text.index(start)
    return text[i:]


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

    PAIRS = [
        ("D1 version pin", (PIN_OLD, PIN_NEW)),
        ("D2 bow block insert", (INS_ANCHOR, INS_NEW)),
    ]

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

    CAND_D.write_text(cand_d)
    CAND_T.write_text(cand_t)
    say(f"candidate draft sha256: {sh256(CAND_D)}")
    say(f"candidate tracker sha256: {sh256(CAND_T)}")

    # --- live diagnostics -------------------------------------------------
    ops = opcodes(base_d, cand_d)
    b_lines_d, c_lines_d = base_d.splitlines(), cand_d.splitlines()
    b_lines_t, c_lines_t = base_t.splitlines(), cand_t.splitlines()
    say(f"line count draft: base {len(b_lines_d)} -> candidate {len(c_lines_d)}")
    say(f"line count tracker: base {len(b_lines_t)} -> candidate {len(c_lines_t)}")
    say(f"draft opcodes: {ops}")
    say(f"tracker opcodes: {opcodes(base_t, cand_t)}")

    def tokdiff(base, cand):
        a, b = Counter(TOK.findall(base)), Counter(TOK.findall(cand))
        return dict(b - a), dict(a - b)

    add_d, rem_d = tokdiff(base_d, cand_d)
    add_t, rem_t = tokdiff(base_t, cand_t)
    say(f"draft token delta add: {dict(sorted(add_d.items()))}")
    say(f"draft token delta rem: {dict(sorted(rem_d.items()))}")
    say(f"tracker token delta add: {dict(sorted(add_t.items()))}")
    say(f"tracker token delta rem: {dict(sorted(rem_t.items()))}")
    say(f"cite count: base {base_d.count('NR-')} -> candidate {cand_d.count('NR-')}")
    say(f"NR-059 count: base {base_d.count('NR-059')} -> candidate {cand_d.count('NR-059')}")
    say(f"bow substring count: base {base_d.count('bow')} -> candidate {cand_d.count('bow')}")
    say(f"v0.56 count: base {base_d.count('v0.56')} -> candidate {cand_d.count('v0.56')}")
    say(f"v0.57 count: base {base_d.count('v0.57')} -> candidate {cand_d.count('v0.57')}")
    say(f"1.5 count: base {base_d.count('1.5')} -> candidate {cand_d.count('1.5')}")
    say(f"tracker v0.57 count: base {base_t.count('v0.57')} -> candidate {cand_t.count('v0.57')}")

    # --- guards (diagnostics above must be complete before these exit) ----
    recon = base_d
    for _, (old, new) in PAIRS:
        recon = recon.replace(old, new, 1)
    rev = cand_d
    for _, (old, new) in reversed(PAIRS):
        rev = rev.replace(new, old, 1)

    block_lines = BLOCK.split("\n")
    text_blocks = [b for b in BLOCK.split("\n\n")]

    guards = [
        ("pin: v0.57 dated 2026-10-16",
         "Draft v0.57" in cand_d and "Draft v0.56" not in cand_d
         and "Date 2026-10-16" in cand_d),
        ("reconstruction: candidate == base plus declared edits", cand_d == recon),
        ("reverse: base == candidate minus declared edits", rev == base_d),
        ("D2 lands once, old gone",
         cand_d.count(INS_NEW) == 1 and cand_d.count(INS_ANCHOR) == 0),
        ("line count draft exact +13", len(c_lines_d) == len(b_lines_d) + 13),
        ("line count tracker exact +5", len(c_lines_t) == len(b_lines_t) + 5),
        ("opcodes exact",
         EXPECT_OPCODES is None or ops == EXPECT_OPCODES),
        ("tracker opcodes exact", opcodes(base_t, cand_t) == EXPECT_OPCODES_T),
        ("block: three paragraphs read once", all(cand_d.count(b) == 1 for b in text_blocks)),
        ("block: every line reads once", all(cand_d.count(l) == 1 for l in block_lines if l)),
        ("block: fragment counts within six",
         all(len(b.split("\n")) <= 6 for b in text_blocks)),
        ("block: founded on the anchor lines",
         cand_d.count("The settle state starts the machine at 10.170 rad/s (NR-016).") == 1
         and cand_d.count("The machine accelerates through the relax run.") == 1
         and cand_d.count("Its window-mean speed reads 13.38 rad/s, 127.772 rpm (NR-029).") == 1),
        ("block: row display forms carried",
         "0.002 m at settle" in cand_d and "0.105 to 0.310 m" in cand_d
         and "0.209 to 0.613 m" in cand_d and "0.422 m" in cand_d
         and "0.833 m" in cand_d and "the 1.5 m line" in cand_d),
        ("block: station and state names carried",
         "midpoint ring" in cand_d and "the hub" in cand_d and "at settle" in cand_d),
        ("block: the finding reads",
         "instrument finding, not a design question" in cand_d
         and "do not agree on the bowed shape" in cand_d),
        ("hold: NR-016 count", cand_d.count("NR-016") == base_d.count("NR-016")),
        ("hold: NR- count grows by five", cand_d.count("NR-") == base_d.count("NR-") + 5),
        ("hold: NR-059 reads five", cand_d.count("NR-059") == 5),
        ("hold: 10.170 held", cand_d.count("10.170") == base_d.count("10.170")),
        ("hold: 13.38 held", cand_d.count("13.38") == base_d.count("13.38")),
        ("region: abstract to 2.2 unchanged",
         region(cand_d, "**Abstract.**", "### 2.2 The simulation analysis") ==
         region(base_d, "**Abstract.**", "### 2.2 The simulation analysis")),
        ("region: 2.2 to 3.3 unchanged",
         region(cand_d, "### 2.2 The simulation analysis", "### 3.3 The winner") ==
         region(base_d, "### 2.2 The simulation analysis", "### 3.3 The winner")),
        ("region: 3.3 head to settle para unchanged",
         region(cand_d, "### 3.3 The winner", "The machine accelerates through the relax run.") ==
         region(base_d, "### 3.3 The winner", "The machine accelerates through the relax run.")),
        ("region: window-mean speed to 4 unchanged",
         region(cand_d, "Its window-mean speed reads 13.38 rad/s", "## 4 Discussion") ==
         region(base_d, "Its window-mean speed reads 13.38 rad/s", "## 4 Discussion")),
        ("region: 4 to 6 unchanged",
         region(cand_d, "## 4 Discussion", "## 6 Nomenclature") ==
         region(base_d, "## 4 Discussion", "## 6 Nomenclature")),
        ("region: 6 to Document control unchanged",
         region(cand_d, "## 6 Nomenclature", "## Document control") ==
         region(base_d, "## 6 Nomenclature", "## Document control")),
        ("region: Document control to claims unchanged",
         region(cand_d, "## Document control", "## Appendix: Claims and evidence") ==
         region(base_d, "## Document control", "## Appendix: Claims and evidence")),
        ("region: claims appendix unchanged",
         region(cand_d, "## Appendix: Claims and evidence", "## Appendix: Figure provenance") ==
         region(base_d, "## Appendix: Claims and evidence", "## Appendix: Figure provenance")),
        ("region: figure provenance to end unchanged",
         tail_from(cand_d, "## Appendix: Figure provenance") ==
         tail_from(base_d, "## Appendix: Figure provenance")),
        ("tracker v0.57 entry", "v0.57 pass by @author" in cand_t),
        ("tracker history held",
         "v0.56 pass by @author" in cand_t and "v0.55 pass by @author" in cand_t
         and "## 2. Working notes" in cand_t),
        ("tracker reconstruction exact", cand_t == base_t.replace(T1_OLD, T1_NEW, 1)),
        ("tracker entry lines read once",
         all(cand_t.count(l) == 1 for l in T1_NEW.split("\n")[2:5])),
    ]
    for label, ok in guards:
        say(f"guard {label}: {'ok' if ok else 'FAIL'}")
        if not ok:
            LOG_P.write_text("\n".join(log))
            sys.exit(1)

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
    tok_ok = True
    for name, add, rem, ea, er in [
        ("draft", add_d, rem_d, EXPECT_D_ADD, EXPECT_D_REM),
        ("tracker", add_t, rem_t, EXPECT_T_ADD, EXPECT_T_REM),
    ]:
        ok = (add == ea and rem == er) if ASSERT_TOKENS else True
        tok_ok = tok_ok and ok
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
