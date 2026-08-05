# Handover — 2026-08-04 Session

## Summary

Part A blockers landed (commits `fb7bdc8`/`e796673`). Three test bugs found and fixed.
A 48-eval campaign ran (~3.5h) with a 1.3m autogyro lift device. Result: all designs
stalled. Power generation is the binding constraint, not structure. The best genome
(14-gon, r_hub=5.37m, P=8.6kW, FoS=0.707) produces numerical blowup when initialised
via `settle_to_operational_state` but records plausible numbers via the campaign's
`warmstart_with_k_bracket` path. Simulation result depends on initialisation method —
the ODE solver is pathologically sensitive for underpowered designs.

## Source changes (uncommitted)

| File | Change |
|------|--------|
| `test/test_objective_v11.jl:193,208` | `objective_v11` → `objective_v11_warmstart` (scalar vs tuple bug) |
| `src/objective_v11.jl:458` | `ρ_AIR` → `p.rho` (undefined in module scope) |
| `src/objective_v11.jl:509` | Added `drifted = drift > 0.20` (undefined variable) |
| `src/objective_v11.jl:262,536` | Added `lift_device` kwarg to `objective_v11_warmstart` and `warmstart_with_k_bracket` |
| `src/objective_v11.jl:400,557` | Forward `lift_device` to `run_canonical_sim!` |
| `scripts/run_feasibility_phase_a.jl` | Added `LIFT_DEVICE` (1.3m RotaryLifterParams, 1.6× margin), `lift_tension_N` CSV column, campaign config pop=8/gen=6/cap=48 |
| `scripts/interactive_dashboard.jl:252` | `expansion_blade_mass` → `KiteTurbineDynamics.expansion_blade_mass` |
| `src/visualization.jl:1061-1063` | Added all config names to Menu options (was only 3, crashed on V10 selections) |

## Campaign result (`feasibility_phase_a_v2.csv`)

- 42 rows, 48 evals, 5 generations, 3.5 hours
- **100% stalled** — zero designs reached P≥25kW AND FoS≥1.5
- 88% FoS ≥ 1.0 (structure adequate), 88% P ≈ 0 kW (power catastrophic)
- Best: P=8.6kW, FoS=0.707, n_lines=14, r_hub=5.37m, k_mppt=0.01
- DE converged on huge rotor + zero torque extraction as only viable strategy

## Critical finding: solver instability

The best genome produces **fundamentally different results** depending on initialisation:

| Method | hub_z | omega | P | FoS |
|--------|-------|-------|---|-----|
| `warmstart_with_k_bracket` (campaign) | ~15m | ~25 rad/s | 8.6 kW | 0.71 |
| `settle_to_operational_state` (trace) | NaN | 10^141 | 0.0 | Inf |

The `settle_to_operational_state` path (used by dashboard and trace script) leads to
immediate ODE blowup: NaN positions, runaway omega, zero structural loads.
The campaign path (static equilibrium → settle_to_equilibrium → kickstart → window)
produces plausible but unverified numbers.

**Interpretation:** the ODE solver is pathologically sensitive for designs near the
power/structural boundary. The campaign's `objective_v11_warmstart` may be producing
physically meaningful results OR it may be masking solver failure behind plausible
numbers. Without independent verification (e.g. comparing power/position traces from
both paths), we cannot trust either result.

## Lift device

- Campaign uses `RotaryLifterParams(r=1.3m, ω=33rad/s)` providing 629N vertical (1.6× margin)
- CoAx BEM model shows autogyro produces near-zero lift at low wind speeds — flagged as major concern
- Assumption: sufficient lift from some device (possibly not autogyro), to be published honestly
- `lift_tension_N` column in campaign CSV, currently ~638N per row (steady-state value)

## Test suite

- `test_objective_v11.jl` A2 and A1 tests: 1,859/1,859 green after fixes
- Fixes needed: `objective_v11`→`objective_v11_warmstart`, `ρ_AIR`→`p.rho`, `drifted` computed

## Dashboard bugs (pre-existing)

1. **Menu widget**: `visualization.jl:1061` only listed 3 config names; any V10/V9/V6 selection crashed — **FIXED**
2. **equilibrium solver**: `settle_to_operational_state` hangs for designs that can't reach rated power (150k steps × 1e-5 dt = slow, not hung)
3. **expansion_blade_mass**: unqualified call in `build_from_campaign_v10` — **FIXED**

## To do

1. **Solver stability** — compare `warmstart_with_k_bracket` path against `settle_to_operational_state` for the best genome. Verify which (if either) is physically correct. The campaign data may be garbage masked by a forgiving initialisation.
2. **B1 dt refinement** — run 3 blowup genomes at dt, dt/4, dt/10 (handover spec). The preliminary CSVs suggest genuine structural failure for k=60 genome.
3. **Lift device model** — resolve PCA-2 vs BEM discrepancy. KTD's `lift_kite.jl` PCA-2 model overestimates autogyro lift by orders of magnitude vs CoAx BEM.
4. **Dashboard** — add `--genome-csv` support properly (ArgParse registration needed). Make equilibrium solver handle underpowered designs gracefully.
5. **Campaign re-run** — increase eval budget, investigate why power generation fails across the entire population.

## Restart commands

```bash
cd ~/Documents/GitHub/KiteTurbineDynamics.jl
git status  # check uncommitted changes
rm -f ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji  # clear cache
julia --project=. test/runtests.jl  # verify 1859/1859 green
```

## Key files

- `scripts/results/recampaign/feasibility_phase_a_v2.csv` — campaign output (42 rows)
- `scripts/results/recampaign/best_genome_trace.csv` — 60s trace (all NaN/Inf)
- `scripts/run_feasibility_phase_a.jl` — campaign launcher (pop=8, gen=6, cap=48)
- `scripts/trace_best_genome.jl` — trace script (needs Statistics import fix)
- `scripts/view_genome.jl` — geometry printer
