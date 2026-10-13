#!/usr/bin/env python3
"""Draft v0.27 — founder docx-return fold (author seat, 2026-10-13).

Folds the returned forms (the founder docx return; capture set c2e2aee,
extract au_draft_docx_notes_extract_2026-10-13.md) into the draft front
quarter, abstract to section 2.2.

Two-state, fail-closed:
  - builds from `git show HEAD:<draft>` (never from the working file)
  - asserts every anchor exactly once
  - runs the STE gate on base and candidate (candidate must not exceed baseline)
  - runs the numeric token diff against the declared expected delta
  - runs the register-seat citation checker

Usage:
  python3 scratch/au_docx_v027_fold.py          # build, gate, report (no writes to the draft)
  python3 scratch/au_docx_v027_fold.py --write  # copy the candidate over the draft (only after all gates pass)
"""
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRAFT_REL = "docs/reporting/drafts/2026-10-08-report-first-draft.md"
REG = "docs/reporting/numbers-register.md"
BASE_P = ROOT / "scratch/au_docx_v027_base.md"
CAND_P = ROOT / "scratch/au_docx_v027_candidate.md"
LOG_P = ROOT / "scratch/au_docx_v027_fold.log"

EXPECT_ADD = {"11.01": 1, "9.41": 1, "15.0": 1, "27": 1, "19": 1, "2.2": 2, "1": 1, "2": 1}
EXPECT_REM = {"26": 1, "14.972": 1, "2.3": 1}

