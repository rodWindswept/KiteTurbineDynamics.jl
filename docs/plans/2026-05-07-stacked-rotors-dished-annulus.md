# Stacked Rotors + Dished Annulus — Implementation Plan

**Date:** 2026-05-07
**Status:** Design phase

## Motivation

Field tests with physical prototypes showed two promising structural-aerodynamic
mechanisms not yet captured in the simulator:

1. **Stacked rotors** — multiple rotor discs distributed along the TRPT shaft.
   Observed to improve efficiency, likely because each rotor sees cleaner inflow
   and line drag is amortised across more power-producing discs.

2. **Dished rotor annulus** — blades angled so outer tips sit lower on the TRPT
   than the root (root closer to lift hub, tips further down the shaft axis).
   This geometry converts blade lift into an outward radial force component that
   helps hold the rings open, counteracting the inward buckling load from tether
   line tension. Centripetal acceleration of the blade mass reinforces this effect.

## 1. Data Model Changes

### 1.1 Multiple Rotors

Current `SystemParams` has a single rotor:
```julia
n_blades::Int     # number of blades (one set)
m_blade::Float64  # mass per blade
rotor_radius::Float64
```

New multi-rotor design:
```julia
n_rotors::Int                    # number of rotor discs (default 1)
rotor_ring_indices::Vector{Int}  # which TRPT ring each rotor attaches to
rotor_radii::Vector{Float64}     # radius per rotor (can vary)
m_blade::Float64                 # mass per blade (same for all rotors)
n_blades::Int                    # blades per rotor (same for all)
```

The hub ring (topmost) always carries one rotor. Additional rotors attach to
rings further down the shaft — typically the top 3-5 rings for a 3-rotor stack.

**Rule of thumb from field tests:** Rotors spaced ~3-5m apart axially (2-3 ring
intervals on the 30m TRPT). This gives each rotor clean inflow without the
downstream rotor sitting in the wake of the upstream one.

### 1.2 Dished Annulus

New `SystemParams` fields:
```julia
cone_angle::Float64  # blade dish angle (rad). 0 = flat disc, positive = tips lower
```

At cone_angle = 0 (current behaviour), blades lie in the ring plane.
At cone_angle = 10°, blade tips are `span × sin(10°)` lower on the z-axis.

The cone angle applies to ALL rotors (same dish for all discs).

### 1.3 `RotorSpec` Changes

Current:
```julia
struct RotorSpec
    node_id::Int     # ring global ID where rotor attaches
    radius::Float64
    mass::Float64
    inertia_z::Float64
end
```

Extended:
```julia
struct RotorSpec
    node_id::Int
    radius::Float64
    mass::Float64
    inertia_z::Float64
    cone_angle::Float64    # NEW: dish angle (rad)
    ring_offset::Int       # NEW: which ring index (1 = hub, 2 = next down, etc.)
end
```

`KiteTurbineSystem` changes from single `rotor::RotorSpec` to `rotors::Vector{RotorSpec}`.

## 2. Physics Changes

### 2.1 Multi-Rotor Aerodynamics

Each rotor contributes independently. Total aerodynamic power:

```
P_total = Σᵢ 0.5·ρ·Vᵢ³ · π·Rᵢ² · Cp(λᵢ) · cos³(β)
τ_total = Σᵢ Pᵢ / ωᵢ
```

Where:
- `Vᵢ` = wind speed at rotor i's altitude (shear profile applied per rotor)
- `Rᵢ` = radius of rotor i
- `λᵢ` = TSR at rotor i = ω_hub × Rᵢ / Vᵢ
- `β` = shaft elevation (same for all rotors on the same TRPT)

**Key simplification for v1:** All rotors share the same ω (they're on the same
shaft). TSR differs only due to different radii and altitudes.

**Wake interaction (deferred):** For v1, assume no wake interaction between
stacked rotors. A simple axial induction model (Glauert) can be added in v2.

### 2.2 Thrust Distribution

Each rotor produces thrust at its attachment ring:

```
Tᵢ = 0.5·ρ·Vᵢ² · π·Rᵢ² · CT(λᵢ) · cos²(β)
```

This thrust is applied as an axial force at the rotor's ring node. The TRPT
segments ABOVE each rotor only carry the thrust from rotors above them. The
ground-end segment carries the sum of ALL rotor thrusts.

