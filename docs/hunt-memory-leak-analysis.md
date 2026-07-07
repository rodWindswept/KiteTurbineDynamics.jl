# Memory Leak in hunt_control_map — Post-Mortem

**Date:** 2026-07-07
**Status:** Defect — blocks λ=0.69 Gate 2 re-hunt; workaround: use Gate 1 data

## Symptom

`hunt_control_map` with `max_power=true` on the V10 λ=0.69 design runs
until Julia exhausts available memory, then crashes with exit code 124
(timeout). All five attempts across three invocation patterns failed.

## Attempted invocations

| Pattern | Winds/process | Allocations | Outcome |
|---------|--------------|-------------|---------|
| Multi-wind script | 6 | 324 GB | Reinforced saved, λ=0.69 saved nothing |
| Multi-wind script | 5 | 334 GB | Saved nothing |
| Single wind (`-e`) | 1 | 58-69 GB | Timed out before completion |
| Two winds (`-e`) | 2 | 159-162 GB | Timed out before completion |
| Two winds parallel | 2×2 | 162+159 GB | Both timed out |

The Reinforced design (blade_scale=1.0, tether_diameter=0.004, r_bottom_scale=1.30)
completed successfully and saved its CSV. λ=0.69 (blade_scale=0.69) failed
in all configurations.

## Root cause

`hunt_kmppt_bisect.jl` calls `build_kite_turbine_system()` 10+ times per
wind during the k-sweep and bisection phases. Each call allocates a fresh
KiteTurbineSystem (nodes, edges, springs, rotors). The GC cannot reclaim
these allocations between calls, causing linear memory growth:

- **~6 GB per builder call** (from per-wind allocation / sweep count)
- **~15 builder calls per wind** (10 sweep + ~5 bisection)
- **~80 GB per wind for λ=0.69**
- **~55 GB per wind for Reinforced**

The δ=45% difference between designs suggests λ=0.69 triggers more eval/recompile
cycles or creates larger intermediate structures (smaller blades → wider k-sweep
range → more k values tested → more builder calls).

## Why Gate 1 succeeded

Gate 1 was run on 2026-07-05/06 (commit `13f304a`) with a smaller EvalResult
struct (14 fields vs 22 today). The evaluator was called during verify (60s ×
1Hz = 60 calls) but the struct was smaller. The builder leak was always present
but Gate 1 completed before memory exhaustion — likely due to lower baseline
allocations from the simpler struct.

Since `13f304a`, the EvalResult grew by 8 fields (57%):
- Centrifugal blade loads (`e5b4886`)
- SpokeParams + spoke FoS (`784be6b`)
- required_MBL_N (`18043d4`)
- strut tension FoS (`ed8c3a6`)
- blade-root bending FoS (`f1b5f4e`)
- bridle FoS + lateral line load (`6f0dc35`)

## Impact

- Reinforced Gate 2 data: **complete** (6 winds saved)
- λ=0.69 Gate 2 data: **workaround** — Gate 1 data (`max_power=true`, same geometry) is Gate-2-equivalent
- Post-processing (spoke/drag/stability): **unaffected** — these columns are computed from existing timeseries CSVs, not from new hunts
- Future hunts (V11, site-specific re-optimisation): **blocked** until the leak is fixed

## Fix plan

1. **Profile** the builder → `build_kite_turbine_system` for the λ=0.69 design.
   Compare allocations vs Reinforced. Hypothesis: the λ=0.69 design creates
   more expansion rotor parameters, larger node graphs, or wider k-sweep range.
2. **Reduce k-sweep** — the current sweep tests 10 k-values; Gate 2 only needs
   the peak. Narrow the sweep range or reuse Gate 1 k as the starting point.
3. **Reuse system** — the builder creates an identical KiteTurbineSystem for
   each k-try (only k changes, geometry is fixed). Cache the system and vary k
   without rebuilding.
4. **Run per-wind** — as a stopgap, 1 wind per process with `GC.gc()` between
   runs. This worked for Gate 1 but fails for λ=0.69 with today's struct.

## Ticketed

⬜ Profile λ=0.69 builder allocations (src issue)
⬜ Reduce k-sweep to narrow range around Gate 1 optimum (hunt script fix)
⬜ Cache KiteTurbineSystem between k-sweep calls (performance fix)
⬜ Add `GC.gc()` after each wind in hunt_control_map (hygiene)
