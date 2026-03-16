# KiteTurbineDynamics.jl — Design Document

**Date:** 2026-03-16
**Status:** Approved, ready for implementation
**Supersedes:** `TRPTKiteTurbineJulia2` (`scripts/interactive_multibody.jl`)

---

## Motivation

`TRPTKiteTurbineJulia2` models each inter-ring tether segment as a single spring-damper
element with analytical torsional coupling (`compute_tensegrity_torque()`). This means:

- Tether lines between rings are rendered as single straight segments — no sag, no
  catenary, no centrifugal bow-out
- Torsional collapse is detected analytically, not physically — lines cannot individually
  go slack
- In low-wind, launch, and land states, rings appear to float in space rather than being
  visibly supported by tensioned lines

`KiteTurbineDynamics.jl` is a new Julia package that replaces this with full individual
line rope physics. It is designed for open-source sharing with the AWE research community.

---

## Package Identity

| Field | Value |
|---|---|
| Package name | `KiteTurbineDynamics.jl` |
| Location | `~/Documents/GitHub/KiteTurbineDynamics.jl/` |
| Julia version | 1.12+ |
| Intended audience | Open-source AWE researchers |
| Install | `pkg> add https://github.com/windswept-energy/KiteTurbineDynamics.jl` |

---

## Scope

**In scope:**
- Full individual-line rope physics for all 15 TRPT shaft segments (5 lines × 3
  intermediate nodes × 15 segments = 225 rope nodes)
- Emergent torsional coupling from attachment-point geometry (replaces analytical formula)
- Gravity sag, centrifugal bow-out, aerodynamic drag on rope nodes
- Ring hoop compression computed and displayed as a safety indicator (FoS)
- Torsional collapse emerging naturally from line slack (tensile-only springs)
- Interactive GLMakie dashboard with per-line force coloring and structural HUD

**Out of scope (deferred):**
- Lift kite tether rope physics (direct applied force on hub node, as now)
- Ring buckling deformation (point-mass limitation; FoS flagged in HUD)
- Individual line severance/failure (deferred — add `broken` flag later)

---

## Node Architecture

### Node Types

```julia
abstract type AbstractNode end

struct RingNode <: AbstractNode
    id        :: Int      # global index in unified node list
    ring_idx  :: Int      # index into the 16-element twist sub-array
    mass      :: Float64
    radius    :: Float64  # ring radius (m) — for attachment point geometry
    inertia_z :: Float64  # torsional moment of inertia (kg·m²)
    is_fixed  :: Bool
end

struct RopeNode <: AbstractNode
    id       :: Int       # global index in unified node list
    mass     :: Float64   # n_lines × ρ_line × A_line × L₀_sub
    line_idx :: Int       # which of the 5 lines (1–5)
    seg_idx  :: Int       # which inter-ring segment (1–15)
    sub_idx  :: Int       # intermediate position within segment (1–3)
end
```

Hub, ground anchor, and all ring spacers are `RingNode`.
Intermediate rope nodes are `RopeNode`.
Ground anchor has `is_fixed = true`.

### Physical Node Ordering

Nodes are ordered from ground upward, rope nodes interleaved naturally between rings:

```
index 1    : ground anchor         (RingNode, fixed, ring_idx=1)
indices 2–16  : rope nodes seg 1, lines 1–5, sub-nodes 1–3  (15 × RopeNode)
index 17   : ring 1               (RingNode, ring_idx=2)
indices 18–32 : rope nodes seg 2, lines 1–5, sub-nodes 1–3  (15 × RopeNode)
ring 2     ...
           ...
ring 14    (RingNode, ring_idx=15)
rope nodes seg 15, lines 1–5, sub-nodes 1–3
index 241  : hub / rotor          (RingNode, ring_idx=16)
```

**Total nodes: 241** (16 RingNode + 225 RopeNode)

---

## State Vector

Approach B — unified interleaved layout. All nodes share the position/velocity block;
only RingNodes have twist states.

```
u[1          : 3×241]       positions   x,y,z  for all 241 nodes
u[3×241+1    : 6×241]       velocities  vx,vy,vz for all 241 nodes
u[6×241+1    : 6×241+16]    twist angles   α_i  (rad)   — RingNodes only
u[6×241+17   : 6×241+32]    twist rates    ω_i  (rad/s) — RingNodes only
```

