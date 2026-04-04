# Task Note — MPPT × Twist Angle Analysis

**Created:** April 2026
**Status:** Sweep script written; results pending (long-running job)

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

## Next steps (after data is available)

- Plot twist heatmap (k_mppt × v_wind) with power overlay
- Identify the twist value at maximum P/W for each wind speed
- Check whether that twist value is approximately constant across wind
  speeds (which would make it a wind-speed-independent set-point)
- If promising: design a simple proportional bridling controller that
  targets a fixed twist angle and test in simulation
