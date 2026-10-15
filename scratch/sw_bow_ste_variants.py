#!/usr/bin/env python3
"""STE variant test for the bow row and its guard row (round 2).

Builds the two-row candidate for each wording variant, lints it with ste-lint,
and reports the offender lines added against the pinned baseline.  The only
structural edit outside the two rows is the status token, so the reflow artifact
of round 1 is gone.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SK = pathlib.Path("/home/rod/.hermes/profiles/science-writer/skills/windswept/ktd-reporting/scripts")
BASE = ROOT / "scratch/sw_bow_base.md"
TMP = ROOT / "scratch/_ste_variants"
TMP.mkdir(exist_ok=True)

base_text = BASE.read_text()
base_lines = base_text.splitlines()
ANCHOR = [l for l in base_lines if l.startswith("| destructive resonance |")][0]
RETIRE = [l for l in base_lines if l.startswith("| \"physics-validation era\"")][0]
STATUS_OLD = "**Status** PREP v19, numbers-free by construction (no measurement values, no"
STATUS_NEW = "**Status** PREP v20, numbers-free by construction (no measurement values, no"

SENT = {
    "S1": "The settle calculation and the run must agree on it.",
    "S2": "The settle and the run must agree on it.",
}
GROUND = {
    "G1": "`DECISIONS.md` [2026-09-15] ruling 2, the 2026-09-12 handover sections 2 and 5",
    "G4": "`DECISIONS.md` [2026-09-15] ruling 2, 2026-09-12 handover sections 2 and 5",
    "G5": "`DECISIONS.md` [2026-09-15] ruling 2, 2026-09-12 handover section 5",
}

GUARD = ("| \"bow\" as a sideways move, or a stack translation | bow: a line rearrangement "
         "at near-constant length. The stack does not translate sideways. | "
         "`DECISIONS.md` [2026-09-15] ruling 2 |")

PREFIX = ("The lateral sag of the column axis off the design line, in the tilted plane. "
          "The perpendicular part of the hub weight causes it. The stack does not translate "
          "sideways: the bow is a rearrangement in which the lines reorient at near-constant "
          "length. The report holds it as an output, not a constraint. ")


def offenders(path):
    out = subprocess.run([sys.executable, str(SK / "lint-offenders.py"), "ste-lint.py", str(path)],
                         cwd=ROOT, capture_output=True, text=True).stdout
    lines = [l for l in out.splitlines() if l.strip()]
    return set(lines[1:]) if lines else set()


base_off = offenders(BASE)
print(f"baseline offenders: {len(base_off)}\n")

for gname, ground in GROUND.items():
    for sname, sent in SENT.items():
        row = f"| bow | {PREFIX}{sent} | {ground} | supply |"
        text = base_text.replace(STATUS_OLD, STATUS_NEW, 1)
        text = text.replace(ANCHOR, ANCHOR + "\n" + row, 1)
        text = text.replace(RETIRE, RETIRE + "\n" + GUARD, 1)
        p = TMP / f"r2_{gname}_{sname}.md"
        p.write_text(text)
        added = sorted(a.strip() for a in (offenders(p) - base_off))
        print(f"{gname} {sname}: " + ("CLEAN" if not added else "ADDED " + " | ".join(added)))