**Total states: 1478** (vs 128 in TRPTKiteTurbineJulia2)

A `RingNode`'s `ring_idx` field is its index into the 16-element twist sub-arrays.
`RopeNode`s have no twist DOF — their angular position is determined by the two
bounding ring nodes' twist angles.

---

## Force Model

### Sub-Segment Spring Forces

Each inter-ring segment has 5 lines, each with 4 sub-segments (3 intermediate rope
nodes). For sub-segment from node P to node Q:

```
stretch_vec  = pos_Q − pos_P
current_len  = ‖stretch_vec‖
dir          = stretch_vec / current_len
strain       = (current_len − L₀_sub) / L₀_sub
tension_mag  = max(0,  EA_single_line × strain
                     + c_damp × dot(vel_Q − vel_P, dir))   ← tensile only
tension_vec  = tension_mag × dir

force on P  += +tension_vec
force on Q  -= +tension_vec
```

Where:
- `EA_single_line = E × π(d/2)²` for one Dyneema line
- `L₀_sub = L₀_segment / 4`
- `c_damp` = structural damping coefficient per line

The `max(0, ...)` clamp is the entire torsional collapse model — lines go slack
naturally when overtwisted or under-tensioned.

### Emergent Torsion — Attachment Point Geometry

The attachment point of line j on a RingNode (centre `pos_ring`, twist angle `α`,
ring radius `R`, shaft-perpendicular basis `perp1`, `perp2`):

```
φⱼ          = α + (j−1) × 2π/5
r_attach_j  = R × (cos(φⱼ)×perp1 + sin(φⱼ)×perp2)
attach_pos  = pos_ring + r_attach_j
```

The sub-segment tension at that attachment point contributes to the ring node:

```
linear force on ring    += tension_vec
torque on ring (shaft)  += dot(r_attach_j × tension_vec,  shaft_dir)
```

Summed over all 5 lines on both faces of each segment.

**`compute_tensegrity_torque()` and the `C_T` torsional damping term are entirely
removed.** Torsional stiffness, torque transmission, and damping all emerge from
attachment-point geometry and sub-segment structural damping.

### Aerodynamic Drag on Rope Nodes

Each rope node represents length `L₀_sub` of tether:

```
v_rel        = wind_func(pos_node, t) − vel_node
seg_dir      = unit vector along local sub-segment
v_rel_perp   = v_rel − dot(v_rel, seg_dir) × seg_dir
drag_force   = 0.5 × ρ × Cd_cyl × d × L₀_sub × ‖v_rel_perp‖ × v_rel_perp
```

`Cd_cyl ≈ 1.0` (circular cross-section cylinder).

### Unchanged Forces

| Force | Applied to |
|---|---|
| Gravity `m × [0,0,−9.81]` | All nodes |
| Rotor thrust (BEM CT) | Hub RingNode |
| Rotor aero torque (BEM CP) | Hub RingNode |
| Kite lift + drag | Hub RingNode |
| Generator MPPT torque | Ground RingNode |

### Structural Safety Indicator (not simulated)

Ring hoop compression computed post-process per frame:

```
F_radial_total = Σⱼ tension_j × sin(γⱼ)      (inward radial components)
F_hoop         = F_radial_total / (2π)
P_crit         = π²EI / (2πR)²                (Euler buckling)
utilisation    = F_hoop / P_crit
```

Displayed in HUD as FoS. Does not affect dynamics.

---

## Failure Mode Coverage

| Failure mode | Coverage | Mechanism |
|---|---|---|
| Shaft overtwist / torsional collapse | ✓ Emergent | Lines go slack via `max(0,...)` |
| Line slack in low wind / ground handling | ✓ Emergent | Individual line tensile clamp |
| Load wave propagation / snap loads | ✓ Physical | Sub-nodes carry wave dynamics |
| Ring hoop compression | ✓ Computed | Post-process FoS in HUD |
| Ring buckling deformation | ✗ Deferred | Point-mass limitation |
| Ring buckling safety threshold | ✓ Flagged | FoS displayed |
| Individual line severance | ✗ Deferred | Add `broken::Bool` per sub-segment later |
| Lift kite tether rope physics | ✗ Deferred | Direct applied force for now |

---