PAIRS = [
    # P0 — version pin
    ("P0 version pin",
     "Internal engineering report. Draft v0.26. Date 2026-10-13.",
     "Internal engineering report. Draft v0.27. Date 2026-10-13."),

    # P1 — abstract: load law, kite turbine
    ("P1 abstract load",
     "A differential-evolution campaign evaluated 930 candidate designs under a\nfixed power-law generator load, each on the measurement window (NR-001).",
     "A differential-evolution campaign evaluated 930 candidate kite turbine\ndesigns under one fixed power-law generator load, each on the measurement\nwindow (NR-001)."),

    # P2 — abstract: winner sentence, wind basis
    ("P2 abstract winner",
     "The campaign winner is the best feasible candidate under the modeled\nobjective and gates. Its mean power is 5.309 kilowatts (NR-008) and its\nminimum factor of safety is 14.972 (NR-009).",
     "The campaign winner is the best feasible candidate kite turbine under the\nmodeled objective and gates. Its mean power is 5.309 kilowatts at the\nsite wind, 11.01 m/s at 9.41 m (NR-008, NR-032)."),

    # P3 — abstract: FoS sentence, 1 dp form
    ("P3 abstract FoS",
     "All checked TRPT rings and twist segments operate below their failure\nboundaries at the final operating point (NR-021, NR-022).",
     "All checked TRPT rings and twist segments operate below their failure\nboundaries at the final operating point (NR-021, NR-022).\n\nThe minimum factor of safety is 15.0 (NR-009)."),

    # P4 — abstract: segment torque margin gloss and S1
    ("P4 abstract margin gloss",
     "At the winner operating point, the least segment torque margin is\n2.03, at S1 (NR-040).",
     "At the winner operating point, the least segment torque margin is\n2.03, at S1, the first of the five segments between the rings (NR-040).\nThe margin is torque capacity over the segment torque it carries, and the\nleast value governs."),

    # P5 — abstract: repo clause, bank derate gloss
    ("P5 abstract derate",
     "All numbers\ncome from the physics era `post-95c385d_wind-authority`, with the bank\nderate applied.",
     "All numbers are in the repo and\ncome from the physics era `post-95c385d_wind-authority`, with the bank\nderate applied. The bank derate is a calculated depowering of the ring\noutput, because banked blades sweep less streamtube frontal area."),

    # P6 — abstract: simulation-only limits
    ("P6 abstract limits",
     "The study is simulation-only. Blade integrity is not yet gated, and\nlifter modulation across wind speeds remains an assumption. The\nrope-break gate placement fix stays open.",
     "The study is simulation-only. Blade integrity is not yet gated, and the\nouter stiffening bridles sit outside the model.\n\nLifter kite modulation\nfor steady lift tension across wind speeds remains an assumption. The\nrope-break gate placement fix stays open."),

    # P7 — section 1: opening
    ("P7 intro opening",
     "The wind above tower height is stronger and steadier than the wind a\ntower mounted wind turbine reaches. Airborne wind energy systems (AWES) are machines that chase that stronger\nwind. Two families of AWES exist.",
     "The wind above tower height is stronger and steadier than the wind\nexploited by traditional wind turbines. Airborne wind energy systems\n(AWES) are kite-based machines that chase that stronger wind.\n\nTwo families of AWES exist."),

    # P8 — section 1: fly-gen
    ("P8 intro flygen",
     "Fly-gen machines carry the generator aloft. A conducting tether sends\nthe electrical power to the ground.",
     "Fly-gen machines carry the generator and turbine aloft. A conducting\ntether sends the electrical power to the ground."),

    # P9 — section 1: ground-gen
    ("P9 intro groundgen",
     "Ground-gen machines keep the generator on the ground. The tether\ncarries force, and the ground station converts it.",
     "Ground-gen machines keep the generator on the ground. The tether\ncarries force, and the ground station converts tether motion to\nelectrical power."),

    # P10 — section 1: second split
    ("P10 intro split",
     "The field splits a second way, on the wing. Soft wings use fabric.\nThey survive crashes and pack small. Rigid wings use composite\nairframes. They hold efficiency and cost more.",
     "The field splits a second way, on the wing.\n\nSoft wings use fabric. They survive crashes and pack small.\n\nRigid wings use composite airframes. They are more efficient and more\ncostly."),

    # P11 — section 1: blades
    ("P11 intro blades",
     "Kite turbines exploit short rigid blades. The blades sit on a ring and\nform a wide diameter rotor.",
     "Kite turbines exploit multiple, short rigid blades. The blades sit on a\nring and form a wide diameter rotor."),

    # P12 — section 1: TRPT rings
    ("P12 intro trpt",
     "A tensile rotary power transmission (TRPT) is a shaft made of\ntensioned lines. Rings sit apart under tension. Torque passes from\nring to ring.",
     "A tensile rotary power transmission (TRPT) is a shaft made of\ntensioned lines. Rings sit at fixed distances under tether tension.\nTorque passes from ring to ring, over multiple tethers."),

    # P13 — section 1: shaft bends
    ("P13 intro shaft",
     "The shaft bends and twists without a rigid driveshaft. Its capacity to transmit torque\ncomes from tension itself.",
     "The TRPT shaft is prone to bending and twisting, especially in low\ntension. It is not a rigid driveshaft. Its capacity to transmit torque\ncomes from the tension in the kite lines."),

    # P14 — section 1: design space
    ("P14 intro search",
     "This report presents a search over the design space of that machine.\nThe search varies ring geometry, polygon count, rotor count, blade bank\nangles and blade scale.",
     "This report presents a search over the design space of kite turbines.\nThe search varies ring geometry, polygon count, rotor count, blade bank\nangles and blade scale."),

    # P15 — section 1: objective and constraints pointer
    ("P15 intro objective",
     "The objective is to find the feasible geometries for a 5 kW-class\nmachine. The generator load law and the safety gates stay fixed.\nThe search asks whether one compact machine can hold the power, mass,\nstructural, clearance and twist constraints at once.",
     "The objective is to find the feasible geometries for a 5 kW-class\nmachine, and then characterise them.\n\nThe generator load law and the\nsafety gates stay fixed. The search asks whether one compact machine\ncan hold the power, mass, structural, clearance and twist constraints\nat once.\n\nThe report reads the gate and the winner outcome for each\nconstraint in the results."),

    # P16 — section 1: failure classes
    ("P16 intro failures",
     "The report states what the record supports. It also states the failures,\neach with its lesson.",
     "The report states what the record supports. It also states several\nclasses of failure in developing this system, each with its lesson."),

    # P17 — section 1: literature splits and order
    ("P17 intro literature",
     "The field context rests on the literature. Loyd showed that both\ncrosswind modes share one theoretical power ceiling.\n\nTrevisi built one power model for both modes and found the glide-ratio\nflip. Cherubini mapped the ground-gen and fly-gen taxonomy. Diehl set\nthe classification axes.",
     "The field context rests on the literature.\n\nLoyd showed that both crosswind modes share one theoretical power\nceiling.\n\nDiehl set the classification axes.\n\nTrevisi built one power model for both modes and found the glide-ratio\nflip.\n\nCherubini mapped the ground-gen and fly-gen taxonomy."),

    # P18 — section 1: Flather/Ranneberg split
    ("P18 intro flather",
     "Flather recorded the rope-drive physics that the TRPT descends from.\nBenhaïem and Schmehl analysed the torque path of a rotating reel.\nRanneberg gave the rotary family a momentum frame with flight data.",
     "Flather recorded the rope-drive physics that the TRPT descends from.\nBenhaïem and Schmehl analysed the torque path of a rotating reel.\n\nRanneberg gave the rotary family a momentum frame with flight data."),

    # P19 — 2.1 heading
    ("P19 heading 2.1",
     "### 2.1 The machine and its terms \n",
     "### 2.1 The kite turbine and its terms\n"),

    # P20 — 2.1 spacers
    ("P20 terms spacers",
     "Rings without blades work as spacers. They hold the TRPT lines apart\nagainst the line torsion from torque transfer. Holding the lines apart is\nwhat preserves torque transmission.",
     "Rings without blades work as line spacers. They hold the TRPT lines\napart against the line torsion from torque transfer. Holding the lines\napart is what preserves torque transmission and prevents torsional\ncollapse."),

    # P21 — 2.1 polygon count and PTO ring
    ("P21 terms polygon pto",
     "The polygon count names the number of lines. Each line meets the ring at\none vertex. The polygon count equals the blade count.\n\nThe topmost ring carries the main rotor. The lowest ring is the\nground ring. A rotor is a set of blades on a ring.",
     "The polygon count names the number of lines (n_Lines). A hexagonal\npolygon connects six lines. Each line meets the ring at one vertex.\n\nThe polygon count also equals the blade count. A rotor is a set of blades\non a ring. A pentagonal rotor carries five blades.\n\nThe topmost ring carries the main rotor. The lowest ring is the ground\nstation power take-off (PTO) ring. The PTO ring anchors the shaft at the\nground and turns about its central axis."),

    # P22 — 2.1 bank, blade scale, gene list
    ("P22 terms genes",
     "Bank is the blade angle away from the ring plane about its chord axis at the ring. \nBlade scale sets the blade size. The search treats each of these as a gene.",
     "Bank is the blade angle away from the ring plane about its chord axis at\nthe ring. Blade scale sets the blade size. The scale multiplies the\nblade span and chord, and the blade mass follows the span cubed.\n\nThe search treats each of these as a gene. The ring geometry sets the\nhub and ground radii, and the rotor count sets how many rings carry\nblades."),

    # P23 — section 2.2 retitle, 2.2.1, block-diagram request, 2.2.2 heading
    ("P23 2.2 restructure",
     "### 2.2 The genome\n\nThe genome is the design vector. The decoder reads it. The builder\nbuilds the machine.\n\nThe genes set the ring geometry, the polygon count, the rotor count,\nthe bank angles and the blade scales. The winner genome names its\ngenes in the decode fields (NR-011).\n\n### 2.3 The evaluator    ",
     "### 2.2 The simulation analysis pipeline instrument and its terms\n\n#### 2.2.1 The gene\n\nThe search uses differential evolution (DE) to assess kite turbine\ndesign variants. DE assesses machine genomes. A genome is a design\nvector that describes the physical character of one machine.\n\nThe decoder reads it, and the builder builds the machine from it. The\nevaluation then feeds the comparison before DE tries a new gene.\n\nThe genes set the ring geometry, the polygon count, the rotor count,\nthe bank angles and the blade scales. The winner genome names its genes\nin the decode fields (NR-011).\n\n[Systems block diagram requested: figure-map row 19 (the simulation\nanalysis pipeline instrument). Gate: the pipeline schema extract.]\n\n#### 2.2.2 The evaluator"),
]

