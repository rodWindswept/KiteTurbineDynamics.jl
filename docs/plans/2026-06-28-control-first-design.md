# Plan: Control-First Design — "Work Backwards" from the Turbine Geometry

**Date:** 2026-06-28
**Status:** Planned
**Depends on:** `scripts/hunt_kmppt.jl` (exists), `scripts/record_ramp_traces.jl` (exists)

## Motivation

The current workflow is "design a turbine, then hunt for a controller that might keep it
alive."  This is the wrong order — it discovers structural infeasibility only AFTER the
DE campaign has already converged on a geometry (as we saw with V10 Tight: 49.2 kg,
FoS=0.43 at k=62, FoS=0.75 at k=550).

The proposed workflow flips this: given a turbine geometry, sweep wind speeds and find the
k_mppt that produces the rated power at each wind speed.  Record the structural margin.
If any operating point has FoS < 1.5, the geometry is infeasible.  If all pass, we have
the control law k(v_wind) built in.

## Approach

For a given turbine geometry (rings, radii, tethers, lines, rotors):

```
For each wind speed v ∈ [5, 7, 9, 11, 13, 15] m/s:
  1. Hunt k_mppt such that |P_gen − P_rated| < ε  (ε = 5% of P_rated)
  2. Run 30s verification sim at the found k*
  3. Record: k*, P_final, ω_final, min FoS, collapse margin, T_max, twist
```

Output: a **control map** — a table of k(v_wind) and FoS(v_wind).

## Deliverables

### Script: `scripts/map_control_law.jl`

- Takes a system builder function as input (e.g. `build_canonical_10kw` or `build_v10_tight`)
- Sweeps 6 wind speeds, hunts k_mppt at each
- Runs 30s verification at each found k*
- Outputs CSV: `scripts/results/control_maps/<name>.csv`

Columns: `v_wind, k_mppt, P_kw, omega_rpm, min_fos, collapse_margin_deg, twist_deg, T_max_kN`

### Figure: Control Map

- Upper panel: k_mppt(v_wind) — the control law curve
- Lower panel: FoS(v_wind) with 1.5 hard floor — the safety curve
- Green/red colouring: green if FoS ≥ 1.5 at all wind speeds, red if any point fails

## Validation

Run on canonical 10 kW first (known-good):
- Should produce a smooth k(v) curve
- Should show FoS ≥ 1.5 at all wind speeds
- Confirms the methodology works

Then run on V10 Tight (known-bad):
- Should show FoS crossing below 1.5 at some wind speed
- Quantifies exactly WHERE it fails
- Provides evidence for the structural redesign needed

## Integration with DE Campaign

The control map becomes the **inner loop** of a future dynamic-aware DE campaign:

```
For each candidate geometry:
  1. Run map_control_law to find k(v) and FoS(v)
  2. If min(FoS) < 1.5: penalty = 1e6 × (1.5 − min FoS)
  3. Else: score = mass + λ × mean(|P − P_rated|/P_rated)
```

This eliminates the two-level hunt-verify per candidate that was proposed in DECISIONS.md.
The control map runs once per candidate, producing both the viability check AND the control
law simultaneously.

## Timeline

- Write script: 1 hour
- Validate on canonical 10 kW: ~30 min (6 wind speeds × 30s each ≈ 15 min wall)
- Run on V10 Tight: ~30 min
- Figures: 30 min
- Total: ~2.5 hours
