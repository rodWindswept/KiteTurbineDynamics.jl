#!/usr/bin/env python3
"""Draft v0.43 — the round-5 wording set (author seat, 2026-10-14).

Folds feedback round 5, the @author wording set, keyed on the signed
source reads NR-049 (the shaft transition cone, one fixed 22 degrees,
not a search gene) and NR-050 (the blade-scale base: 0.75 and 0.113 of
the sized rotor radius):

  D1  version pin v0.42 -> v0.43 (date held 2026-10-14)
  D2  section 2.1: the blade-scale block takes the base clause (NR-050)
  D3  section 2.1: the shaft transition cone sentence lands (NR-049)
  D4  section 2.5: the cold-path line lands beside the probe sentence (NR-012)
  D5  section 3.1: the campaign-scale context lands
  D6  section 3.3: the window-swing reading lands
  D7  section 3.3: the lifter rationale (giant single kite) lands
  D8  section 3.3: the staged-launch assumption lands
  D9  section 3.3: the blade-scale slots take their decode names
  D10 section 3.3: the second bank slot names bank_bottom at its box top
  D11 section 3.5: the cone consistency line and the campaign lead land
  T1  tracker v0.43 entry

Guards: the two 22-degree facts stay apart, each named; the frozen
levers block re-reads carried once; sections 4 to the end re-read
byte-identical; the seven seated markers, the brackets, the classified
line, the rename, the objective block and the safety forms hold.

Two-state, fail-closed (mirrors au_v042_gate_margins.py):
  - builds from `git show HEAD:<path>` (never the working file)
  - asserts every anchor exactly once
  - STE base-versus-candidate per file; totals must not exceed base; no gains
  - declared token diff must match exactly
  - register-seat citation checker on the candidate draft

Usage:
  python3 scratch/au_v043_round5_wording.py          # build, gate, report
  python3 scratch/au_v043_round5_wording.py --write  # copy candidates over
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
BASE_D = ROOT / "scratch/au_v043_draft_base.md"
CAND_D = ROOT / "scratch/au_v043_draft_candidate.md"
BASE_T = ROOT / "scratch/au_v043_tracker_base.md"
CAND_T = ROOT / "scratch/au_v043_tracker_candidate.md"
LOG_P = ROOT / "scratch/au_v043_round5_wording.log"

# Declared before the run. The pin moves (42 out, 43 in); the base clause
# adds 0.75 and 0.113; the cone sentence adds 22 twice; the slot names
# replace the slot numerals 1 and 2. No value token moves.
ASSERT_TOKENS = True
EXPECT_D_ADD = {"43": 1, "0.75": 1, "0.113": 1, "22": 2}
EXPECT_D_REM = {"42": 1, "1": 1, "2": 1}
EXPECT_T_ADD = {"43": 1}
EXPECT_T_REM = {}

D1 = (
    "Internal engineering report. Draft v0.42. Date 2026-10-14.",
    "Internal engineering report. Draft v0.43. Date 2026-10-14.",
)

D2 = (
    "Blade scale sets the blade size. The scale multiplies the blade span\n"
    "and chord, and the blade mass follows the span cubed.",
    "Blade scale sets the blade size. The scale multiplies the blade span\n"
    "and chord, and the blade mass follows the span cubed.\n"
    "The base span reads 0.75 of the rotor radius, and the base chord reads 0.113 of it.\n"
    "The power sizing sets the radius for the rotor at its local wind speed (NR-050).",
)

D3 = (
    "The search treats each of these as a gene. The ring geometry sets the\n"
    "hub and ground radii, and the rotor count sets how many rings carry\n"
    "blades.",
    "The search treats each of these as a gene. The ring geometry sets the\n"
    "hub and ground radii, and the rotor count sets how many rings carry\n"
    "blades.\n"
    "The shaft transition cone holds one fixed angle, 22 degrees, by construction.\n"
    "It is not a search gene (NR-049).",
)

D4 = (
    "scripts/probe_warm_reject_cause.jl. The register header pins their\n"
    "commits.",
    "scripts/probe_warm_reject_cause.jl. The register header pins their\n"
    "commits.\n"
    "\n"
    "The campaign scored every design on the cold path (NR-012).",
)

D5 = (
    "The other members of each population draw at random under a fixed seed per island (scripts/run_v13_5kw_masslift.jl).",
    "The other members of each population draw at random under a fixed seed per island (scripts/run_v13_5kw_masslift.jl).\n"
    "\n"
    "This campaign is the first screen after the physics-validation era.\n"
    "Larger and wider campaigns sit ahead.",
)

D6 = (
    "Its window swing reads 0.029 kW on 5.309 kW, half a per cent (NR-014).",
    "Its window swing reads 0.029 kW on 5.309 kW, half a per cent (NR-014).\n"
    "The machine held a steady operating point through the measurement window.",
)

D7 = (
    "Without modulation, each weather band needs its own kite, up to a giant.",
    "Without modulation, each weather band would need its own single kite.\n"
    "That kite would reach giant sizes and be too hard to handle.",
)

D8 = (
    "across wind speeds is outside this report. The report states the\n"
    "presumption as one (2026-08-05).",
    "across wind speeds is outside this report. The report states the\n"
    "presumption as one (2026-08-05).\n"
    "\n"
    "The report also assumes a staged launch of the stack.\n"
    "A staged launch is easier to handle than one giant kite.",
)

D9 = (
    "The winner genome contains two blade-scale slots. Slot 1 reads 0.82 and\n"
    "decodes to the single active rotor. Slot 2 reads 0.20 and stays inactive\n"
    "because the rotor count is one (NR-011).",
    "The winner genome contains two blade-scale slots.\n"
    "The main-rotor slot, `blade_scale_top`, reads 0.82 and decodes to the single active rotor.\n"
    "The second-rotor slot, `blade_scale_bottom`, reads 0.20 and stays inactive\n"
    "because the rotor count is one (NR-011).",
)

D10 = (
    "A second bank slot reads 22 degrees. It does not decode to a physical\n"
    "rotor at a count of one (NR-011).",
    "The second bank slot holds `bank_bottom`. It reads 22 degrees at the top of its search box.\n"
    "It does not decode to a physical rotor at a rotor count of one (NR-011, NR-017).",
)

D11 = (
    "The winner genome carries inactive slots at a rotor count of one (NR-011, NR-017).",
    "The winner genome carries inactive slots at a rotor count of one (NR-011, NR-017).\n"
    "\n"
    "The shaft transition cone holds one fixed angle, 22 degrees,\n"
    "in every machine of the campaign (NR-049).\n"
    "A later campaign can vary it.",
)

DRAFT_PAIRS = [
    ("D1 version pin", D1[0], D1[1]),
    ("D2 blade-scale base", D2[0], D2[1]),
    ("D3 cone at 2.1", D3[0], D3[1]),
    ("D4 cold-path line", D4[0], D4[1]),
    ("D5 campaign-scale context", D5[0], D5[1]),
    ("D6 swing reading", D6[0], D6[1]),
    ("D7 lifter rationale", D7[0], D7[1]),
    ("D8 staged launch", D8[0], D8[1]),
    ("D9 blade-slot names", D9[0], D9[1]),
    ("D10 bank-slot naming", D10[0], D10[1]),
    ("D11 cone at 3.5", D11[0], D11[1]),
]

T1_OLD = "No signed value changes.\n\n## 2. Working notes"
T1_NEW = (
    "No signed value changes.\n\n"
    "v0.43 pass by @author (2026-10-14).\n"
    "This pass folds the round-5 wording set, keyed on the NR-049 and NR-050 reads.\n"
    "The blade-scale base, the cone statement and the slot names land.\n"
    "The cold-path line, the swing reading and the lifter rationale land.\n"
    "The campaign-scale context and the cone lead line land.\n"
    "No value moves.\n\n"
    "## 2. Working notes"
)

TRACKER_PAIRS = [
    ("T1 v0.43 entry", T1_OLD, T1_NEW),
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
    for name, old, new in DRAFT_PAIRS:
        c = cand_d.count(old)
        if c != 1:
            say(f"ANCHOR FAIL {name}: count={c}")
            LOG_P.write_text("\n".join(log))
            sys.exit(1)
        cand_d = cand_d.replace(old, new, 1)
        say(f"ok {name}")

    cand_t = base_t
    for name, old, new in TRACKER_PAIRS:
        c = cand_t.count(old)
        if c != 1:
            say(f"ANCHOR FAIL {name}: count={c}")
            LOG_P.write_text("\n".join(log))
            sys.exit(1)
        cand_t = cand_t.replace(old, new, 1)
        say(f"ok {name}")

    # --- guards ---------------------------------------------------------
    tail_base = base_d.split("## 4 Discussion")[1]
    tail_cand = cand_d.split("## 4 Discussion")[1]
    guards = [
        ("pin v0.43", "Draft v0.43" in cand_d and "Draft v0.42" not in cand_d),
        ("blade base clause",
         "The base span reads 0.75 of the rotor radius, and the base chord reads 0.113 of it." in cand_d
         and "The power sizing sets the radius for the rotor at its local wind speed (NR-050)." in cand_d),
        ("cone at 2.1",
         "The shaft transition cone holds one fixed angle, 22 degrees, by construction." in cand_d
         and "It is not a search gene (NR-049)." in cand_d),
        ("cone at 3.5",
         "in every machine of the campaign (NR-049)." in cand_d
         and "A later campaign can vary it." in cand_d),
        ("cold-path line", "The campaign scored every design on the cold path (NR-012)." in cand_d),
        ("scale context",
         "This campaign is the first screen after the physics-validation era." in cand_d
         and "Larger and wider campaigns sit ahead." in cand_d),
        ("swing reading", "The machine held a steady operating point through the measurement window." in cand_d),
        ("lifter rationale",
         "Without modulation, each weather band would need its own single kite." in cand_d
         and "That kite would reach giant sizes and be too hard to handle." in cand_d),
        ("staged launch",
         "The report also assumes a staged launch of the stack." in cand_d
         and "A staged launch is easier to handle than one giant kite." in cand_d),
        ("blade-slot names",
         "The main-rotor slot, `blade_scale_top`, reads 0.82 and decodes to the single active rotor." in cand_d
         and "The second-rotor slot, `blade_scale_bottom`, reads 0.20 and stays inactive" in cand_d),
        ("bank-slot naming",
         "The second bank slot holds `bank_bottom`." in cand_d
         and "It reads 22 degrees at the top of its search box." in cand_d
         and "It does not decode to a physical rotor at a rotor count of one (NR-011, NR-017)." in cand_d),
        ("old forms gone",
         "up to a giant." not in cand_d
         and "Slot 1 reads" not in cand_d
         and "Slot 2 reads" not in cand_d
         and "A second bank slot reads" not in cand_d
         and "at a count of one (NR-011)." not in cand_d),
        ("two 22-degree facts apart",
         cand_d.count("22 degrees") == 3 and cand_d.count("holds one fixed angle, 22 degrees") == 2),
        ("frozen levers block held once", cand_d.count(block) == 1),
        ("sections 4 to end unchanged", tail_cand == tail_base),
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
        ("tracker v0.43 entry", "v0.43 pass by @author" in cand_t),
        ("tracker history held",
         "v0.42 pass by @author" in cand_t and "v0.41 fold pass by @figures-images-diagrams" in cand_t),
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
