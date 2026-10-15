#!/usr/bin/env python3
# scratch/sv_br_gate_edits.py — science-validator, 2026-10-15.
#
# The lifting-bridles term gate closure edits (assert-guarded, count==1 each):
#  1. figure-generation-notes.md L23: the style line, the parked one-word flip,
#     closed at the gate seat (the brief names the member lines the plate draws).
#  2. captions-draft.md L43: the ledger-string list line, completing the caption
#     set declared in the scope read (the fold took L23 only).
#  3. physics-topology.md: the dated reader-name amend, after the section 2
#     terminology block (the hub-amend pattern, cb862df).
#  4. domain.md: the dated reader-name note under item 8 (its own block, so no
#     long-paragraph piece joins the item block).
# CONTEXT.md and the register hold (scope call; no edit).
import sys

EDITS = [
    (
        "docs/reporting/figures/figure-generation-notes.md",
        "TRPT lines, bridles (gold, as the dashboard), lift-chain lines",
        "TRPT lines, lifting bridles (gold, as the dashboard), lift-chain lines",
    ),
    (
        "docs/reporting/figures/system-anatomy/captions-draft.md",
        "  bridle, main rotor, ground ring, topmost ring, ground station, backline.",
        "  lifting bridles, main rotor, ground ring, topmost ring, ground station, backline.",
    ),
    (
        "docs/agents/physics-topology.md",
        'mean one of these four.\n\n### 2.1 The lift line & lifter kite boundary',
        'mean one of these four.\n\n**Reader name (Rod, 2026-10-15):** the report reads **lifting bridles** for the\nbearing-to-rotor member. The `DECISIONS.md` pages keep the **gold bridles**\nalias. The code identifiers and the recorded pages hold their spelling.\n\n### 2.1 The lift line & lifter kite boundary',
    ),
    (
        "docs/agents/domain.md",
        "   different tensions.\n9. **The lift chain must be TAUT.**",
        "   different tensions.\n   **Reader name (Rod, 2026-10-15):** the report reads *lifting bridles*. The\n   code and the recorded pages hold their spelling.\n9. **The lift chain must be TAUT.**",
    ),
]

ok = True
for path, old, new in EDITS:
    with open(path, encoding="utf-8") as f:
        t = f.read()
    n = t.count(old)
    if n != 1:
        print(f"FAIL {path}: target occurs {n} times, expected 1")
        ok = False
        continue
    with open(path, "w", encoding="utf-8") as f:
        f.write(t.replace(old, new, 1))
    print(f"edited: {path}")

sys.exit(0 if ok else 1)