## Package Structure

```
KiteTurbineDynamics.jl/
├── src/
│   ├── KiteTurbineDynamics.jl   ← package entry, exports
│   ├── types.jl                 ← RingNode, RopeNode, KiteTurbineSystem
│   ├── parameters.jl            ← SystemParams, params_10kw(), params_50kw()
│   ├── aerodynamics.jl          ← cp_at_tsr(), ct_at_tsr()         [ported]
│   ├── wind_profile.jl          ← wind shear model                 [ported]
│   ├── geometry.jl              ← attachment points, helix basis, shaft_dir
│   ├── initialization.jl        ← unified node list + static equilibrium pre-solve
│   ├── rope_forces.jl           ← sub-segment spring / damper / drag
│   ├── ring_forces.jl           ← rotor aero, kite aero, generator torque
│   ├── dynamics.jl              ← multibody_ode! (unified state vector)
│   └── visualization.jl         ← GLMakie dashboard
├── scripts/
│   ├── interactive_dashboard.jl
│   ├── power_curve.jl
│   └── record_simulation.jl
├── test/
│   ├── runtests.jl
│   ├── test_types.jl              ← node count, state size, ring_idx mapping
│   ├── test_geometry.jl           ← attachment points, perp basis, helix
│   ├── test_static_equilibrium.jl ← zero-wind: rings sag, rope nodes droop
│   ├── test_emergent_torsion.jl   ← applied twist → correct direction torque
│   ├── test_rope_sag.jl           ← low-tension: rope nodes sag toward ground
│   └── test_power.jl              ← rated wind → expected power output
├── docs/
│   └── plans/
├── Project.toml
└── README.md
```

**Ported unchanged:** `aerodynamics.jl`, `wind_profile.jl`
**Ported and adapted:** `parameters.jl`, `visualization.jl`
**Entirely new:** `types.jl`, `geometry.jl`, `initialization.jl`, `rope_forces.jl`,
`ring_forces.jl`, `dynamics.jl`
**Deleted:** `collapse_physics.jl`, `multibody_structural.jl` (emergent physics
replaces analytical collapse detection)

---

## Initialisation Strategy

1. **Place RingNodes** along shaft axis at static equilibrium — chain integration from
   hub downward computing axial tension per segment (same method as current
   `multibody_initialization.jl`)

2. **Place RopeNodes** linearly interpolated along straight line from attachment point A
   to attachment point B at `sub_idx / 4` fraction

3. **Pre-solve for geometric settling** — run ODE at zero wind, zero rotation, with
   high damping for ~5 s at loose tolerance (`abstol=1e-2, reltol=1e-2`). Rope nodes
   settle under gravity to true sag positions before the main simulation begins.
   Prevents violent transient from straight-line initial placement.

---

## Solver Strategy

QNDF (implicit, A-stable) handles the 4× stiffness increase from shorter sub-segments
without requiring a smaller timestep — stiffness is what implicit solvers are designed
for. Impact is more Jacobian evaluations per step, not smaller steps.

```julia
solve(prob, QNDF(autodiff=false),
      saveat=0.2, maxiters=10_000_000,
      abstol=1e-3, reltol=1e-3)
```

Slightly looser tolerance than TRPTKiteTurbineJulia2 (`1e-4`) for first runs.
Tighten after profiling.

---

## Migration from TRPTKiteTurbineJulia2

`TRPTKiteTurbineJulia2` is **preserved unchanged** as a reference implementation.
`KiteTurbineDynamics.jl` is a new package at a new path — no shared code modified.

| Component | Action |
|---|---|
| `aerodynamics.jl` | Copy verbatim |
| `wind_profile.jl` | Copy verbatim |
| `parameters.jl` | Port — same `SystemParams`, same `params_10kw()`/`params_50kw()` |
| `visualization.jl` | Port and extend — GLMakie structure preserved, geometry extraction updated for rope nodes |
| All other src files | Rewrite from scratch |
| Test suite | New suite — old tests test old state vector layout |

---

## Open Source Notes

- MIT licence
- README to include: system diagram, install instructions, basic usage example,
  link to Windswept & Interesting Ltd
- Compatible with `VortexStepMethod.jl`, `WinchControllers.jl`, `AtmosphericModels.jl`
  from the OpenSourceAWE collection
