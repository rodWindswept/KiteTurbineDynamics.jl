#!/usr/bin/env python3
"""av_fdecode_stats.py — fleet statistics over the 508-row f decode
(scratch/av_fdecode_508.csv, produced by scratch/av_fdecode_probe.jl).

Prints the distributions RF-19 quotes and the winner row, plus the
per-n_lines census for the receipt.
"""
import csv
from collections import Counter, defaultdict

rows = []
with open('scratch/av_fdecode_508.csv') as fh:
    for r in csv.DictReader(fh):
        rows.append({k: (float(v) if k not in
                         ('island', 'gen', 'idx', 'status', 'n_lines',
                          'rotor_count') else
                         (int(v) if k in ('n_lines', 'rotor_count') else v))
                     for k, v in r.items()})

print(f"rows {len(rows)}")
nsel = sorted(set(r['n_lines'] for r in rows))
print("n_lines census:", dict(Counter(r['n_lines'] for r in rows)))
print("rotor_count census:", dict(Counter(r['rotor_count'] for r in rows)))

def q(vals, qs=(0.0, 0.25, 0.5, 0.75, 1.0)):
    s = sorted(vals)
    return [s[min(len(s) - 1, int(qq * (len(s) - 1)))] for qq in qs]

print()
print("f(k=2.24, frozen 3mm, two-bridle) across 508:")
print("  min/p25/p50/p75/max:", [f"{v:.4f}" for v in q([r['f_k224'] for r in rows])])
print("f(k*=8.9, frozen):", [f"{v:.4f}" for v in q([r['f_kstar_lo'] for r in rows])])
print("f(k*=8.4, frozen):", [f"{v:.4f}" for v in q([r['f_kstar_hi'] for r in rows])])
print("f(k*=8.9, sized lo):", [f"{v:.4f}" for v in q([r['f_sized_lo'] for r in rows])])
print("f(k*=8.4, sized hi):", [f"{v:.4f}" for v in q([r['f_sized_hi'] for r in rows])])
print("f_full(k=2.24):", [f"{v:.4f}" for v in q([r['f_full_k224'] for r in rows])])

w = [r for r in rows if abs(r['fitness'] - 27.364) < 1e-6][0]
print()
print("winner row (island", w['island'], "gen", w['gen'], "idx", w['idx'], "):")
print(f"  n_lines {w['n_lines']}  r_hub {w['r_hub']:.4f}  bank {w['bank']:.4f}  "
      f"blade_scale {w['blade_scale']:.4f}  v_wind {w['v_wind']:.4f}  "
      f"r_rotor {w['r_rotor']:.4f}")
print(f"  span {w['span']:.4f}  r_in {w['r_in']:.4f}  r_out {w['r_out']:.4f}")
print(f"  f(k=2.24) {w['f_k224']:.4f}  f_full(k=2.24) {w['f_full_k224']:.4f}")
print(f"  f(k* frozen) {w['f_kstar_lo']:.4f}-{w['f_kstar_hi']:.4f}  "
      f"f(k* sized) {w['f_sized_lo']:.4f}-{w['f_sized_hi']:.4f}")

# RF-19 cross-checks: winner credible bound 0.104 (low) to 0.129 (high)
print()
print("RF-19 winner cross-checks:")
print(f"  two-bridle high f {w['f_k224']:.4f} vs RF-19 0.1289-0.1295 band")
print(f"  full-line f {w['f_full_k224']:.4f} vs RF-19 0.177")
print(f"  f(k*) credible 0.104 -> {0.104*2.24/8.9:.4f}-{0.104*2.24/8.4:.4f} "
      f"(RF-19 0.0263-0.0276)")

# per-n medians for the receipt table
print()
print("median f(k=2.24) per n_lines:")
by_n = defaultdict(list)
for r in rows:
    by_n[r['n_lines']].append(r['f_k224'])
for n in nsel:
    vals = sorted(by_n[n])
    print(f"  n={n}: n={len(vals):3d}  median {vals[len(vals)//2]:.4f}  "
          f"min {vals[0]:.4f}  max {vals[-1]:.4f}")
