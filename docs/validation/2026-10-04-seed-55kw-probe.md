# 5.5 kW seed probe — the winner is dead on this tree. The seed is reachable at +24% scale

**From:** @hermes (desktop) · **Date:** 2026-10-04 · **Tree:** `f225e95` (`bank-derate-cos2p65`)

The requirement from Rod (2026-10-04): the seed of the next campaign should ideally measure ≥ 5.5 kW. The DE then has something to optimise.

## What the probe measured

Probe: `scratch/hermes_probe_seed_55.jl`. It runs 4 cases with the campaign regime verbatim. Settings: cold start, k = 2.24, relax 10 + window 40 s, tail5, mass-aware const-tension lift, FoS floor 2.5.
**The probe rejected all four cases.** This includes the control (the recorded bank-derate winner, island 3, fitness 21.698).

Diagnostics: `scratch/hermes_probe_seed_55_diag.jl`, `scratch/hermes_probe_seed_55_diag2.jl`. Logs: `.julia_depot/logs/hermes_probe_seed_55{,_diag,_diag2}.log`.

## The mechanism (measured, not inferred)

1. **The D1 landing killed the 50 m decoder anchor** (`6f4cdbe`). The old decoder sized rotors through `wind_speed_at_ring` (h_ref = 50 m, alpha = 0.14 — the 2.05× defect). It priced ring wind at ≈ 8.7 m/s instead of the honest ≈ 11 m/s. So the rotors came out oversized.

2. Under the corrected decode the winner genome builds a smaller machine. Rotor radius 4.4994 m, blade-hub 3.5498 m, bank 10.74°, n_ring = 10. Wind-normal swept area `A_zy` = **20.415 m²** (swept annulus 24.013 m², bank-projected 23.573 m², × cos 30° elevation).

3. The ODE window runs cleanly — 73/73 finite samples. But the machine only ramps to **P ≈ 3.78 kW** (first P 3.716, last 3.784). The record at campaign time (era `ee6c64f`) was 5.11 kW. Part of that 5.11 kW was the oversized machine of the decoder defect.

4. The **P_available floor gate rejects it** before the fitness seam (`objective_evaluator.jl:1080`). It computes `Betz_cp_kW = p.cp · ½ρ A_zy v³` = 0.16 × 16.64 kW = **2.66 kW < 4.0 kW** (0.8 × p_floor 5.0). The gate prices the rotor at the Daisy system Cp (0.16). The machine operates at ≈ 0.23.

5. All four probe candidates reject the same way. Blade 0.76 / 0.72 do not change area. Radii × 1.04 → A_zy 22.1 m² → Betz_cp 2.88 < 4.0.

## What a ≥ 5.5 kW seed needs (on the current instrument)

Measured on the scaled candidates (`scratch/hermes_probe_seed_55b.jl`, `.julia_depot/logs/hermes_probe_seed_55b.log`, `..._diag2x.log`):

| case | built rotor | A_zy | measured P | P_available gate |
|---|---|---|---|---|
| winner (control) | r 4.4994 / hub 3.5498 | 20.42 m² | 3.78 kW | 2.66 < 4.0 REJECT |
| radii × 1.24 | r 5.4197 / hub 4.4701 | 25.09 m² | 4.03 kW | 3.27 < 4.0 REJECT |

Two findings:

1. **The radii genes propagate** into the built rotor. The radius grew × 1.20. But **the BEM sizing fixes the blade span** (span stayed 0.9496 m: span = 0.75·r_rotor·λ). So area grows only × ~1.2 with radii, not × 1.54.

2. **The span lever is blade_scale (λ).** area ∝ r_ring·span, span ∝ λ.

Gate floor: `A_zy ≥ 4.0 / (0.16 · ½ρ · v³) = 30.67 m²`. Measured Cp ≈ 0.20 at this scale ⇒ ≥ 5.5 kW needs `A_zy ≈ 34 m²`. Current candidates under test: radii × 1.24 with blade 1.00 / 0.95. The other case is radii × 1.35 with blade 0.88.

## Caveats — re-measure before any launch

1. The two pending rulings (Cp convention, feasibility-floor shape) can move the evaluator. A seed is valid only under the physics era of its measurement.

2. §6 items 1–2 (Betz reconciliation, acceptance winner repoints) stay RED. The seed rides on the same corrected-decode instrument.

3. The seed sits outside the OLD campaign bounds (r_hub hi 4.32 m). The new campaign must re-centre `tight_bounds` on the new seed. This is the normal procedure.

4. The probe has not measured twist and realisability at the larger scale.

STE pass 2026-10-06: no numbers or findings changed.
