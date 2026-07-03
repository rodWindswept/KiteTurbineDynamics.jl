# V10 Tight Sweep — 2026-06-29

## Fixes applied since 2026-06-28 sweep

1. **Expansion rotor power in equilibrium scan** (`src/initialization.jl:710`)
   - `settle_to_operational_state` now sums P_aero from hub + all expansion rotors
   - Previously only used hub rotor, falling back to ω_eq=9.5 for V10 Tight
   - Fixes: TRPT now settles to correct preloaded state at the right operating ω

2. **Kite position lag in settle loop** (`src/initialization.jl:875`)
   - `update_kite_pos!` called during 150,000-step operational settle
   - Previously the kite stayed at design position while bearing moved → snap at frame 1
   - Fixes: lift line appears correctly positioned at frame 0

3. **HOLDING no longer blocked by structural margin** (`src/soft_ramp_controller.jl:250`)
   - Removed `struct_mult >= 0.99` requirement for HOLDING transition
   - Structural guards still limit ramp rate but don't prevent reaching steady state
   - Fixes: controller can reach HOLDING even when FoS is below soft limit

4. **Brake auto-engagement removed** (`src/ring_forces.jl:89`)
   - `new_brake_engaged = brake_engaged` (was `brake_engaged || abs(omega_hub) < 1.0`)
   - Fixes: brake no longer latches when ω drops below ~9.5 rpm during normal operation

5. **Controller init after settle** (`src/visualization.jl:854`)
   - Auto-ramp controller initialised AFTER operational settle
   - Fixes: `init_geometry!` sees settled ring positions, not raw u0

6. **Warm start: skip IDLE if already spinning** (`src/visualization.jl:867`)
   - If settled ω > idle threshold, controller starts in RAMPING not IDLE
   - Fixes: no pointless 0.5s IDLE wait when system is already at operational speed

## Scenarios run

| k_mppt | Controller | T_sim |
|---|---|---|
| 62 | None (fixed) | 60s |
| 550 | None (fixed) | 60s |
| 550 | Soft-ramp (k_min=110, k_max=1100) | 60s |

## Expected differences from 2026-06-28

- Settled state should show correct TRPT twist and preload for V10 Tight
- No lift-line snap at frame 0
- k=62 should overspeed as before, but from a properly settled start
- k=550 should show the correct equilibrium, not the progressive decay seen before
  (the decay was likely caused by wrong initial twist over-stressing rings)
- Soft-ramp should transition RAMPING→HOLDING once power stabilises
