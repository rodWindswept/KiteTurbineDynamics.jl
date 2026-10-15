#!/usr/bin/env python3
"""The lifting-bridles term-set checker — science-writer, 2026-10-15.

Reads the three folded files and the probe logs; asserts every moved
string, the remaining old-form sets, the version delta, and the probe
counts. Prints one line per check; exits nonzero on any failure.
"""
import hashlib
import pathlib
import re
import sys

ROOT = pathlib.Path('.')
C = ROOT / 'docs/reporting/glossary-candidates.md'
N = ROOT / 'docs/reporting/figures/figure-generation-notes.md'
S = ROOT / 'docs/agents/stale-phrases.md'
CB = ROOT / 'scratch/sw_br_cand_base.md'

checks = 0
fails = 0


def ok(cond, label):
    global checks, fails
    checks += 1
    if cond:
        print(f'PASS {checks:02d} {label}')
    else:
        fails += 1
        print(f'FAIL {checks:02d} {label}')


c = C.read_text()
n = N.read_text()
s = S.read_text()
cb = CB.read_text()

old_pat = re.compile(r'(?<!lifting )(?<!-)\bbridles?\b')

# --- candidates ---
ok('**Status** PREP v17,' in c, 'candidates: status reads PREP v17')
ok('lift bearing, lifting bridles, main rotor.' in c, 'candidates: the chain list takes the new form')
ok('It is never a lifting bridle.' in c, 'candidates: the cyan-line guard names the member')
ok('| lifting bridles (gold lifting bridles) |' in c, 'candidates: the term row takes the new form')
ok('the apex of the lifting-bridle cone.' in c, 'candidates: the cone reference follows')
ok('name each line: lifting bridles, cyan line' in c, 'candidates: the retire row takes the new form')
ok('- **v17 (2026-10-15):** the lifting-bridles rename re-keys the lift-chain rows.' in c, 'candidates: the v17 delta head reads')
hits = [m.start() for m in old_pat.finditer(c)]
ok(len(hits) == 1, 'candidates: the old form reads once (the ban quote)')
ln = c.splitlines()[c[:hits[0]].count('\n')]
ok('bridles (cyan lines)' in ln, 'candidates: the one old form is the ban quote')
ok('"bridles (cyan lines)"' in c, 'candidates: the ban quote holds')
ok(c.count('lifting') - cb.count('lifting') == 8, 'candidates: eight lifting inserts, net')
ok(c.endswith('- **v17 (2026-10-15):** the lifting-bridles rename re-keys the lift-chain rows.\n'
             '  The term row, the chain list and the cyan-line guard take the founder form.\n'
             '  The lift-bearing row follows at the cone reference.\n'
             '  The rename lands with the lifting-bridles relabel.\n'
             '  No other change.\n'), 'candidates: the v17 delta closes the file')

# --- notes ---
ok('Lift bearing, then three lifting bridles (one per TRPT line) to the R6 vertices.' in n, 'notes: the floor list takes the new form')
ok('load-bearing: lifting bridle = bearing to rotor;' in n, 'notes: the distinction takes the new form')
hits = [m.start() for m in old_pat.finditer(n)]
ok(len(hits) == 1, 'notes: the old form reads once (the deferred style line)')
ln = n.splitlines()[n[:hits[0]].count('\n')]
ok('bridles (gold, as the dashboard)' in ln, 'notes: the deferred line is the style class, enumerated')
n13 = n.splitlines()[12]
n30 = n.splitlines()[29]
ok('then three lifting bridles (one per TRPT line)' in n13, 'notes: line 13 reads the new form')
ok('lifting bridle = bearing to rotor' in n30, 'notes: line 30 reads the new form')

# --- stale-phrases ---
ok('Replacement: lifting bridles and the cyan line are different lines: lifting bridles = lift bearing to main-rotor vertices (n_lines lines); cyan line = sky hook to lift bearing (1 line). See docs/agents/physics-topology.md §2' in s, 'stale-phrases: the replacement takes the new form')
ok('Note (2026-10-15): the lift-chain member reads "lifting bridles" (Rod, 2026-10-15).' in s, 'stale-phrases: the dated note reads')
ok('~4.66 m 3D lifting bridle' in s, 'stale-phrases: the bearing_offset replacement follows')
hits = [m.start() for m in old_pat.finditer(s)]
ok(len(hits) == 1, 'stale-phrases: the old form reads once (the heading)')
ln = s.splitlines()[s[:hits[0]].count('\n')]
ok(ln == '## bridles (cyan lines)', 'stale-phrases: the one old form is the heading')

# --- probes ---
pg = (ROOT / 'scratch/sw_br_probe_gold.log').read_text()
pb = (ROOT / 'scratch/sw_br_probe_bare.log').read_text()
ok('doc flags 3, skill hits 0' in pg, 'probe: gold bridles reads 3 doc flags, 0 skill hits')
ok('doc flags 20, skill hits 4' in pb, 'probe: bare bridles reads 20 doc flags, 4 skill hits')

# --- md5s ---
md5 = lambda p: hashlib.md5(pathlib.Path(p).read_bytes()).hexdigest()
ok(md5(C) == '7d54d76f5fb28267a48ce6e6d148d8dc', 'candidates: md5 reads the folded value')
ok(md5(N) == '9e005efb7f3f2723770929bad70cf8b1', 'notes: md5 reads the folded value')
ok(md5(S) == 'ff97856278ab8a8ebabe6b6c256b59e6', 'stale-phrases: md5 reads the folded value')

print(f'-- {checks} checks, {fails} fail')
sys.exit(1 if fails else 0)
