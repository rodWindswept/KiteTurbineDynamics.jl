# Lift-Tension vs Torsional FoS Test — 2026-08-13

Provenance note for the lift-tension contribution test. Results recorded
here so the campaign folder carries its own analysis record.

## Provenance

- **Script:** `scripts/diag_lift_tension_torsional.jl`
- **Date:** 2026-08-13
- **Design:** island-1 winner from this campaign (`island_1_best.csv`) —
  n_lines=16, rings=9, n_active=3, r_hub=0.65m, V12 fitness -3.58,
  ODE-gate verified 6.34 kW at 20s
- **Parameters:** mass_scale(params_10kw(), 10.0, 5.0), ζ=0.05 (SystemParams.zeta),
  tether_diameter from cfg, lift device = rotary_lifter_default(),
  settle ceiling 60 rad/s, 20s MPPT window, dt=4e-5
- **Git era:** post-ζ-fix (DECISIONS.md [2026-08-12])

## Question

Does the lift-kite axial tension materially change the static torsional
FoS gate at 5 kW? The gate computes τ_cap ∝ T_total where
T_total = Σ(thrust from rotors) — lift-device tension is NOT included
(trpt_optimization.jl:375 `T_total_rated = sum(T_ring)`).

## Results

| Quantity | Value |
|----------|-------|
| Lift-device axial tension T_lift (ODE, live state) | 1041.5 N |
| Rotor thrust (BEM est, CT=0.55) | 1600.7 N |
| **T_lift / T_thrust** | **0.651** |
| Static torsional FoS (thrust only) | 0.314 |
| Static torsional FoS with lift tension added | 0.519 |
| Gate (OPT_TORSION_FOS_REQUIRED) | 1.5 |

## Findings

1. **Lift tension is significant** — 65% of rotor thrust. It should be
   included in the static gate's T_total as correct physics regardless of
   the 5kW question.
2. **But it does not close the gap at 5 kW** — 0.314 → 0.519, still 2.9×
   short of 1.5.
3. **The ODE (which includes lift tension) sustains 6.34 kW on this same
   design** — the conservative piece is the τ_cap formula itself: the
   April-2022 (v3) gate applies Tulloch's constant-radius criterion
   per-segment on a tapered shaft. DECISIONS.md [2026-04-20] flagged that
   "not a trivial extension of Tulloch's constant-radius derivation" was
   needed; that extension was never done.

## Disposition (pending Rod)

- No DECISIONS entry yet — test first, decide after seeing 7 kW and 10 kW rungs.
- If 10 kW also flips (static gate vs ODE), the tapered-shaft τ_cap
  derivation becomes the work item.
- For ≤7kW rungs the ODE gate remains the arbiter; static torsional gate
  is report-only at that scale.
