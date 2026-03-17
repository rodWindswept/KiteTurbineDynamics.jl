# KiteTurbineDynamics.jl

Full multi-body dynamics simulator for a **TRPT kite turbine** — a Tensile Rotary Power Transmission airborne wind energy system developed by [Windswept & Interesting Ltd](https://windswept.energy).

## What it is

Unlike quasi-static TRPT simulators, this package models every tether line individually as a chain of spring-damper rope nodes. Torsional coupling between rings is **emergent** from the helical geometry of those lines — there is no analytical torque formula. This enables simulation of:

- Rope sag and catenary shape under gravity and wind drag
- Line slack → torsional collapse (the key failure mode for TRPT)
- Per-ring hoop compression and Euler buckling factor of safety
- Hub spin-up, MPPT generator load, and power extraction

**System size:** 241 nodes (16 RingNodes + 225 RopeNodes), 1 478-state ODE.

## Install

```julia
pkg> add https://github.com/windswept/KiteTurbineDynamics.jl
```

Or from a local clone:

```julia
pkg> dev /path/to/KiteTurbineDynamics.jl
```

## Quick start

```julia
using KiteTurbineDynamics

p        = params_10kw()                     # 10 kW parameter set
sys, u0  = build_kite_turbine_system(p)      # 241 nodes, 300 sub-segments
u_settled = settle_to_equilibrium(sys, u0, p) # gravity sag pre-solve (~0.3 s)

# Custom wind profile
wind_fn = (pos, t) -> begin
    z  = max(pos[3], 1.0)
    sh = (z / p.h_ref)^(1.0/7.0)
    [p.v_wind_ref * sh, 0.0, 0.0]
end

# Seed hub angular velocity and run 2 s forward
N, Nr = sys.n_total, sys.n_ring
u_start = copy(u_settled)
u_start[6N + Nr + Nr] = 1.0   # hub omega = 1 rad/s

u_final = simulate(sys, u_start, p, wind_fn; n_steps=50_000, dt=4e-5)
println("Hub ω = ", u_final[6N + Nr + Nr], " rad/s")

# Structural safety check
alpha_vec = u_final[6N+1 : 6N+Nr]
sf = ring_safety_frame(u_final, alpha_vec, sys, p)
for r in sf
    @printf "Ring %2d  FoS = %.2f\n" r.ring_id r.fos
end
```

## GLMakie dashboard

```julia
# scripts/interactive_dashboard.jl — pre-built script
julia --project=. scripts/interactive_dashboard.jl
```

Opens a 3D view with rope node geometry, ring polygons coloured by structural utilisation (blue = safe → red = at limit), a structural HUD, and a frame slider for playback.

## System architecture

```
Ground anchor (fixed)
│
├─ 5 tether lines × 4 sub-segments per inter-ring segment
│    Each segment: ring_A ─ rope_1 ─ rope_2 ─ rope_3 ─ ring_B
│    Torsional coupling emerges from helical attachment-point geometry
│
├─ 14 intermediate rings (intermediate RingNodes)
│
└─ Hub (RingNode) — rotor disc, kite tether attachment
     Kite lift + rotor thrust + MPPT generator load
```

## Tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

All 11 test suites pass:
- Parameters, aerodynamics, types, geometry, rope forces, ring forces, ODE smoke
- Static equilibrium (gravity sag), rope sag, emergent torsion, power generation

## Licence

MIT © 2025 Rod Read / Windswept & Interesting Ltd
