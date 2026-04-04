# Task Note — MPPT × Twist Angle Analysis

**Created:** April 2026
**Status:** First sweep COMPLETE. Improved sweep queued (see §Next run).

## What we're doing

Running a parametric sweep of MPPT gain (`k_mppt`) and hub wind speed (`v_wind`)
to characterise how the TRPT structural twist angle settles at steady state.

**Script:** `scripts/mppt_twist_sweep.jl`
**Results:** `scripts/results/mppt_twist_sweep/` (created by the script)

## Why

Hypothesis (to be tested with data — no conclusion yet):

> The steady-state twist angle of the TRPT shaft may encode the blade
> incidence operating point.  If twist correlates with Cl/Cd ratio, it
> could serve as a passive or low-bandwidth control signal for bridling
> (adjusting blade angle of attack), without requiring an explicit blade
> pitch sensor.

This is a hunch worth investigating with simulation before any physical
experiment or control-loop design.

## Sweep parameters

| Variable | Values |
|---|---|
| `k_mppt` multiplier | 0.25×, 0.5×, 1.0×, 1.5×, 2.5×, 4.0× nominal (11 N·m·s²/rad²) |
| Hub wind speed | 8, 10, 11, 13 m/s |
| Simulation time | 60 s per combination (+ 5 s spin-up) |
| Record interval | 0.5 s |

**Total:** 24 combinations × ~10 min wall time ≈ 4 hours.

## How to resume / re-run

```bash
# From repo root — run in background overnight:
nohup julia --project=. scripts/mppt_twist_sweep.jl \
  > scripts/results/mppt_twist_sweep/sweep.log 2>&1 &

# Monitor progress:
tail -f scripts/results/mppt_twist_sweep/sweep.log
```

## What to look for in the results

1. **Twist vs k_mppt at fixed wind**: Does twist increase monotonically with
   MPPT gain (more braking = more torque = more shaft twist)? If yes, twist
   is a reliable proxy for torque load.

2. **Twist vs wind speed at fixed k_mppt**: Does twist change with wind speed?
   If twist is approximately wind-speed-independent at the same k_mppt, it
   reflects the control setting. If it tracks wind speed strongly, it could
   serve as a wind estimator.

3. **Twist stability**: Does the twist settle cleanly, or does it oscillate?
   The torsional damping fix (principal-value Δα, April 2026) should keep
   it stable — this data will confirm that.

4. **Power vs twist**: Is there an identifiable twist range where P/W is
   maximised? This would be the "sweet spot" for the bridling controller.

## First sweep results (April 2026)

Results in `scripts/results/mppt_twist_sweep/`. Key findings:

- Twist range across all conditions: **90° – 228°**
- Maximum power occurs at k×1.0 (nominal MPPT) for all wind speeds — good calibration
- Twist at max-P point: 142° (8 m/s) → 199° (13 m/s) — NOT wind-speed-independent
- Twist is **ambiguous** as a sole control signal: same twist value can occur at two
  different k_mppt settings (under-braked fast vs over-braked stalled) — panel E
- Heavy-braking cases (k×2.5, k×4.0) not fully settled at t=65 s — need longer runs
- Torsional damping fix confirmed working: small std dev in settled region (±2–5°)

## Analytical twist prediction (from geometry + force ratios)

For small twist angles, the per-segment equilibrium gives:

    δα ≈ (τ / T) × L_seg / (n × r_s²)

where τ = shaft torque, T = tether tension per line, L_seg = inter-ring spacing,
n = number of lines, r_s = ring radius.

Total stack twist = sum over all segments. In the linear regime this is:

    Δα_total ≈ (τ / T) × L_total / (n × r_s²)

So twist scales as the **torque:tension ratio** multiplied by a pure **geometry factor**
(L/r² per line). At large angles the full transcendental rope-chord equation must be
used (see ring_forces.jl), but the ratio structure is preserved. This means twist is
directly predictable from measurable quantities (shaft torque, tether tension, geometry)
without running the simulator.

## Next run — planned improvements to sweep script

Changes needed in `scripts/mppt_twist_sweep.jl`:

1. **Longer simulation** — increase T_SIM from 60 → 180 s (heavy-braking cases still
   drifting at t=65 s; need at least 120 s for k×2.5–4.0 to settle)

2. **Add tether tension recording** — `T_max` from `ring_safety_frame()` alongside
   twist; validates the analytical δα ≈ (τ/T) × geometry prediction

3. **Add Δω (hub−PTO slip)** — `omega_hub − omega_gnd`; the slip is the mechanical
   loading signal and likely more informative than absolute ω

4. **Add per-segment twist profile** — record α at rings 1, 5, 10, 16 (ground, mid-low,
   mid-high, hub) to see whether twist distributes uniformly along the shaft

5. **Finer k_mppt resolution** — add k×0.75 and k×1.25 to better resolve the peak
   and its width

6. **Add wind ramp scenario** — run a 0 → rated → 0 wind ramp at k×1.0 to see
   twist dynamics during transients (key for any real controller)

## Future work — lift line and stacking lift kite modelling

Tracked separately. Priority additions to the simulator:

- **Lift line tension model**: add a `lift_force()` function that computes kite
  lift/drag from elevation angle, wind speed, and kite Cl/Cd; apply to hub node
  as an upward+inward force; record lift tension alongside twist and power

- **Stacking lift kites**: model a secondary lifter kite on a separate bridle above
  the rotor; parameterise lifter area, Cl/Cd, line length; key question is whether
  a single lifter can support multiple stacked rotors more efficiently

- **Lifting rotor kite configurations**: model the rotor itself contributing lift
  (via blade incidence angle / non-zero Cl when not at optimal TSR); assess how
  much of the airborne weight can be self-supported vs needing a dedicated lifter

- **Broader wind speed range for lifters**: lifter kites operate efficiently at lower
  wind speeds than power kites; model the overlap region (6–9 m/s) where the lifter
  is doing real work but the rotor is below rated

## Next steps

- Run improved sweep (see §Next run) overnight
- Validate analytical twist prediction (δα ≈ (τ/T)×geometry) against sweep results
- If twist-at-max-P correlates with a constant τ/T ratio, it supports using tether
  tension as the primary MPPT feedback signal in real systems
- Design bridling controller experiment once the τ/T relationship is confirmed
