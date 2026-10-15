#!/usr/bin/env python3
"""Draft v0.56 — the era pack folds (author seat, 2026-10-15).

Folds the three supplied blocks the science-writer seat routed to this
seat (era pack, `1c65d27`; supply `scratch/sw_era_pack_supply.md`):

  (a) Block A — section 3.1: the era phrase takes the era the record
      carries ("the wind-authority era"). One line moves. No digit
      moves, no row needed. The era call is ruled (Rod, in the room).
  (b) Block B — section 4.2: the failure-ledger table takes date order
      (08-13, 08-14, 08-22, 08-22, 08-24, 08-26). Header and rule hold;
      all 30 body cells hold byte for byte, compared as sets.
  (c) Block C — the back-pointer: three sentences close the load block
      after the anchor line "That load forces about 9 kW from the seed
      (NR-047)." No digit; no cite.

The blocks are pulled from the supply and the receipt and asserted
byte-identical across the two before use.

  D1  version pin v0.55 -> v0.56 (date held at 2026-10-15)
  D2  Block A at section 3.1 (one line moves)
  D3  Block B at section 4.2 (six rows reorder, cells held)
  D4  Block C at the load block (three lines insert)
  T1  tracker v0.56 entry

Two-state, fail-closed (mirrors au_v055_split_and_env_fold.py).

Usage:
  python3 scratch/au_v056_era_pack_fold.py          # build, gate, report
  python3 scratch/au_v056_era_pack_fold.py --write  # copy candidates over
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
SUPPLY_REL = "scratch/sw_era_pack_supply.md"
RECEIPT_REL = "docs/reporting/room-responses/science-writer-2026-10-15-era-pack.md"
BASE_D = ROOT / "scratch/au_v056_era_draft_base.md"
CAND_D = ROOT / "scratch/au_v056_era_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v056_era_tracker_base.md"
CAND_T = ROOT / "scratch/au_v056_era_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v056_era_pack_fold.log"

ASSERT_TOKENS = True
EXPECT_D_ADD = {"56": 1}
EXPECT_D_REM = {"55": 1}
EXPECT_T_ADD = {"2": 1, "2.2": 1, "3.1": 1, "4.2": 1, "56": 1}
EXPECT_T_REM = {}

EXPECT_OPCODES = [
    ("equal", 0, 2, 0, 2),
    ("replace", 2, 3, 2, 3),
    ("equal", 3, 300, 3, 300),
    ("insert", 300, 300, 300, 304),
    ("equal", 300, 485, 304, 489),
    ("replace", 485, 486, 489, 490),
    ("equal", 486, 830, 490, 834),
    ("insert", 830, 830, 834, 835),
    ("equal", 830, 831, 835, 836),
    ("insert", 831, 831, 836, 839),
    ("equal", 831, 832, 839, 840),
    ("delete", 832, 836, 840, 840),
    ("equal", 836, 1059, 840, 1063),
]

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


def opcodes(base, cand):
    b, c = base.splitlines(), cand.splitlines()
    return difflib.SequenceMatcher(a=b, b=c, autojunk=False).get_opcodes()


def fenced(text, marker):
    i = text.index(marker)
    j = text.index("```", i) + 3
    k = text.index("```", j)
    return text[j:k].strip("\n")


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

    # --- pull the supplied blocks; supply and receipt must agree ----------
    sup = (ROOT / SUPPLY_REL).read_text()
    rec = (ROOT / RECEIPT_REL).read_text()
    A_s = fenced(sup, "## Block A")
    B_s = fenced(sup, "## Block B")
    C_s = fenced(sup, "Insert:")
    A_r = fenced(rec, "**Block A")
    B_r = fenced(rec, "**Block B")
    C_r = fenced(rec, "Insert:")
    say(f"block A supply md5: {hashlib.md5(A_s.encode()).hexdigest()}")
    say(f"block B supply md5: {hashlib.md5(B_s.encode()).hexdigest()}")
    say(f"block C supply md5: {hashlib.md5(C_s.encode()).hexdigest()}")
    if not (A_s == A_r and B_s == B_r and C_s == C_r):
        say("SUPPLY/RECEIPT BLOCK MISMATCH")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    say("supply blocks == receipt blocks (A, B, C)")
    if re.search(r"\d", C_s):
        say("BLOCK C CARRIES A DIGIT")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    say("block C carries no digit")

    # the supply pins the base draft md5 it was cut from
    m = re.search(r"md5 `([0-9a-f]{32})`", sup)
    base_md5 = hashlib.md5(BASE_D.read_bytes()).hexdigest()
    say(f"supply pins draft md5: {m.group(1) if m else None}")
    say(f"base draft md5: {base_md5}")
    if not m or m.group(1) != base_md5:
        say("BASE MD5 MISMATCH")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)

    # --- derive the table runs from the base (old) and the supply (new) ---
    t_start = "| Date / event | Class | What happened | Detection | Correction / lesson | Status |"
    i = base_d.index(t_start)
    j = base_d.index("\n\n- The dead geometry genes.", i)
    cur = base_d[i:j].split("\n")
    cur_rows = cur[2:]
    b_lines = B_s.split("\n")
    new_rows = b_lines[2:]
    say(f"table rows: base {len(cur_rows)} -> supply {len(new_rows)}")
    if len(cur_rows) != 6 or len(new_rows) != 6:
        say("ROW COUNT MISMATCH")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    if sorted(cur_rows) != sorted(new_rows):
        say("ROW SET NOT EQUAL")
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    say("row sets equal (30 cells held as sets)")
    cur_run = "\n".join(cur_rows)
    new_run = "\n".join(new_rows)

    # Block A: one line moves; the second line holds
    a_old = ("This campaign is the first screen after the physics-validation era.\n"
             "Larger and wider campaigns sit ahead.")
    a_new = A_s

    # Block C: the three sentences insert after the anchor line
    c_anchor = "That load forces about 9 kW from the seed (NR-047)."
    c_old = c_anchor + "\n\nThe sweep rows read as follows (NR-047)."
    c_new = (c_anchor + "\n\n" + C_s
             + "\n\nThe sweep rows read as follows (NR-047).")

    D1 = (
        "Internal engineering report. Draft v0.55. Date 2026-10-15.",
        "Internal engineering report. Draft v0.56. Date 2026-10-15.",
    )
    D2 = (a_old, a_new)
    D3 = (cur_run, new_run)
    D4 = (c_old, c_new)

    T1_OLD = (
        "No value moves, and no figure byte moves.\n"
        "\n"
        "## 2. Working notes"
    )
    T1_NEW = (
        "No value moves, and no figure byte moves.\n"
        "\n"
        "v0.56 pass by @author (2026-10-15).\n"
        "This pass folds the era pack: the era phrase, the ledger dates and the back-pointer.\n"
        "Section 3.1 takes the era label the record carries. Section 4.2 takes date order.\n"
        "The back-pointer lands at section 2.2.2, per the ruling.\n"
        "No value moves, and no figure byte moves.\n"
        "\n"
        "## 2. Working notes"
    )

    PAIRS = [
        ("D1 version pin", D1),
        ("D2 Block A (era phrase)", D2),
        ("D3 Block B (ledger dates)", D3),
        ("D4 Block C (back-pointer)", D4),
    ]

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

    CAND_D.write_text(cand_d)
    CAND_T.write_text(cand_t)
    say(f"candidate draft sha256: {sh256(CAND_D)}")
    say(f"candidate tracker sha256: {sh256(CAND_T)}")

    # --- live diagnostics -------------------------------------------------
    ops = opcodes(base_d, cand_d)
    b_lines_d, c_lines_d = base_d.splitlines(), cand_d.splitlines()
    say(f"line count: base {len(b_lines_d)} -> candidate {len(c_lines_d)}")
    say(f"draft opcodes: {ops}")

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

    rc_db, w_db, tot_db, cats_db = lint(BASE_D)
    rc_dc, w_dc, tot_dc, cats_dc = lint(CAND_D)
    rc_tb, w_tb, tot_tb, cats_tb = lint(BASE_T)
    rc_tc, w_tc, tot_tc, cats_tc = lint(CAND_T)
    say(f"STE draft base: rc={rc_db} words={w_db} total={tot_db} {cats_db}")
    say(f"STE draft candidate: rc={rc_dc} words={w_dc} total={tot_dc} {cats_dc}")
    say(f"STE tracker base: rc={rc_tb} words={w_tb} total={tot_tb} {cats_tb}")
    say(f"STE tracker candidate: rc={rc_tc} words={w_tc} total={tot_tc} {cats_tc}")

    # --- guards ----------------------------------------------------------
    recon = base_d
    for _, (old, new) in PAIRS:
        recon = recon.replace(old, new, 1)
    rev = cand_d
    for _, (old, new) in reversed(PAIRS):
        rev = rev.replace(new, old, 1)

    guards = [
        ("pin: v0.56 dated 2026-10-15",
         "Draft v0.56" in cand_d and "Draft v0.55" not in cand_d and "Date 2026-10-15" in cand_d),
        ("reconstruction: candidate == base plus declared edits", cand_d == recon),
        ("reverse: base == candidate minus declared edits", rev == base_d),
        ("D2 lands once, old gone", cand_d.count(D2[1]) == 1 and cand_d.count(D2[0]) == 0),
        ("D3 lands once, old gone", cand_d.count(D3[1]) == 1 and cand_d.count(D3[0]) == 0),
        ("D4 lands once, old gone", cand_d.count(D4[1]) == 1 and cand_d.count(D4[0]) == 0),
        ("line count exact", len(c_lines_d) == (len(b_lines_d) + 4)),
        ("opcodes exact", EXPECT_OPCODES is not None and ops == EXPECT_OPCODES),
        ("era phrase gone", cand_d.count("physics-validation") == 0 and cand_d.count("first screen") == 0),
        ("era phrase lands once",
         cand_d.count("This campaign is the first search campaign of the wind-authority era.") == 1),
        ("era count grows by one",
         cand_d.count("wind-authority era") == base_d.count("wind-authority era") + 1),
        ("held line: larger campaigns",
         cand_d.count("Larger and wider campaigns sit ahead.") == 1),
        ("table: header and rule read once",
         cand_d.count(t_start) == 1 and cand_d.count("|---|---|---|---|---|---|") == base_d.count("|---|---|---|---|---|---|")),
        ("table: each row reads once",
         all(cand_d.count(r) == 1 for r in new_rows)),
        ("table: date order 08-13 to 08-26",
         [r[2:12] for r in new_rows] == ["2026-08-13", "2026-08-14", "2026-08-22",
                                         "2026-08-22", "2026-08-24", "2026-08-26"]),
        ("table: same-day pair keeps its order",
         new_rows[2].startswith("| 2026-08-22 blade-mass-law") and new_rows[3].startswith("| 2026-08-22 FoS=Inf")),
        ("block C: three lines read once each",
         all(cand_d.count(l) == 1 for l in C_s.split("\n"))),
        ("block C: anchor and sweep lines held",
         cand_d.count("That load forces about 9 kW from the seed (NR-047).") == 1
         and cand_d.count("The sweep rows read as follows (NR-047).") == 1),
        ("hold: 36.109", cand_d.count("36.109") == base_d.count("36.109")),
        ("hold: 25.698", cand_d.count("25.698") == base_d.count("25.698")),
        ("hold: NR-047", cand_d.count("NR-047") == base_d.count("NR-047")),
        ("hold: NR-013 ext2 reads 5", cand_d.count("NR-013 ext2") == 5),
        ("hold: least margin", cand_d.count("The least segment torque margin is 2.03") == base_d.count("The least segment torque margin is 2.03")),
        ("hold: never-allows-breaks close",
         cand_d.count("The fix removes false rejections. It never allows breaks.") == 1),
        ("hold: study-is-simulation-only", cand_d.count("The study is simulation-only.") == 1),
        ("region: 1 to the load anchor unchanged",
         region(cand_d, "## 1 Introduction", "That load forces about 9 kW from the seed (NR-047).") ==
         region(base_d, "## 1 Introduction", "That load forces about 9 kW from the seed (NR-047).")),
        ("region: sweep rows to the 3.1 heading unchanged",
         region(cand_d, "The sweep rows read as follows (NR-047).", "### 3.1 The search at scale") ==
         region(base_d, "The sweep rows read as follows (NR-047).", "### 3.1 The search at scale")),
        ("region: 3.2 to the 4.2 heading unchanged",
         region(cand_d, "### 3.2 Convergence", "### 4.2 The failure ledger") ==
         region(base_d, "### 3.2 Convergence", "### 4.2 The failure ledger")),
        ("region: 4.2 head to the table unchanged",
         region(cand_d, "### 4.2 The failure ledger", "| Date / event | Class |") ==
         region(base_d, "### 4.2 The failure ledger", "| Date / event | Class |")),
        ("region: ledger prose to 4.3 unchanged",
         region(cand_d, "- The dead geometry genes.", "### 4.3 Model boundaries") ==
         region(base_d, "- The dead geometry genes.", "### 4.3 Model boundaries")),
        ("region: 4.3 to 5 unchanged",
         region(cand_d, "### 4.3 Model boundaries", "## 5 Conclusion") ==
         region(base_d, "### 4.3 Model boundaries", "## 5 Conclusion")),
        ("region: 5 to 6 unchanged",
         region(cand_d, "## 5 Conclusion", "## 6 Nomenclature") ==
         region(base_d, "## 5 Conclusion", "## 6 Nomenclature")),
        ("region: 6 to Document control unchanged",
         region(cand_d, "## 6 Nomenclature", "## Document control") ==
         region(base_d, "## 6 Nomenclature", "## Document control")),
        ("region: Document control to claims appendix unchanged",
         region(cand_d, "## Document control", "## Appendix: Claims and evidence") ==
         region(base_d, "## Document control", "## Appendix: Claims and evidence")),
        ("region: claims appendix unchanged",
         region(cand_d, "## Appendix: Claims and evidence", "## Appendix: Figure provenance") ==
         region(base_d, "## Appendix: Claims and evidence", "## Appendix: Figure provenance")),
        ("region: figure provenance unchanged",
         region(cand_d, "## Appendix: Figure provenance", "- `checks` `e6bcfca931") ==
         region(base_d, "## Appendix: Figure provenance", "- `checks` `e6bcfca931")),
        ("tracker v0.56 entry", "v0.56 pass by @author" in cand_t),
        ("tracker history held",
         "v0.55 pass by @author" in cand_t and "v0.54 pass by @author" in cand_t
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
