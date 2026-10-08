# Numbers Register — the single source of truth between the simulation and the audience

**Status:** TEMPLATE + v1 PROPOSED ROWS (2026-10-08). A row becomes usable
for reporting only when a validator signs it. Unsigned rows do not exist
for reporting purposes. Writers and figure bots cite ONLY signed rows, by
row ID, in every public post and in every figure spec.

**Row format:** `ID · claim · value · units · source (commit + file +
row-range or script) · derivation recipe (if derived) · validator signature
· date signed`. A number that changes is superseded by a dated new row —
never edited.

**Sources for v1:** bankderate2 dataset (`scripts/results/
v13_5kw_masslift_len18.8_rotorcount_bankderate2/`, era
`post-95c385d_wind-authority`, data git `a76c5e9`), the Phase 0 signed audit
(master `31ca00d`), and the 2026-10-08 probes
(`scripts/probe_rapid_vs_ode_winners.jl`,
`scripts/probe_warm_reject_cause.jl`, repo `338e74c`-era branch).

## v1 proposed rows (awaiting validator signatures)

| ID | Claim | Value | Units | Source | Status |
|---|---|---|---|---|---|
| NR-001 | Campaign size | 930 (3 islands × 310) | evals | island_*/telemetry.csv | proposed |
| NR-002 | Status mix | 508 ok / 301 reject / 110 clearance_reject / 11 reject_twist | designs | telemetry `status` column | proposed |
| NR-003 | Island 1 best fitness | 30.578 (found gen 30) | kg | island_1/convergence.csv | proposed |
| NR-004 | Island 2 best fitness | 30.637 (found gen 30) | kg | island_2/convergence.csv | proposed |
| NR-005 | Island 3 best fitness | 27.364 (found gen 26) | kg | island_3/convergence.csv | proposed |
| NR-006 | All-island start point | 36.109 (gen 1, common seed) | kg | convergence.csv | proposed |
| NR-007 | P_mean range, ok rows | 5.02–6.32 | kW | telemetry, ok only | proposed |
| NR-008 | Winner P_mean (island 3) | 5.309 / P_end 5.314 | kW | island_3 telemetry | proposed |
| NR-009 | Winner FoS (island 3) | 14.972 | — | island_3 telemetry | proposed |
| NR-010 | Winner T_lift (island 3) | 324.1 | N | island_3 telemetry | proposed |
| NR-011 | Winner geometry (island 3) | n_lines 3, rings 6, n_active 1, r_hub 4.580 m, r_bot 0.804 m, bank_bot 22°, blade scales 0.82/0.20 | — | decode of best_vector.csv | proposed |
| NR-012 | Cold-path reproduction | :cold re-eval matches recorded P_mean, P_end, FoS, fitness, T_lift to 3 dp on all three winners | — | probe_rapid_vs_ode_winners.jl | proposed |
| NR-013 | Rapid-path result on winners | :warm rejects all three winners — rope-break gate (broken=true), transient line over-strain during relax | — | probe_rapid_vs_ode_winners.jl + probe_warm_reject_cause.jl | proposed |
| NR-014 | Winner window swing | P_range 0.029 on 5.309 kW (0.5%) | kW / % | island_3 telemetry | proposed |
| NR-015 | Operating point | k 2.24, relax 10 s + window 40 s, FoS gate 2.5/2.5, length 18.8 m | — | runner provenance | proposed |
| NR-016 | Winner ω (ODE) | 10.170 | rad/s | island_3 telemetry / re-eval | proposed |

## Known boundaries (must accompany any use — Track E)

- Blade integrity is not checked: `min_fos_blade_root` hard `Inf`, full
  beam-on-supports blade model deferred (PRD 0006:147).
- Flown blades carry tether-to-blade bridling that resists thrust/expansion
  more capably than the unbridled-blade model assumes; that bridling adds
  drag not included in the model.
- `start_mode=:warm` is the evaluator default; any consumer that does not
  pass `:cold` measures the instrument, not the machine.
