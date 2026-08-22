# Plan — staged model-comparison DE campaigns on the validated 5 kW base (2026-08-22)

**Status:** PLAN (Rod approved "both, staged": mass/evaluator variants first,
then geometry families).  Executes AFTER the base campaign
(`v13_5kw_masslift_len18.8`, running) wins, is re-gated, and the acceptance
suite is re-baselined on it.

**Goal:** turn "which model do we believe?" into measured DE outcomes on ONE
protocol, so every winner is comparable.  Each comparison keeps the SAME
evaluator protocol (mass_min_fitness, FoS floor 2.5, P floor 5 kW, L=18.8 m,
k=2.24, honest window relax 10 + window 40, cold start, mass-aware
const-tension lift) and varies exactly ONE model axis.

## Common protocol (all campaigns)

| Item | Value |
|---|---|
| Runner | `scripts/run_v13_5kw_masslift.jl` (length 18.8, cfg as committed) |
| Objective | `mass_min_fitness` — score = TRUE physics mass; Inf below FoS/P floors |
| Base | `params_at_length(18.8)` = Daisy 1.5 kW mass_scale'd up (measured anchor) |
| k_mppt | 2.24 (honest 6-blade anchor; sweep `scripts/results/k_sweep_daisy_5kw.csv`) |
| Window | relax 10 + window 40 s, power_stat :tail5 (honest running power) |
| DE | 10 pop × 3 islands × 30 gen, seeded population, eval cache |
| Metric set | winner mass, φ kg/kW, sustained P, FoS_min (must be finite — see guard), tip speed, twist margin, ok rate, wall time |

## Stage A — mass & evaluator model variants (trust first)

| Run | Axis | What it answers |
|---|---|---|
| A0 (DONE) | baseline | the lightest honest 5 kW machine under the validated model |
| A1 | mass law: λ² (area) instead of λ³ | sensitivity of the winner to the mass exponent — how much does the λ³ decision matter? |
| A2 | knuckle floor off | how much of the winner mass is knuckles (0.050 kg/blade)? |
| A3 | window: 20 s (old) vs 40 s (honest) | quantify the flattery effect on the winner (expect heavier/more-rotored winners under the honest window) |
| A4 | k: fixed 2.24 vs k-bracket vs ramp controller | does the generator-gain discovery method change the winner? (evaluate_ramp now builds the right machine) |
| A5 | generator cap: quadratic `tau_max_safe` (current) vs margin-based cap | **MEASURED BINDING (2026-08-22):** the 625 N·m quadratic clamp is the active constraint at 5 kW (seed P_gen = 625·ω once ω > 10.8). Does a physics-based cap (τ_rated with ≥50% margin, convention-fixes item 1) change the winner family? |

Implementation notes: A1/A2 are one-line law toggles behind a config kwarg
(after the mass-law proposal lands, keep the law functions parameterised);
A3/A4 are runner-cfg variants.  Each run reuses the runner with a results
subdir per variant.

## Stage B — geometry families (on the winning evaluator)

| Run | Axis | What it answers |
|---|---|---|
| B1 | rotor masks: hub-only vs hub+1 vs hub+2/3 expansion | is a pure single rotor the lightest 5 kW machine, or do co-equal expansion rotors win? (the user's "different models" — the network-rotor question) |
| B2 | n_lines families {6, 8, 12} (bounds per family) | solidity/line-count tradeoff at 5 kW |
| B3 | search-space: drop dead x3 (aspect_ratio, fixed 1.0) and cap x8 at 12 (decoder clamp) | DE efficiency — dead dimensions waste ~7% of mutations (genome-glossary) |
| B4 | blade_scale bounds {[0.2,1.0] tight} vs {[0.1,2.0] wide} | does the reference-scale bound shape the winner? |

## Before Stage A/B can start

1. Base campaign finishes; winners picked (min mass, status ok, FoS finite)
   and re-gated with `scripts/ode_gate_v13.jl` (aligned machine + honest
   window).
2. **Land the non-finite-FoS guard** (convention-fixes proposal §Sequencing
   item 0) — every campaign after it is protected from the FoS=Inf exploit.
3. Re-baseline the acceptance suite once on the winners (amortises the ODE
   test cost across all variants).
4. Land the brake-torque cap fix (proposal §1) and re-sweep k once to
   confirm the operating map is unchanged at 5 kW.

## Success criteria

- Every winner's telemetry row has finite FoS, ok status, P_end ≥ 5 kW
  sustained, tip speed < 100 m/s, twist not crossed, T_lift = 1.5·m·g/sin70°
  (0.00% rel) — the same integrity checklist the base campaign must pass.
- Each comparison reports the winner metric table + a one-line verdict
  (e.g. "λ² vs λ³ changes winner mass by X%").
- Findings recorded in DECISIONS; winners archived with full provenance
  (git hash + physics era + geometry fingerprint) per the runner.
