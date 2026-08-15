# v13 18.0 m campaign — re-gate verdict (2026-08-15)

**Winner:** `scripts/results/v13_5kw_len18.0/island_1_best.csv`
**Gate:** `scripts/regate_winner_v13.jl` on the corrected model (A2, per-rotor
Betz, C1, rope break SK99, twist, tip-speed, clearance).

| Check | Result |
|---|---|
| P_gen final (ground ring) | **7.678 kW** |
| ω_gnd / ω_hub | 15.81 / 15.83 (coherent chain) |
| Twist crossing | none (max ratio 0.17) |
| Line break | none |
| Tip-speed sanity | ok |
| Clearance | 5.97 m |
| Genome | r_hub=0.702, n_lines=12, rings=5, n_active=1 |

**VERDICT: PASS ✓** — the first campaign winner of the cycle that transmits
sustained power at the ground ring while surviving every structural check.
57% above the seed (4.89 kW) at this length. The DE again touched the r_hub
floor (0.70), but the floor is now a physical fence and the design inside it
is sound. n_active=1 is noted — legitimate here (real transmission, coherent
chain), but watch whether single-rotor topologies dominate the 21.2/25 m runs.
