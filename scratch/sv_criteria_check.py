#!/usr/bin/env python3
"""sv_criteria_check.py — science-validator check for the torsion criteria rows.

Reads the code constants at the tree tip, recomputes the criterion arithmetic,
and re-reads the winner's telemetry cells behind the quotes.
"""
import math

fails = []

def check(cond, msg):
    print(('PASS' if cond else 'FAIL'), msg)
    if not cond:
        fails.append(msg)

# ── code constants ───────────────────────────────────────────────────────────
src1 = open('src/trpt_optimization.jl').read().splitlines()
src2 = open('src/initialization.jl').read().splitlines()

l39 = src1[38]
check('OPT_TORSION_FOS_REQUIRED = 1.5' in l39, f'trpt_optimization.jl:39 reads the 1.5 constant ({l39.strip()})')

idx1691 = src2[1690]
check('TRPT_REALISABILITY_TENSION_MARGIN = 1.05' in idx1691,
      f'initialization.jl:1691 reads the 1.05 constant ({idx1691.strip()})')

# ── arithmetic ───────────────────────────────────────────────────────────────
t = 1 / 1.05
floor = math.degrees(math.asin(t))
print(f'     1/1.05 = {t!r}')
print(f'     floor angle = {floor!r} deg (quote 72.25 / 72.247)')
check(abs(t - 0.9523809523809523) < 1e-16, '1/1.05 reads 0.9523809523809523')
check(abs(floor - 72.24720983805331) < 1e-12, 'the continuum floor reads 72.24720983805331 deg')

r_fos = 2.0287970973051634 / 1.5
print(f'     2.0287970973051634 / 1.5 = {r_fos!r} (quote 1.35)')
check(f'{r_fos:.2f}' == '1.35', 'the least capacity ratio reads 1.35 times the 1.5 floor')

m_floor = floor / 33.94561934829036
m_cross = 1 / 0.4393474253185575
m_dcrit = 98.85908296054023 / 33.94561934829036
print(f'     twist / floor = {m_floor!r} (quote 2.13)')
print(f'     1 / crossing ratio = {m_cross!r} (quote 2.28)')
print(f'     twist / dcrit = {m_dcrit!r} (quote 2.91)')
check(f'{m_floor:.2f}' == '2.13', 'the S1 twist reads 2.13 times margin to the floor')
check(f'{m_cross:.2f}' == '2.28', 'the worst crossing ratio reads 2.28 times margin to the crossing gate')
check(f'{m_dcrit:.2f}' == '2.91', 'the S1 twist reads 2.91 times margin to dcrit')

# ── telemetry cells ──────────────────────────────────────────────────────────
BASE = 'scripts/results/v13_5kw_masslift_len18.8_rotorcount_bankderate2'
hits = []
winner = None
for island in (1, 2, 3):
    with open(f'{BASE}/island_{island}/telemetry.csv') as f:
        for line in f:
            if line.startswith('#'):
                continue
            p = line.strip().split(',')
            if p[0] == 'island':
                continue
            if p[10] == '0.4393474253185575':
                hits.append((island, p[1], p[2], p[4], p[10]))
            if island == 3 and p[3] == '27.364':
                winner = (island, p[1], p[2], p[3], p[10], p[9])
print('     crossing-ratio hits:', hits)
print('     island 3 winner row:', winner)
check(len(hits) >= 1, 'the worst crossing ratio 0.4393474253185575 reads in the telemetry cells')
check(winner is not None and winner[4] == '0.4393474253185575' and winner[5] == 'false',
      'the winning row carries the worst crossing ratio and twist_crossed false')

print()
print('SV_CRITERIA_CHECK', 'PASS' if not fails else f'FAIL ({len(fails)})')
