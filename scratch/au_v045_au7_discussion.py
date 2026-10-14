#!/usr/bin/env python3
"""Draft v0.45 — AU7: the discussion folds (author seat, 2026-10-14).

Folds the two verified discussion supplies in one pass:
  D1  version pin v0.44 -> v0.45 (date held 2026-10-14)
  D2  section 3.3: the era map lands beside the era note — a short
      pointer block plus the four-row era table (SW3b, sweep 16;
      NR-019, NR-020, NR-027, NR-028)
  D3  section 4.2: the failure-ledger table lands, the narrative after
      it (SW3a, sweep 16)
  T1  tracker v0.45 entry

Supplies (byte-frozen): the fenced blocks in
docs/reporting/room-responses/science-writer-2026-10-13-sweep-16-era-map.md,
asserted byte-identical to their fold sims in
scratch/sw_sw3b_erasim.md and scratch/sw_ws3a_ledgersim.md.
SV7 audited both tables. The two tables carry the accepted table class
(one long_paragraph flag each, per scratch/sw_sw3b_tablesim2.log); the
STE check allows exactly that declared gain and nothing else.

Two-state, fail-closed (mirrors au_v043_round5_wording.py):
  - builds from `git show HEAD:<path>` (never the working file)
  - asserts every anchor exactly once
  - STE: rc=0; every category held except the two accepted table flags
  - declared token diff must match exactly
  - register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v045_au7_discussion.py          # build, gate, report
  python3 scratch/au_v045_au7_discussion.py --write  # copy candidates over
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
RECEIPT_REL = "docs/reporting/room-responses/science-writer-2026-10-13-sweep-16-era-map.md"
SIM_ERA = "scratch/sw_sw3b_erasim.md"
SIM_LEDGER = "scratch/sw_ws3a_ledgersim.md"
BASE_D = ROOT / "scratch/au_v045_draft_base.md"
CAND_D = ROOT / "scratch/au_v045_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v045_tracker_base.md"
CAND_T = ROOT / "scratch/au_v045_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v045_au7_discussion.log"

# Declared before the run. The pin moves (44 out, 45 in); the era table
# adds 18.8 and the pointer's section forms (2.2.2 -> 2.2 + 2, and 2.4);
# the ledger table adds 1.94 and 5.18. No value token moves.
ASSERT_TOKENS = True
EXPECT_D_ADD = {"45": 1, "18.8": 1, "2.2": 1, "2": 1, "2.4": 1, "1.94": 1, "5.18": 1}
EXPECT_D_REM = {"44": 1}
EXPECT_T_ADD = {"45": 1, "3.3": 1, "4.2": 1}
EXPECT_T_REM = {}

POINTER = (
    "The three movers carry their records. The bank derate is a\n"
    "calculated depowering of the main-rotor disc (NR-019, NR-020).\n"
    "The window basis sits at section 2.2.2, and the gate set at\n"
    "section 2.4."
)

D2_OLD = (
    "space. Numbers across the eras would compare models, not machines.\n"
    "\n"
    "This run also trades"
)
D2_NEW = (
    "space. Numbers across the eras would compare models, not machines.\n"
    "\n"
    + POINTER + "\n"
    "\n"
    "{ERA_TABLE}\n"
    "\n"
    "This run also trades"
)

D3_OLD = (
    "Candidate entries. Each failure enters with its lesson.\n"
    "\n"
    "- The dead geometry genes."
)
D3_NEW = (
    "Candidate entries. Each failure enters with its lesson.\n"
    "\n"
    "{LEDGER_TABLE}\n"
    "\n"
    "- The dead geometry genes."
)

D1 = (
    "Internal engineering report. Draft v0.44. Date 2026-10-14.",
    "Internal engineering report. Draft v0.45. Date 2026-10-14.",
)

T1_OLD = (
    "The re-cut adds the cone-ring label (figure-map row 2; round-5 comment 3).\n"
    "No value moves.\n"
    "\n"
    "## 2. Working notes"
)
T1_NEW = (
    "The re-cut adds the cone-ring label (figure-map row 2; round-5 comment 3).\n"
    "No value moves.\n"
    "\n"
    "v0.45 pass by @author (2026-10-14).\n"
    "This pass folds AU7: the era map at section 3.3 and the failure-ledger table at section 4.2.\n"
    "The era map takes the short pointer block and the four-row table.\n"
    "The failure-ledger table lands with the narrative after it.\n"
    "The two tables add the accepted table class.\n"
    "No value moves.\n"
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


def md5s(text):
    return hashlib.md5(text.encode()).hexdigest()


def fenced_blocks(text):
    blocks = []
    lines = text.split("\n")
    cur = None
    for ln in lines:
        if ln.strip() == "```":
            if cur is None:
                cur = []
            else:
                blocks.append("\n".join(cur))
                cur = None
        elif cur is not None:
            cur.append(ln)
    return blocks


def table_from_sim(text, header_start):
    lines = text.split("\n")
    i = next(i for i, ln in enumerate(lines) if ln.startswith(header_start))
    j = i
    while j + 1 < len(lines) and lines[j + 1].startswith("|"):
        j += 1
    return "\n".join(lines[i:j + 1])


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

    # --- extract the supplied tables, byte-frozen -----------------------
    receipt = (ROOT / RECEIPT_REL).read_text()
    blocks = fenced_blocks(receipt)
    era_block = next(b for b in blocks if b.startswith("| Era |"))
    ledger_block = next(b for b in blocks if b.startswith("| Date / event |"))
    say(f"era table from receipt: {len(era_block)} bytes, md5 {md5s(era_block)}")
    say(f"ledger table from receipt: {len(ledger_block)} bytes, md5 {md5s(ledger_block)}")

    sim_era = (ROOT / SIM_ERA).read_text()
    sim_ledger = (ROOT / SIM_LEDGER).read_text()
    era_sim_tab = table_from_sim(sim_era, "| Era |")
    ledger_sim_tab = table_from_sim(sim_ledger, "| Date / event |")
    if era_sim_tab != era_block:
        say("SIM MISMATCH era table")
        say(repr(era_sim_tab[:200]))
        say(repr(era_block[:200]))
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    if ledger_sim_tab != ledger_block:
        say("SIM MISMATCH ledger table")
        say(repr(ledger_sim_tab[:200]))
        say(repr(ledger_block[:200]))
        LOG_P.write_text("\n".join(log))
        sys.exit(1)
    say("era table == sim: byte-identical")
    say("ledger table == sim: byte-identical")

    # --- build the candidates ------------------------------------------
    cand_d = base_d
    pairs = [
        ("D1 version pin", D1[0], D1[1]),
        ("D2 era map fold", D2_OLD, D2_NEW.replace("{ERA_TABLE}", era_block)),
        ("D3 ledger table fold", D3_OLD, D3_NEW.replace("{LEDGER_TABLE}", ledger_block)),
    ]
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

    # --- guards ---------------------------------------------------------
    n194_b, n518_b = base_d.count("1.94"), base_d.count("5.18")
    guards = [
        ("pin v0.45", "Draft v0.45" in cand_d and "Draft v0.44" not in cand_d),
        ("era table lands once", cand_d.count(era_block) == 1),
        ("ledger table lands once", cand_d.count(ledger_block) == 1),
        ("pointer block lands",
         "The three movers carry their records. The bank derate is a\n"
         "calculated depowering of the main-rotor disc (NR-019, NR-020).\n"
         "The window basis sits at section 2.2.2, and the gate set at\n"
         "section 2.4." in cand_d),
        ("era note held", "Numbers across the eras would compare models, not machines." in cand_d),
        ("ledger lead held", "Candidate entries. Each failure enters with its lesson." in cand_d),
        ("k-alignment values held",
         cand_d.count("1.94") == n194_b + 1 and cand_d.count("5.18") == n518_b + 1
         and "5.18 kilowatts" in cand_d and "5.18 kW" in cand_d),
        ("standing gate line held",
         "[2.24 holds a register row (NR-015). The other values need rows" in cand_d),
        ("frozen levers block held once", cand_d.count(block) == 1),
        ("methods region unchanged",
         region(cand_d, "## 2 Methods", "### 3.3 The winner") == region(base_d, "## 2 Methods", "### 3.3 The winner")),
        ("levers-to-ledger region unchanged",
         region(cand_d, "### 3.4 The levers", "### 4.2 The failure ledger") == region(base_d, "### 3.4 The levers", "### 4.2 The failure ledger")),
        ("boundaries to end unchanged",
         cand_d.split("### 4.3 Model boundaries")[1] == base_d.split("### 4.3 Model boundaries")[1]),
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
        ("tracker v0.45 entry", "v0.45 pass by @author" in cand_t),
        ("tracker history held",
         "v0.44 pass by @fig-img-diagrams" in cand_t and "v0.43 pass by @author" in cand_t),
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
    accepted = {"long_paragraph(>6s)": 2}
    gains_d_ok = (not gains_t) and gains_d == accepted
    if gains_d:
        say(f"draft category gains: {gains_d} (accepted: {accepted})")
    if gains_t:
        say(f"tracker category gains: {gains_t}")
    ste_ok = (rc_dc == 0 and rc_tc == 0
              and None not in (tot_db, tot_dc, tot_tb, tot_tc)
              and tot_dc == tot_db + 2 and tot_tc == tot_tb
              and gains_d_ok)

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