TOK = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")


def run(cmd):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


def lint(path):
    r = run(["python3", "ste-lint.py", "--fail-above", "2.0", str(path)])
    m = re.search(r"total=\s*(\d+)\s+per100w=\s*([\d.]+)", r.stdout)
    total = int(m.group(1)) if m else None
    cats = Counter()
    for line in r.stdout.splitlines():
        mm = re.match(r"\[HOOK:ste\].*?: ([a-z_()>0-9w]+) x(\d+)", line)
        if mm:
            cats[mm.group(1)] += int(mm.group(2))
    return r.returncode, total, dict(cats), r.stdout


def main():
    write = "--write" in sys.argv
    log = []

    def say(s):
        print(s)
        log.append(s)

    head = run(["git", "rev-parse", "--short", "HEAD"]).stdout.strip()
    say(f"base tip: {head}")

    base = run(["git", "show", f"HEAD:{DRAFT_REL}"]).stdout
    BASE_P.write_text(base)

    text = base
    for name, anchor, repl in PAIRS:
        c = text.count(anchor)
        if c != 1:
            say(f"ANCHOR FAIL {name}: count={c}")
            LOG_P.write_text("\n".join(log))
            sys.exit(1)
        text = text.replace(anchor, repl, 1)
        say(f"ok {name}")

    # leftover guards
    guards = [
        ("old pin gone", "Draft v0.26" not in text),
        ("old genome heading gone", "### 2.2 The genome" not in text),
        ("old evaluator heading gone", "### 2.3 The evaluator" not in text),
        ("new pin present", "Draft v0.27" in text),
        ("new heading present", "#### 2.2.2 The evaluator" in text),
    ]
    for label, ok in guards:
        say(f"guard {label}: {'ok' if ok else 'FAIL'}")
        if not ok:
            LOG_P.write_text("\n".join(log))
            sys.exit(1)

    CAND_P.write_text(text)

    rc_b, tot_b, cats_b, _ = lint(BASE_P)
    rc_c, tot_c, cats_c, out_c = lint(CAND_P)
    say(f"STE base: rc={rc_b} total={tot_b} {cats_b}")
    say(f"STE candidate: rc={rc_c} total={tot_c} {cats_c}")
    ste_ok = (rc_c == 0 and tot_c is not None and tot_b is not None and tot_c <= tot_b)

    ta, tb = Counter(TOK.findall(base)), Counter(TOK.findall(text))
    add, rem = dict(tb - ta), dict(ta - tb)
    tok_ok = (add == EXPECT_ADD and rem == EXPECT_REM)
    say(f"token delta add: {add}")
    say(f"token delta rem: {rem}")
    say(f"token check: {'PASS' if tok_ok else 'FAIL (expected add ' + str(EXPECT_ADD) + ' rem ' + str(EXPECT_REM) + ')'}")

    r = run(["python3", "scratch/sv_check_draft_citations.py", str(CAND_P), REG])
    cite_ok = (r.returncode == 0)
    say(f"citation checker: rc={r.returncode}")
    say(r.stdout.strip())
    if r.stderr.strip():
        say(r.stderr.strip())

    all_ok = ste_ok and tok_ok and cite_ok
    say(f"GATES: ste={'pass' if ste_ok else 'fail'} tokens={'pass' if tok_ok else 'fail'} citations={'pass' if cite_ok else 'fail'}")
    LOG_P.write_text("\n".join(log))

    if write:
        if not all_ok:
            say("--write refused: gates not green")
            sys.exit(1)
        shutil.copyfile(CAND_P, ROOT / DRAFT_REL)
        say(f"draft written: {DRAFT_REL}")


if __name__ == "__main__":
    main()
