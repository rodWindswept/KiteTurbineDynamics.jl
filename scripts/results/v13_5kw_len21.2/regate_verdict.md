# v13 21.2 m campaign — re-gate verdict (2026-08-15)

**Winner:** `scripts/results/v13_5kw_len21.2/island_1_best.csv`
**Gate:** `scripts/regate_winner_v13.jl` on the corrected model (A2, per-rotor
Betz, C1, rope break SK99, twist, tip-speed, clearance).

| Check | Result |
|---|---|
| P_gen final (ground ring) | **8.243 kW** |
| ω_gnd / ω_hub | 16.18 / 16.18 (bit-identical — full chain coherence) |
| Twist crossing | none (max ratio 0.25) |
| Line break | none |
| Tip-speed sanity | ok |
| Clearance | 7.70 m |
| Genome | r_hub=0.705, n_lines=14, rings=7, n_active=1 |

**VERDICT: PASS ✓** — second consecutive honest winner. 8.24 kW sustained at
the ground ring, 85% above the seed (4.45 kW) at this length. The chain is
fully coherent (ω identical end-to-end). n_active=1 again — single-rotor
dominance at 5 kW is now a two-campaign pattern; await the 25 m result.
