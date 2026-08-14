# Dashboard ObjectiveConfig Exposure — PRD

**Date:** 2026-08-11
**Status:** Proposed
**Priority:** Medium (enables manual calibration workflow)

## Problem Statement

The dashboard currently uses hard-coded builder presets (v10-tight, v10-reinforced, etc.)
but has no way to adjust the `ObjectiveConfig` scoring knobs that the DE evaluator uses:

- `p_floor_kw` (25.0) — power floor for "stalled" classification
- `p_ceiling_kw` (50.0) — power ceiling for penalty
- `fos_target` (3.0) — ideal FoS for scoring
- `fos_hard` (1.5) — hard rejection floor
- `fos_cap` (16.0) — hard rejection ceiling (new, 2026-08-11)
- `w_floor`, `w_ceiling`, `w_fos_below`, `w_fos_above` — penalty weights
- `relax_s`, `window_s` — protocol timing
- `v_rated` — rated wind speed

Without exposing these, a user cannot:
- Test a design against different P_floor values to see where it lands in the three-tier sort
- See how FOS_TARGET=3.0 vs 1.5 changes a seed's fitness
- Adjust stationarity swing tolerance and watch designs flip between "stationary" and "drifting"
- Independently assess design hunches without running a full DE campaign

## Proposed Solution

Add an **Objective Config panel** to the dashboard (V2 cockpit) that exposes all `ObjectiveConfig`
fields as interactive controls:

- **Sliders** for continuous parameters (p_floor_kw, fos_target, relax_s, etc.)
- **Dropdowns** for discrete choices (v_rated: 5, 7, 9, 11, 13, 15 m/s)
- **Live score display** showing current fitness, tier classification, and stationarity status
- **"Score with current config" button** that re-evaluates the active design

## Implementation Notes

- `ObjectiveConfig` is already an immutable struct with keyword defaults — suitable for GUI binding
- The evaluator functions (`evaluate_windowed`, `evaluate_ramp`) accept `ObjectiveConfig` directly
- Config changes would trigger a re-evaluation (potentially expensive — add a "Score" button rather than live-binding)
- Consider a "compare" mode: show scores for two configs side-by-side

## Out of Scope

- Running DE campaigns from the dashboard
- Saving/loading config presets (future enhancement)

## Dependencies

- Dashboard V2 cockpit (`scripts/interactive_dashboard.jl --v2`)
- `ObjectiveConfig` struct (stable, in `src/objective_evaluator.jl`)
