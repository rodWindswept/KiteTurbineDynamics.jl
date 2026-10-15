#!/usr/bin/env python3
# scratch/sw_r6leg_apply.py — science-writer, 2026-10-15.
# The round-6 legs: the tracker takes the short name (2 sites); the candidates
# take the guard extension, the retire-list extension and the pair re-key;
# the stale-phrases list re-forms the two claims and records the ring-name
# retirement. Assertion-guarded: a wrong count aborts with nothing written.
import sys

OK = True

def apply(path, edits):
    global OK
    with open(path, encoding="utf-8") as f:
        t = f.read()
    orig = t
    for old, new, expect in edits:
        n = t.count(old)
        print(f"[{path}] count={n} expect={expect} :: {old[:72]!r}")
        if n != expect:
            print(f"ABORT: {path} — count {n} != {expect}")
            OK = False
            continue
        t = t.replace(old, new)
    if OK and t != orig:
        with open(path, "w", encoding="utf-8") as f:
            f.write(t)
        print(f"WRITTEN: {path}")
    elif not OK:
        print(f"SKIPPED (abort): {path}")
    else:
        print(f"UNCHANGED: {path}")

TRACKER = "docs/reporting/draft-tracker.md"
CAND = "docs/reporting/glossary-candidates.md"
SP = "docs/agents/stale-phrases.md"

apply(TRACKER, [
    ("the capture hub ring reads 15.033 at the final step",
     "the capture topmost ring reads 15.033 at the final step", 1),
    ("the capture hub ring reading keeps its form",
     "the capture topmost ring reading keeps its form", 1),
])

apply(CAND, [
    ('Never write "hub rotor".',
     'Never write "hub rotor" or "hub ring".', 1),
    ("| ground ring | The bottom of the TRPT. It is free to rotate, and it is the PTO end. "
     "One of only two parts that touch the ground. | physics-topology 1 | ratify |",
     "| ground ring | The bottom of the TRPT. It is free to rotate, and it is the PTO end. "
     "One of only two parts that touch the ground. | physics-topology 1 | ratify |\n"
     '| topmost ring | The ring at the top of the TRPT. It carries the main rotor. '
     'The full name is "topmost rotor ring". The name "hub ring" retires (Rod, 2026-10-14). '
     "| physics-topology 4, CONTEXT.md | ratify |", 1),
    ('| "hub rotor", or "hub" for a rotor | main rotor, topmost rotor | stale-phrases, physics-topology 4 | ratify |',
     '| "hub rotor", or "hub" for a rotor or the ring | main rotor, topmost ring | stale-phrases, physics-topology 4 | ratify |', 1),
    ("**Status** PREP v15, numbers-free by construction",
     "**Status** PREP v16, numbers-free by construction", 1),
    ('The rename lands with the draft\n  section 2.4 sentence, so the term gate reads one form. No other\n  change.',
     'The rename lands with the draft\n  section 2.4 sentence, so the term gate reads one form. No other\n  change.\n\n- **v16 (2026-10-15):** the hub-name retirement re-keys the ring\n'
     '  pair. The topmost ring row joins the machine group beside the\n'
     '  ground ring. The main-rotor guard and the retire list take the\n'
     '  ring name. The rename lands with the round-6 fold, so the term\n'
     '  gate reads one form. No other change.', 1),
])

apply(SP, [
    ("## The hub ring hosts ONLY the cp/ct rotor",
     "## The topmost ring hosts ONLY the cp/ct rotor", 1),
    ("## expansion_params_from_rotors excludes the decoder's hub rotor",
     "## expansion_params_from_rotors excludes the decoder's topmost rotor", 1),
    ('Replacement: main rotor (the topmost rotor). "Hub" is not a rotor term — see docs/agents/physics-topology.md §4',
     'Replacement: main rotor (the topmost rotor). "Hub" is not a rotor term, and it does not name the ring — see docs/agents/physics-topology.md §4\n'
     'Note (2026-10-14): the part reads "topmost ring", or "topmost rotor ring" in full (Rod, 2026-10-14). '
     "The code identifiers and the recorded pages hold their spelling.", 1),
])

print("RESULT:", "OK" if OK else "ABORTED — nothing partially written where aborted")
sys.exit(0 if OK else 1)
