# Build-geometry audit — build_system_from_v10 wiring (2026-08-24)

**Status:** FINDING — the ODE builder dropped three genome geometry genes;
fix landed (v5 builder), campaign re-run required.

## The bug

`build_system_from_v10` built the ODE system with the LINEAR-taper
`build_kite_turbine_system`, which derives the bottom radius as
`r_bot = 2·L·trpt_rL_ratio/n_seg − r_hub` from the FIXED base `trpt_rL_ratio`
(1.083) and the hub radius.  It never reads the genome's geometry genes:

| Gene | Meaning | Decoder | ODE (linear builder) | Verdict |
|---|---|---|---|---|
| x5 r_hub | hub ring radius | ring_spacing_v4 | trpt_hub_radius | flows |
| x6 r_bottom | ground ring radius | ring_spacing_v4 | ignored (derived from rL_ratio) | **DEAD** |
| x7 target_Lr | ring spacing L/r | ring_spacing_v4 | ignored (fixed rL_ratio) | **DEAD** |
| x9 density_profile | ring clustering | ring_spacing_v4 | ignored (linear taper) | **DEAD** |
| x3 aspect_ratio | beam ellipticity | — | — | known dead (fixed 1.0) |

Consequence: the decoded winner (r_bottom 0.479 m) was simulated as a machine
with r_bottom 2.224 m (4.6× too fat), and the DE optimised x6/x7/x9 as if they
controlled the ODE geometry.  Every 5 kW campaign result since the evaluator
consolidation used this wrong geometry.  This is the ADR-0005 wrong-geometry
class, persisting in the builder choice.

## The fix (landed 2026-08-24)

- `build_system_from_v10` now calls `build_kite_turbine_system_v5` (the
  `ring_spacing_v4` geometry) with `design.target_Lr`, `design.r_bottom`,
  `design.density_profile`.
- `build_kite_turbine_system_v5` gained a `density_profile` kwarg (was
  silently dropping it).
- Regression test: the ODE ring radii must equal `ring_spacing_v4`'s output
  for the decoded design (would have caught the bug).

## Consequences

- The re-run's winners are VOID (their geometry was not what the ODE ran).
  Re-run the campaign on the corrected geometry.
- The settlement/geometry of the seed changes (its ODE bottom ring is now the
  decoded r_bottom, not the rL_ratio-derived value) — re-smoke before re-run.
- The geometry re-run may also change the k sweep and the settle-gap numbers.

## Remaining geometry wiring (verified correct)

- Rotor annulus (r_out = r_hub + 0.7·span, r_in = r_hub − 0.3·span, clamped):
  flows via sys.rotor + blade_hub_radius, ring-anchored 70/30.  OK.
- n_lines, n_rings, rotor masks, bank angles, blade scale/chord: flow via the
  decoder's rotors and GeometrySpec.  OK.
- Tether length: fixed at the rung (18.8 m) via the base — intended, not a bug.
- Elevation/lifter angles: fixed base params.  Intended.