### 2.3 Dished Annulus — Radial Force

For a blade at cone angle γ, the aerodynamic force vector tilts:

```
F_blade = F_lift · [cos(γ), 0, -sin(γ)]  (in blade-local coordinates)
```

The radial component `F_lift × sin(γ)` pushes OUTWARD on the ring vertex,
counteracting the inward force from tether line tension. This is structurally
beneficial for Euler buckling — it reduces the net compressive load on the
polygon ring beams.

At γ = 10°: radial component ≈ 17% of blade lift. For a blade producing ~500N
of lift, that's ~87N of outward radial force per vertex.

### 2.4 Centripetal Relief

Blade mass m_blade at radius r spinning at ω experiences outward centrifugal
force:

```
F_centripetal = m_blade × ω² × r
```

At the hub ring (r ≈ 1.6m, ω ≈ 10 rad/s, m_blade ≈ 1.4 kg):
F_cp ≈ 1.4 × 100 × 1.6 ≈ 224 N per blade.

This outward force is already partially modeled in the optimizer
(`m_blade_per_vertex × ω² × r` subtracted from inward line force) but is NOT
currently applied in the ODE dynamics. Adding it to the ODE would make the
simulation more physically accurate.

### 2.5 TRPT Torque Accumulation

With multiple rotors, torque accumulates along the shaft. The TRPT segment
between rotor i and rotor i+1 carries the torque from all rotors above i+1.
The ground-end segment carries the total torque from all rotors.

This makes the torsional collapse constraint MORE demanding for multi-rotor
configurations — the ground-end segments see higher cumulative torque. The
v5-safe design (nearly cylindrical, r_bottom ≈ 1.5m) should handle this well.

## 3. Visualization Changes

### 3.1 Multi-Rotor Rendering

Current code renders one set of blades at the hub ring:
```julia
for b in 1:p.n_blades
    blade_obs = @lift begin ... end
    lines!(ax3d, ...; color=:steelblue, linewidth=2.5)
end
```

Extended: loop over `sys.rotors`, render blades at each rotor's attachment ring:
```julia
for (ri, rotor) in enumerate(sys.rotors)
    ring_gid = sys.ring_ids[rotor.ring_offset]
    for b in 1:p.n_blades
        # ... render blade at this ring ...
        lines!(ax3d, ...; color=ri == 1 ? :steelblue : :cornflowerblue, linewidth=2.0 + ri*0.3)
    end
end
```

Colour coding: hub rotor = steelblue (darkest), lower rotors progressively
lighter blue.

### 3.2 Dished Annulus Rendering

Current blade is a flat quadrilateral:
```
p1 = ctr + r_inner × r_dir - hc × c_dir
p2 = ctr + r_outer × r_dir - hc × c_dir
p3 = ctr + r_outer × r_dir + hc × c_dir
p4 = ctr + r_inner × r_dir + hc × c_dir
```

Dished: add z-offset to outer points:
```
z_offset = cone_angle > 0 ? -(r_outer - r_inner) × tan(cone_angle) : 0.0
p2.z += z_offset; p3.z += z_offset
```

This creates a visible "bowl" shape. The cone depth at r_outer=5m, γ=10°:
```
z_offset = -(5.0 - 2.0) × tan(10°) ≈ -0.53 m
```

### 3.3 Controls

New Controls section "── Rotor Stack ──":
- Slider: Number of rotors (1–5)
- Slider: Rotor spacing (2–5m axial)
- Checkbox: Dished annulus (enables cone angle slider)
- Slider: Cone angle (0–20°)

Defaults: 1 rotor, flat (cone_angle = 0) — backwards compatible.

## 4. Dashboard Integration

### 4.1 New Configuration Option

"Multi-rotor" could be a separate configuration or a parameter on existing
configs. Recommended: add as parameters on all three existing configs
(canonical, v5, v5-safe), defaulting to 1 rotor / flat.

### 4.2 HUD Additions

New HUD section "── Rotors ──":
```
Rotor 1 (hub):  P = XX.X kW  τ = XXX Nm
Rotor 2:        P = XX.X kW  τ = XXX Nm
...
Total:          P = XX.X kW  τ = XXX Nm
```

### 4.3 Power Curve

Multi-rotor power curve P(v) would show:
- Individual rotor contributions
- Total system power
- Efficiency gain vs single rotor of equivalent total area

