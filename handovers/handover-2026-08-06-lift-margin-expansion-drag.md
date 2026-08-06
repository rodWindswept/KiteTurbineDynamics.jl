# Handover — 2026-08-06: lift_margin fix + campaign results + expansion rotor drag diagnosis

## What was done

### lift_margin = 0.00× fix (2 files)

**`src/sim_frame.jl`** — `capture_frame` type dispatch
- Added `StackedLifterParams` branch so telemetry populates `T_lift`, `lift_margin`, `lift_type` correctly
- Backfilled `lift_margin` computation for `SingleKiteParams` and `StackedKitesParams`
- `StackedLifterParams` uses its own `m_airborne_ref` field for the requirement, not `autogyro_lift_required`

**`src/objective_v11.jl`** — cold path lift_device plumbing
- Added `lift_device` keyword param (default `nothing`, backward compatible)
- Resolves Function→LiftDevice after system build, passes to settle/kickstart/capture/sim
- (Warmstart path was already correct)

**Verified:** Best genome shows `T_lift=2381 N`, `lift_margin=1.49×`, `lift_type=:stacked` (was 0, 0.00, :none).

### Campaign results (`feasibility_phase_a_v2.csv`, 48 evals, ea32d6d)

| Gen | Best P | Best FoS | f_feas |
|-----|--------|----------|--------|
| 1–6 | 23.8 kW | 0.605 | 10.047 |

- 0/48 feasible. All `stationary=false`.
- DE stalled after gen 1 — flat basin around V10 seed.
- Expansion rotors are a **net drag** (see below).

## Expansion rotor drag diagnosis

At t=2s (ω_hub≈32 rpm, V=11 m/s):

| Rotor | Ring | r_nom | blade_tip | P_aero |
|-------|------|-------|-----------|--------|
| Hub | — | 5.0m | 5.6m | +2.4 kW |
| R1 | ring 11 | 2.1m | 6.8m | +42.3 kW |
| R2 | ring 7 | 4.3m | 8.8m | +29.0 kW |
| R3 | ring 4 | 3.0m | **12.4m** | **−89.6 kW** |

**Net: −18.3 kW.** Rotor 3 at ring 4 has a 12.4m blade on a 3.0m ring — blade midspan at 9.4m from TRPT axis. Fixed-CL=0.7 model gives huge forces but at φ≈17°, drag component dominates the tangential lift at this shallow inflow. The shaft unwinds (ω_gnd=34.9 > ω_hub=32.3 rpm).

The 23.8 kW campaign peak was during warmstart transient before rotor 3's drag fully engaged.

## N_crit = 3.79 kN constant across rings

BY DESIGN. Tube law `Do = 0.01396 × √R` makes `I ∝ R²`, `L_beam ∝ R`, so `N_crit ∝ R²/R² = constant`. This is the constant-compression design.

## Remaining issues

1. **Beam sizing:** Why aren't larger tubes appearing? `Do = DO_SCALE × √R` with `DO_SCALE=0.01396` is fixed at build time. Does the DE have a knob for tube diameter, or is it purely geometry-driven?
2. **Expansion rotor blade sizes:** 12.4m tip on 3.0m ring is physically absurd. Blade scaling through λ applies multiplicatively to expansion rotors — check if there's a cap.
3. **Campaign CSV `lift_tension_N`:** Still the constant 1.5 placeholder. TODO to thread T_lift through objective_v11_warmstart return tuple.
4. **Stationarity:** All 48 designs `stationary=false` — measurement window catches transient decay, not steady state.
