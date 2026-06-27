# TRPT Soft-Ramp k_mppt Controller

**Status:** Planned — not yet implemented  
**Date:** 2026-06-26  
**Context:** AWEC Porto 2026 — V10 Tight dashboard k_mppt hunting is manual and fragile

## Problem

The V10 Tight winner (49.2 kg, 3 rotors) can theoretically produce 50 kW at 59 rpm with
k_mppt_eff = 166 (static equilibrium). Dynamic verification shows it only reaches 12.1 kW
at 55.6 rpm with k_mppt = 62. The static solver overpredicts because it assumes instant,
lossless torque propagation through the TRPT shaft.

In reality, torque propagates sequentially through each ring pair. Each segment has:
- Torsional stiffness k_sec (varies with DE-optimised radii r_a, r_b)
- Critical damping c_s = 2√(k_sec × I_s)
- Tension-only clamp (line slack → coupling breaks)

A too-aggressive k_mppt loads the generator before the rotor has spun up, stalling the
shaft. Too low and the rotor overspeeds. The sweet spot is narrow and drifts with wind.

## Goal

A closed-loop controller that:
1. Ramps k_mppt smoothly from a safe low value toward the rated-power target
2. Respects structural constraints (FoS ≥ 1.5 at every ring, no line slack)
3. Adapts to wind gusts and rotor speed changes
4. Finds and holds the maximum sustainable power point

## Architecture

```
  ┌──────────────┐    structural HUD    ┌──────────────────┐
  │    TRPT ODE   │───FoS, slack,tension──→│  Soft-Ramp PID   │
  │  (dynamics.jl)│                      │                  │
  │              │←──k_mppt adjustment──│  target: 50 kW    │
  └──────────────┘                      │  limit: FoS ≥ 1.5 │
                                        │  limit: no slack  │
                                        └──────────────────┘
```

## Implementation Plan

### Phase 1: Monitor (use existing HUD data)
The dashboard already tracks per-segment tension, ring buckling utilisation, slack line
count, and generator power. No new instrumentation needed.

### Phase 2: Add ramp state machine
```
State: IDLE → RAMPING → HOLDING → ADJUSTING

IDLE:      k_mppt = k_min (~20), rotor spins up unloaded
RAMPING:   k_mppt += Δk per second, monitor FoS and slack
HOLDING:   power stable, FoS > 1.5, hold k_mppt
ADJUSTING: power dropped (gust lull), try small k_mppt increases
PROTECT:   FoS < 1.5 OR slack detected → aggressive k_mppt reduction
```

### Phase 3: PID tuning
- **Proportional**: error = P_target - P_actual. Increase k_mppt if below target.
- **Derivative**: rate of power change. If power is still climbing, wait — TRPT has inertia.
- **Integral**: accumulated error. Slow correction for steady-state offset.
- **Anti-windup**: clamp k_mppt to [k_min, k_max] where k_max is the value at which
  the lowest ring hits FoS = 1.5.

### Phase 4: Dashboard integration
- New button: "Auto-Ramp" (toggles the PID on/off)
- Status indicator: shows current state (RAMPING / HOLDING / PROTECT)
- Target power slider (default 50 kW, can dial down for conservative runs)
- FoS floor slider (default 1.5)

## Key design decisions

1. **k_mppt is the control variable, not the goal.** We don't need to solve for the
   optimal k_mppt analytically — the PID handles that. The goal is power at the
   generator, and the constraint is structural safety.

2. **Line slack is the hard limit.** If any tether segment goes slack, torsional coupling
   through that ring pair breaks. The PID must react to slack within 1-2 ODE steps
   (dt = 4×10⁻⁵ s → ~80 μs). This needs a fast inner loop, not the dashboard's
   frame-by-frame update.

3. **FoS is the soft limit.** Ring buckling at FoS < 1.0 is failure. The PID should
   keep FoS ≥ 1.5 to allow margin for gusts. If FoS drops toward 1.2, reduce k_mppt
   aggressively.

4. **The 4.1× gap is the PID's job.** The static-to-dynamic gap exists because the
   equilibrium solver doesn't model the TRPT's torsional dynamics. The PID controller
   bridges this gap by operating in the dynamic domain — it doesn't need to know the
   static prediction, only the live structural state.

## Code locations

- `src/dynamics.jl` — multibody_ode! (the plant)
- `src/ring_forces.jl` — per-segment torque/tension coupling (the transmission model)
- `src/visualization.jl` — dashboard HUD (already has FoS, slack, tension, power)
- `src/objective_v10.jl` — static k_mppt scaling (reference only, not used by PID)

## Dependencies

None external. Uses existing ODE state, structural HUD data, and Makie callbacks.