## 5. Implementation Phases

### Phase A: Multi-Rotor Data Model (2–3 hours)
1. Extend `SystemParams` with `n_rotors`, `rotor_ring_indices`, `rotor_radii`
2. Change `RotorSpec` to include `cone_angle`, `ring_offset`
3. Change `KiteTurbineSystem.rotor` to `KiteTurbineSystem.rotors::Vector{RotorSpec}`
4. Update `params_10kw()` to produce 1-rotor default (backwards compatible)
5. Add `params_multi_rotor_10kw(n=3)` for stacked configuration
6. Update `build_kite_turbine_system()` to create multiple RotorSpecs
7. Update `state_size()` for multi-rotor
8. Run existing test suite — should pass with 1-rotor default

### Phase B: Multi-Rotor Physics (3–4 hours)
1. Modify `compute_ring_forces!` to iterate over all rotors
2. Apply thrust and torque at each rotor's attachment ring
3. Scale generator MPPT to handle total torque
4. Add per-rotor power tracking
5. Verify torque accumulation along TRPT segments

### Phase C: Dished Annulus Physics (2–3 hours)
1. Add `cone_angle` to SystemParams
2. Modify blade force computation in `ring_forces.jl`:
   - Radial component from cone angle
   - Centripetal force from blade mass
3. Update ring force balance to include outward radial forces
4. Verify ring utilisation (Euler FOS) improves with cone angle

### Phase D: Visualization (3–4 hours)
1. Multi-rotor rendering in `build_dashboard`
2. Dished annulus blade geometry
3. Rotor stack HUD panel
4. Controls for rotor count, spacing, cone angle

### Phase E: Testing & Tuning (2–3 hours)
1. Single-rotor comparison: new code matches old results
2. 3-rotor stack at rated wind: verify power and torque
3. Dished annulus: verify ring FOS improvement
4. Edge cases: max rotors (5), extreme cone angle (20°)
5. Performance: ensure simulation speed stays acceptable

## 6. Total Estimated Effort

| Phase | Hours |
|---|---|
| A — Data model | 2–3 |
| B — Multi-rotor physics | 3–4 |
| C — Dished annulus physics | 2–3 |
| D — Visualization | 3–4 |
| E — Testing | 2–3 |
| **Total** | **12–17 hours** |

## 7. Open Questions

1. **Rotor radii:** Do all stacked rotors have the same radius, or do they taper?
   Field tests used same-radius rotors. Tapering might match the TRPT taper.

2. **Blade count per rotor:** Same n_blades for all? Or can downstream rotors
   have fewer blades (less solidity needed since upstream rotor extracts energy)?

3. **Cone angle per rotor:** Same dish for all? Or does the dish increase for
   lower rotors (more structural benefit where buckling risk is higher)?

4. **Wake model:** How much does an upstream rotor reduce wind speed at the
   downstream rotor? Simple axial induction: V_downstream = V × (1 - a) where
   a ≈ 1/3. This reduces downstream rotor power by ~30%.

5. **TRPT sizing for multi-rotor:** The v5-safe design (18 kg) was optimized for
   single-rotor. Multi-rotor increases total torque and thrust — may need
   re-optimization with multi-rotor loads.

## 8. Quick-Start Agent Prompt

```
TASK: Implement Phase A — Multi-Rotor Data Model in KiteTurbineDynamics.jl

REPO: ~/Documents/GitHub/KiteTurbineDynamics.jl/
FILES TO MODIFY:
  - src/types.jl: RotorSpec — add cone_angle, ring_offset fields
  - src/parameters.jl: SystemParams — add n_rotors, rotor_ring_indices, 
    rotor_radii, cone_angle; update params_10kw() for 1-rotor default
  - src/initialization.jl: build_kite_turbine_system — create 
    Vector{RotorSpec} instead of single RotorSpec
  - src/KiteTurbineDynamics.jl: update exports

CONSTRAINTS:
- Single-rotor (n_rotors=1) must produce IDENTICAL results to current code
- All existing tests must pass
- Backwards compatible: params_10kw() still returns a working 1-rotor config
- cone_angle defaults to 0.0 (flat disc)

VERIFICATION:
  julia --project=. -e 'using Pkg; Pkg.test()'
  julia --project=. scripts/interactive_dashboard.jl --headless --wind 11 --duration 1
```
