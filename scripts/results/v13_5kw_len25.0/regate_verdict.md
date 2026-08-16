# v13 25.0 m campaign — re-gate verdict (2026-08-15)

**Winner:** `scripts/results/v13_5kw_len25.0/island_1_best.csv`
**Gate:** `scripts/regate_winner_v13.jl` on the corrected model (A2, per-rotor
Betz, C1, rope break SK99, twist, tip-speed, clearance).

| Check | Result |
|---|---|
| P_gen final (ground ring) | **8.322 kW** |
| ω_gnd / ω_hub | 16.24 / 16.22 (coherent chain) |
| Twist crossing | none (max ratio 0.24) |
| Line break | none |
| Tip-speed sanity | ok |
| Clearance | 9.20 m |
| Genome | r_hub=0.700, n_lines=16, rings=8, n_active=1 |

**VERDICT: PASS ✓** — third consecutive honest winner. 8.32 kW sustained at
the ground ring = 3.7× the seed at this length (the ladder found the seed
marginal at 25 m: 2.25 kW). The DE overturned seed marginality.

## Campaign family (all three lengths, corrected model)

| Length | P_gen | vs seed | n_lines | rings |
|---|---|---|---|---|
| 18.0 | 7.68 kW | +57% | 12 | 5 |
| 21.2 | 8.24 kW | +85% | 14 | 7 |
| 25.0 | 8.32 kW | +270% | 16 | 8 |

Shared family traits: n_active=1 (single rotor), r_hub at the 0.70 floor,
n_lines grows with length, coherent chains, all structural checks green.
The 5 kW rung is solved across 18–25 m on the corrected model.
