#!/usr/bin/env python3
# scratch/sw_r6leg_apply2.py — science-writer, 2026-10-15. Second pass:
# verifies the tracker write from pass 1, then applies the candidates and
# stale-phrases hunks with corrected expected strings. Assertion-guarded.
import sys

OK = True

def verify(path, present, absent):
    global OK
    t = open(path, encoding="utf-8").read()
    for s in present:
        n = t.count(s)
        print(f"[{path}] VERIFY new present x{n}: {s[:70]!r}")
        if n != 1:
            OK = False
    for s in absent:
        n = t.count(s)
        print(f"[{path}] VERIFY old absent x{n}: {s[:70]!r}")
        if n != 0:
            OK = False

def apply(path, edits):
    global OK
    with open(path, encoding="utf-8") as f:
        t = f.read()
    for old, new, expect in edits:
        n = t.count(old)
        print(f"[{path}] count={n} expect={expect} :: {old[:72]!r}")
        if n != expect:
            print(f"ABORT: {path} — count {n} != {expect}")
            OK = False
            return
        t = t.replace(old, new)
    with open(path, "w", encoding="utf-8") as f:
        f.write(t)
    print(f"WRITTEN: {path}")

TRACKER = "docs/reporting/draft-tracker.md"
CAND = "docs/reporting/glossary-candidates.md"
SP = "docs/agents/stale-phrases.md"

verify(TRACKER,
       ["the capture topmost ring reads 15.033 at the final step",
        "the capture topmost ring reading keeps its form"],
       ["the capture hub ring"])

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
    ('| "hub rotor", or "hub" for a rotor | main rotor, topmost rotor | stale-phrases, physics-topology 4 |',
     '| "hub rotor", or "hub" for a rotor or the ring | main rotor, topmost ring | stale-phrases, physics-topology 4 |', 1),
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

print("RESULT:", "OK" if OK else "ABORTED")
sys.exit(0 if OK else 1)
