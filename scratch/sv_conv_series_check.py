#!/usr/bin/env python3
"""sv_conv_series_check.py — science-validator recompute of the convergence series.

Independent recompute of scratch/av_conv_series.csv from the campaign telemetry,
plus the parity set (finals, ok counts, sha256s, NR-036 milestones, stock-probe
agreement). Rule (strip extract, 2026-10-09): best-so-far at generation G = least
recorded fitness among ok rows with gen <= G; ties -> earliest (gen, idx); no
interpolation, no reconstruction.
"""
import hashlib

BASE = 'scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2'
fails = []

def check(cond, msg):
    print(('PASS' if cond else 'FAIL'), msg)
    if not cond:
        fails.append(msg)

# ── av series ────────────────────────────────────────────────────────────────
av = {}
with open('scratch/av_conv_series.csv') as f:
    for line in f:
        if line.startswith('#') or not line.strip():
            continue
        p = line.strip().split(',')
        if p[0] == 'island':
            continue
        av[(int(p[0]), int(p[1]))] = (p[2], int(p[3]), int(p[4]))
check(len(av) == 93, f'av series rows read 93 (read {len(av)})')

expected_sha = {
    1: '6f359c33f174d5dc98b1252e29fdba6eac8dbae15dd71d46ef8bbed6acc9bd2f',
    2: '54172ce5a64b22903a2428f870b499f13da53c6b065600d8a01edfd882b29827',
    3: '34d40e8ea960a1e04c83df58df9e24047cfcf7eb3deff3278807f1147b8d60b0',
}

series = {}
for island in (1, 2, 3):
    path = f'{BASE}/island_{island}/telemetry.csv'
    rows = []
    with open(path) as f:
        for line in f:
            if line.startswith('#'):
                continue
            p = line.strip().split(',')
            if p[0] == 'island':
                continue
            rows.append((int(p[1]), int(p[2]), p[3], p[4]))  # gen, idx, fitness(str), status
    sha = hashlib.sha256(open(path, 'rb').read()).hexdigest()
    check(sha == expected_sha[island], f'island {island} telemetry sha256 matches the header ({sha[:12]}...)')
    n_ok = sum(1 for r in rows if r[3] == 'ok')
    print(f'     island {island}: rows {len(rows)}, ok {n_ok}')
    series[island] = (rows, n_ok)

check(series[1][1] + series[2][1] + series[3][1] == 508, 'ok counts sum to 508 (NR-002)')

# ── recompute the series ─────────────────────────────────────────────────────
mismatch = 0
for island in (1, 2, 3):
    rows, _ = series[island]
    for G in range(31):
        cands = [r for r in rows if r[3] == 'ok' and r[0] <= G]
        best = min(cands, key=lambda r: (float(r[2]), r[0], r[1]))
        bfit, bgen, bidx = best[2], best[0], best[1]
        a = av[(island, G)]
        if a != (bfit, bgen, bidx):
            mismatch += 1
            print(f'     MISMATCH island {island} gen {G}: av {a} vs recomputed {(bfit, bgen, bidx)}')
check(mismatch == 0, f'all 93 recomputed rows equal the av series (mismatches {mismatch})')

# ── finals and milestones ────────────────────────────────────────────────────
finals = {i: av[(i, 30)][0] for i in (1, 2, 3)}
print('     finals:', finals)
check(finals[1] == '30.578', 'island 1 final reads 30.578 (NR-003 form)')
check(finals[2] == '30.637', 'island 2 final reads 30.637 (NR-004 form)')
check(av[(3, 26)][0] == '27.364' and av[(3, 30)][0] == '27.364', 'island 3 reads 27.364 from gen 26 (NR-005 form)')

milestones = [0, 6, 10, 18, 22, 25, 26]
expected_m = ['36.109', '32.293', '31.661', '30.929', '29.854', '28.315', '27.364']
got = [av[(3, g)][0] for g in milestones]
check(got == expected_m, f'island 3 milestones reproduce NR-036 7 of 7 ({got})')

for i, want in ((1, '36.109'), (2, '36.109'), (3, '36.109')):
    check(av[(i, 0)][0] == want, f'island {i} starts at the common seed 36.109 (NR-006 form)')

pct1 = (30.578 / 27.364 - 1) * 100
pct2 = (30.637 / 27.364 - 1) * 100
print(f'     island 1 final is +{pct1:.2f} per cent vs island 3; island 2 +{pct2:.2f} per cent')
check(f'{pct1:.1f}' == '11.7' and f'{pct2:.1f}' == '12.0', 'the finals read +11.7 and +12.0 per cent (Harris line)')

# ── stock-probe agreement ────────────────────────────────────────────────────
log = open('scratch/av_rb_stock_probe.log').read()
check('30.578' in log and '30.637' in log, 'the stock-probe log carries the same 30.578 and 30.637 values')

print()
print('SV_CONV_SERIES_CHECK', 'PASS' if not fails else f'FAIL ({len(fails)})')
