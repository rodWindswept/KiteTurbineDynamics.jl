#!/usr/bin/env python3
# fig_br2_docs_edit.py — the relabel closures fold back (figures seat, 2026-10-15)
# Verify-all-then-apply. Every (old, new) pair must match exactly once.
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

P = []

FM = "docs/reporting/figures/figure-map.md"
P.append((FM, [
    ('The lifting-bridles relabel lands (script `9241b23`): the chain label reads "lifting bridles (three)". Next: the aero counter-read of the re-cut, then the visual pass by Rod',
     'The lifting-bridles relabel lands (script `9241b23`): the chain label reads "lifting bridles (three)". The caption text and the copy take the forms (v0.49). The aero counter-read closes clean (`79da87c`, 273 checks; the chain re-runs byte-identical at five locations). Next: the visual pass by Rod'),
    ('The title takes the winner form (the founder note 2026-10-15): "hero" stops as a figure label. Next: the aero counter-read, then the visual pass by Rod',
     'The title takes the winner form (the founder note 2026-10-15): "hero" stops as a figure label. The winner-form sites take the forms in the draft (v0.49). The aero counter-read closes clean (`79da87c`). Next: the visual pass by Rod'),
    ('  Row 10\'s title takes the winner form: "hero" stops as a figure\n  label on the map. Next: the aero counter-read of the relabel and\n  the winner-form re-keys.',
     '  Row 10\'s title takes the winner form: "hero" stops as a figure\n  label on the map. Next: the aero counter-read of the relabel and\n  the winner-form re-keys.\n\n- **v41 (2026-10-15):** the relabel closures fold back. The caption\n  text and the copy take the forms (author v0.49, `8169e36`). The term\n  gate closes (`08b8523`, 105 checks) and the aero counter-reads close\n  (`79da87c`, 273 checks). The kit SPEC closes its caption leg. Rows 2\n  and 10 take the closure and read the visual pass by Rod as their next\n  gate. No plate byte moves.'),
]))

SPEC = "docs/reporting/figures/system-anatomy/SPEC.md"
P.append((SPEC, [
    ('- The lifting-bridles relabel (2026-10-15): the chain label reads\n  "lifting bridles (three)" (the v7 re-cut). The caption text re-keys\n  at the author pass.',
     '- Closed: the lifting-bridles relabel (v7 re-cut, 2026-10-15). The\n  chain label reads "lifting bridles (three)". The caption text and the\n  copy take the forms (author v0.49). No value moves.'),
]))

CAP = "docs/reporting/figures/system-anatomy/captions.md"
P.append((CAP, [
    ('Relabel note (2026-10-15): the lifting-bridles relabel (the founder\nnote). The plate re-renders with the chain label "lifting bridles\n(three)". The caption text re-keys at the author pass. No value\nmoves.',
     'Relabel note (2026-10-15): the lifting-bridles relabel (the founder\nnote). The plate re-renders with the chain label "lifting bridles\n(three)". The caption text re-keyed at the author pass (v0.49). No\nvalue moves.'),
]))

RS = "docs/reporting/figures/system-anatomy/register-status.md"
P.append((RS, [
    ('**Delta** v5 (2026-10-15): the v7 re-cut lands. The chain label takes\nthe founder form. Script commit `9241b23`. The caption sentence re-keys\nat the author pass. No value moves.',
     '**Delta** v5 (2026-10-15): the v7 re-cut lands. The chain label takes\nthe founder form. Script commit `9241b23`. The caption sentence re-keyed\nat the author pass (v0.49). No value moves.'),
]))

SEAT = "handovers/handover-2026-10-14-reporting-room-figures-images-diagrams.md"
P.append((SEAT, [
    ('This refresh records the lifting-bridles relabel, the corner counter-read closure and the cite fixes (2026-10-15).',
     'This refresh records the relabel closures (the author fold at v0.49, the term gate, the counter-reads), the corner counter-read closure and the cite fixes (2026-10-15).'),
    ('1. **The lifting-bridles relabel (map row 2).** The chain label lands (script `9241b23`): the F1 plate reads "lifting bridles (three)". The caption text, the copy embed and the appendix exhibit name re-key at the author pass. The aero counter-read of the re-cut queues; the visual pass by Rod follows.\n\n2. **The winner-form re-keys (row 10).** The map title takes the winner form; the appendix exhibit name re-keys at the author pass. The aero counter-read queues.\n\n3. **The visual pass by Rod.** The corner grid, the winner plate, the F1 plate and rows 4 to 7 read the visual pass as their next gate (map v38, v39, v40). The plates carry the round-6 top forms. The winner plate reads §3.3, ahead of the plates. It moves earlier in one line if the room calls.',
     '1. **The visual pass by Rod.** The corner grid, the winner plate, the F1 plate and rows 4 to 7 read the visual pass as their next gate (map v38 to v41). The plates carry the round-6 top forms and the relabel. The winner plate reads §3.3, ahead of the plates. It moves earlier in one line if the room calls.'),
    ('## Closed, last (evidence index)\n\n- The lifting-bridles relabel lands (2026-10-15):',
     '## Closed, last (evidence index)\n\n- The relabel closures fold back (2026-10-15): the caption text and the copy take the forms (author v0.49, `8169e36`); the term gate closes (`08b8523`, 105 checks); the aero counter-reads close (`79da87c`, 273 checks); the kit SPEC closes its caption leg. Receipt `docs/reporting/room-responses/figures-images-diagrams-2026-10-15-relabel-closures-foldback.md`. Evidence `scratch/fig_br2_check.py` plus the log.\n\n- The lifting-bridles relabel lands (2026-10-15):'),
    ('**Owner:** @fig-img-diagrams (figures-images-diagrams). **Next action:** the aero counter-read of the F1 relabel and the winner-form re-keys (row 10). The visual pass by Rod follows.',
     '**Owner:** @fig-img-diagrams (figures-images-diagrams). **Next action:** the visual pass by Rod (the corner grid, the winner plate, the F1 plate and rows 4 to 7).'),
]))

# ---- phase 1: verify --------------------------------------------------------
problems = []
for rel, pairs in P:
    txt = (ROOT / rel).read_text(encoding="utf-8")
    for old, new in pairs:
        n = txt.count(old)
        if n != 1:
            problems.append(f"{rel}: count={n} for: {old[:80]!r}")
if problems:
    print("VERIFY FAILED — nothing written")
    for p in problems:
        print(" ", p)
    sys.exit(1)
print("verify ok: all pairs match exactly once")

# ---- phase 2: apply ---------------------------------------------------------
for rel, pairs in P:
    fp = ROOT / rel
    txt = fp.read_text(encoding="utf-8")
    for old, new in pairs:
        txt = txt.replace(old, new, 1)
    fp.write_text(txt, encoding="utf-8")
    print("applied:", rel, f"({len(pairs)} pairs)")
