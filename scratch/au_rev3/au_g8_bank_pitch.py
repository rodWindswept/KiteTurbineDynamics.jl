#!/usr/bin/env python3
"""G8 fold: split bank and pitch into blade and rotor levels.

Founder ruling (2026-10-20): "We can have Blade bank and rotor bank ... just as
we can have blade pitch and rotor pitch."  The glossary defines the four terms
at the two levels.  Reading of rotor bank as the whole-rotor setting (the cone)
rests on founder comment 72 ("the cone shape of rotor bank") and the source's
one bank angle per rotor (src/types.jl:95; src/bem.jl project factor).

Two-state: base = current draft; already-applied = verified and skipped.
Run plain to review; --land writes the tracked files.
"""
import re
import subprocess
import sys
from pathlib import Path

REPO = Path("/home/rod/Documents/GitHub/KiteTurbineDynamics.jl")
DRAFT = REPO / "docs/reporting/drafts/2026-10-08-report-first-draft.md"
TRACKER = REPO / "docs/reporting/draft-tracker.md"
CAND = REPO / "scratch/au_rev3/G8_candidate.md"
CAND_T = REPO / "scratch/au_rev3/G8_tracker_candidate.md"

OLD_GLOSS = """Bank is the blade angle away from the plane of rotation about its chord axis at the ring.
The equivalent term in AeroDyn is pre-cone.
The machine plates show the blade leaning downward.
"""

NEW_GLOSS = """Blade bank is the blade angle away from the plane of rotation about its chord axis at the ring.
The equivalent term in AeroDyn is pre-cone.
Rotor bank is that angle set for the whole rotor, so every blade carries it.
Blade pitch is the angle of one blade about its span axis.
Rotor pitch is that angle set for the whole rotor, as collective pitch.
The machine plates show the blade leaning downward.
"""

OLD_PIN = "Internal engineering report. Draft v0.67. Date 2026-10-19."
NEW_PIN = "Internal engineering report. Draft v0.68. Date 2026-10-20."

ENTRY = """v10 (2026-10-20): the bank and pitch terms split into blade and rotor levels (author).

Blade bank keeps its definition, and rotor bank now reads as the whole-rotor setting every blade carries.
Blade pitch and rotor pitch take the same split, so rotor pitch reads as collective pitch.
The split follows the founder ruling and reads rotor bank as the cone, per comment 72.

The section 6.1 bridle paragraph and the tilt wording land with it, from the founder bridle ruling.
The lean sentence keeps its short form and no target clause.
No number and no citation moves.
The draft ticks to v0.68.

"""

TOKEN = re.compile(r"(?<![\w-])\d+(?:\.\d+)?(?![\w-])")


def tokens(text):
    text = re.sub(r"\b[0-9a-f]{64}\b", "<HASH>", text)
    return sorted(TOKEN.findall(text))


def main():
    land = "--land" in sys.argv
    base = DRAFT.read_text()
    tbl = TRACKER.read_text()

    applied = NEW_GLOSS in base and NEW_PIN in base
    if not applied:
        assert base.count(OLD_GLOSS) == 1, f"gloss anchor count {base.count(OLD_GLOSS)}"
        assert base.count(OLD_PIN) == 1, f"pin anchor count {base.count(OLD_PIN)}"
        cand = base.replace(OLD_GLOSS, NEW_GLOSS).replace(OLD_PIN, NEW_PIN)
    else:
        cand = base

    if "v10 (2026-10-20): the bank and pitch terms split" in tbl:
        cand_t = tbl
    else:
        anchor = "## 2. Working notes"
        assert tbl.count(anchor) == 1, "tracker section-2 anchor"
        cand_t = tbl.replace(anchor, ENTRY + anchor)

    CAND.write_text(cand)
    CAND_T.write_text(cand_t)

    print(f"draft applied={applied} lines {len(base.splitlines())} -> {len(cand.splitlines())}")
    print(f"draft words {len(base.split())} -> {len(cand.split())}")
    print(f"tracker lines {len(tbl.splitlines())} -> {len(cand_t.splitlines())}")

    add = [t for t in tokens(cand) if t not in tokens(base)]
    rem = [t for t in tokens(base) if t not in tokens(cand)]
    print("tokens added:", sorted(set(add)))
    print("tokens removed:", sorted(set(rem)))

    for label, path in (("base", None), ("cand", CAND)):
        if path is None:
            tmp = REPO / "scratch/au_rev3/G8_base.md"
            tmp.write_text(base)
            path = tmp
        out = subprocess.run(
            ["python3", "ste-lint.py", "--fail-above", "2.0", str(path)],
            cwd=REPO, capture_output=True, text=True,
        )
        print(f"lint {label}: rc={out.returncode} {out.stdout.strip()}")

    if land:
        assert not applied or True
        DRAFT.write_text(cand)
        TRACKER.write_text(cand_t)
        print("landed")


if __name__ == "__main__":
    main()
