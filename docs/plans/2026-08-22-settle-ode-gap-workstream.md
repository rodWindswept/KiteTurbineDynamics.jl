# Proposal — settle-vs-ODE equilibrium gap: Cp/TSR mismatch in `settle_to_operational_state` (2026-08-22)

**Status:** PROPOSAL for the parallel workstream (2026-08-21 open task, Option 2).
Honest-window campaign (Option 1) proceeds on the current settle; this workstream
investigates and fixes the shared init so every FUTURE campaign starts closer to
the ODE's true equilibrium.

## The observed gap

The settle parks the machine at an idealized ω where its simplified balance
holds; the ODE then relaxes toward a LOWER ω. On the Daisy-anchored 5 kW seed
the settle lands 10–60% too fast (2026-08-13; re-observed 2026-08-21):

| quantity | settle | ODE window end | gap |
|---|---|---|---|
| ω_gnd (k=5.39) | 11.5 rad/s (λ 4.8) | ~10.1 rad/s @ 20 s, decaying | ~12% and still falling |
| sustained P | — | k·ω³ = 3.15 kW at true equilibrium | the 20 s window read 5.97 kW |

The 2026-08-13 drag experiment measured rope/bearing losses ≈ 26 W — negligible.
So the settle model's aero power at its chosen ω EXCEEDS what the ODE actually
realises: a Cp / area / elevation-factor mismatch, not a loss problem.

## The settle model (src/initialization.jl:819-865)

```
P_aero(ω) = 0.5·ρ·v_mag³ · π(r_out²−r_in²) · cp_at_tsr(λ) · cos(β)^2.65      λ = ω·r_out/v_mag
P_gen(ω)  = k·ω³
first ω (scanning down from the cp peak) where P_aero > P_gen  →  ω_eq
```

Candidates for the mismatch (to be measured, not assumed):

1. **Cp reference**: settle uses `cp_at_tsr(λ)` with λ on `r_out`. The ODE aero
   (ring_forces.jl) may use a different radius convention (BEM r_rotor vs r_out)
   or an induction/α model (expansion rotors) that the settle does not include.
2. **Wind magnitude**: settle uses `v_mag = norm(wind at hub)`; the ODE uses the
   power-law `wf` per node with z clipped at 1 m — near-ground rings see lower
   wind, and the ODE integrates aero over the full machine, not just the hub.
3. **Elevation factor**: `cos(β)^2.65` (thrust) vs the ODE's per-ring projections
   (`cos²`/`cos³` in ring_forces, elevation vs yaw decomposition). Possible
   double-counting or mismatch of the projection.
4. **Expansion rotors**: settle uses a simplified per-rotor `cp_at_tsr(λ_er)·cosd(bank)`
   without the α/induction model the ODE applies.

## Investigation (diag, no physics change)

1. Trace the ODE on the corrected 18.8 m machine (k=5.39, new mass law) for 60 s:
   record ω_gnd(t), P_gen(t), and the ODE-realised aero power per rotor vs the
   settle model's P_aero(ω) at the same ω.
2. Compute the settle's P_aero(ω_eq) and the ODE's P_aero at ω_eq from the trace.
   The ratio identifies the mismatch magnitude per candidate (vary one at a time).
3. Output: `scripts/diag_settle_gap.jl` → CSV + a short report.

## Fix shape (if confirmed)

Bring the settle's aero model in line with the ODE (same Cp reference radius,
same wind treatment, same elevation projection, same expansion-rotor model) —
a physics change to SHARED init, so: proposal → acceptance tests (RED:
settle ω_eq within X% of the ODE 60 s equilibrium for the seed at 3 k values)
→ implement → GREEN → DECISIONS entry. Bit-identical guard: the healthy
k=5.39 case must not regress (mirrors A3 of the settle-scan fix).

## Scope guard

- Does NOT block the honest-window campaign (Option 1). The honest window
  makes the evaluator measure the TRUE equilibrium regardless of where the
  settle starts; the settle fix only makes campaigns FASTER (less relax time
  wasted) and the settle state more representative.
- Acceptance suite re-baseline already pending (DECISIONS [2026-08-20/21]);
  a settle change adds re-baseline items — noted for the plan.
