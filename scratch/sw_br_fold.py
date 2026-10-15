#!/usr/bin/env python3
"""The lifting-bridles term-set fold at the science-writer seat.

Base: the committed worktree at 3c4d2c8. Files: the glossary candidates
(v17), the figure-generation notes (the two routed sites), and the
stale-phrases list (the replacement texts plus the dated note).

Assertion-guarded: every hunk asserts exactly one occurrence, and each
file is written only after all of its hunks pass. The remaining
old-form counts are asserted against the intended sets (the ban quote,
the deferred notes line). Run from the repo root.
"""
import pathlib
import re

ROOT = pathlib.Path('.')
C = 'docs/reporting/glossary-candidates.md'
N = 'docs/reporting/figures/figure-generation-notes.md'
S = 'docs/agents/stale-phrases.md'

texts = {}


def load(rel):
    texts[rel] = (ROOT / rel).read_text()


def sub(rel, old, new):
    t = texts[rel]
    n = t.count(old)
    assert n == 1, f'{rel}: expected 1 occurrence, got {n}: {old[:70]!r}'
    texts[rel] = t.replace(old, new)


old_pat = re.compile(r'(?<!lifting )(?<!-)\bbridles?\b')

# --- 1. glossary candidates, v17 ---
load(C)
sub(C, 'lift bearing, bridles, main rotor.',
       'lift bearing, lifting bridles, main rotor.')
sub(C, 'It is never a bridle.', 'It is never a lifting bridle.')
sub(C, '| bridles (gold bridles) |', '| lifting bridles (gold lifting bridles) |')
sub(C, 'the apex of the bridle cone.', 'the apex of the lifting-bridle cone.')
sub(C, 'name each line: bridles, cyan line',
       'name each line: lifting bridles, cyan line')
sub(C, '**Status** PREP v16,', '**Status** PREP v17,')
v16_tail = ('- **v16 (2026-10-15):** the hub-name retirement re-keys the ring pair.\n'
            '  The topmost ring row joins the machine group beside the ground ring.\n'
            '  The main-rotor guard and the retire list take the ring name.\n'
            '  The rename lands with the round-6 fold, so the term gate reads one form.\n'
            '  No other change.')
assert texts[C].endswith(v16_tail + '\n'), 'candidates: v16 tail not found at EOF'
v17 = ('\n\n- **v17 (2026-10-15):** the lifting-bridles rename re-keys the lift-chain rows.\n'
       '  The term row, the chain list and the cyan-line guard take the founder form.\n'
       '  The lift-bearing row follows at the cone reference.\n'
       '  The rename lands with the lifting-bridles relabel.\n'
       '  No other change.')
texts[C] = texts[C][:-1] + v17 + '\n'
c_hits = [m.start() for m in old_pat.finditer(texts[C])]
assert len(c_hits) == 1, f'candidates: old-form count {len(c_hits)} != 1'
ln = texts[C][:c_hits[0]].count('\n')
assert 'bridles (cyan lines)' in texts[C].splitlines()[ln], 'candidates: the one old form is not the ban quote'

# --- 2. figure-generation notes: the two routed sites ---
load(N)
sub(N, 'Lift bearing, then three bridles (one per TRPT line) to the R6 vertices.',
       'Lift bearing, then three lifting bridles (one per TRPT line) to the R6 vertices.')
sub(N, 'load-bearing: bridle = bearing to rotor;',
       'load-bearing: lifting bridle = bearing to rotor;')
n_hits = [m.start() for m in old_pat.finditer(texts[N])]
assert len(n_hits) == 1, f'notes: old-form count {len(n_hits)} != 1'
ln = texts[N][:n_hits[0]].count('\n')
assert 'bridles (gold, as the dashboard)' in texts[N].splitlines()[ln], 'notes: the one old form is not the deferred line'

# --- 3. stale-phrases list: replacement texts plus the dated note ---
load(S)
sub(S, 'Replacement: bridles and the cyan line are different lines: bridles = lift bearing to main-rotor vertices (n_lines lines); cyan line = sky hook to lift bearing (1 line). See docs/agents/physics-topology.md §2',
       'Replacement: lifting bridles and the cyan line are different lines: lifting bridles = lift bearing to main-rotor vertices (n_lines lines); cyan line = sky hook to lift bearing (1 line). See docs/agents/physics-topology.md §2\n'
       'Note (2026-10-15): the lift-chain member reads "lifting bridles" (Rod, 2026-10-15).')
sub(S, 'Measured correct geometry ~3.99 m axial / ~4.66 m 3D bridle',
       'Measured correct geometry ~3.99 m axial / ~4.66 m 3D lifting bridle')
s_hits = [m.start() for m in old_pat.finditer(texts[S])]
assert len(s_hits) == 1, f'stale-phrases: old-form count {len(s_hits)} != 1'
ln = texts[S][:s_hits[0]].count('\n')
assert texts[S].splitlines()[ln] == '## bridles (cyan lines)', 'stale-phrases: old form outside the heading'

for rel, t in sorted(texts.items()):
    (ROOT / rel).write_text(t)
    print(f'wrote {rel}: {len(t.splitlines())} lines')
print('all assertions closed')
