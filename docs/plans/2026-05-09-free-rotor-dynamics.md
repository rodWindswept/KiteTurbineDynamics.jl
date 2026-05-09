# Free-Rotor Dynamics: Emergent Disc Orientation via Tension Network

**Date:** 2026-05-09
**Status:** Plan
**Author:** Hermes + Rod Read

## Problem

The rotor disc (top ring with kite blades) is currently locked to the shaft
elevation axis. Its orientation does not emerge from the tension network — it
is imposed by four artificial constraints:

| Constraint | Location | What should happen instead |
|---|---|---|
| Lift force applied to hub centre | `ring_forces.jl:147-150` | Lift pulls on bearing; bridle lines distribute to hub vertices |
| Thrust projected along tether direction | `ring_forces.jl:56-59` | Thrust acts along disc normal, not hub→ground vector |
| Wind incidence uses hub position angle | `ring_forces.jl:45,54` | Incidence is angle between disc normal and wind direction |
| Bridle lines are visual-only | `visualization.jl:334-345` | Bridle lines are spring-dampers in the ODE |

Consequence: furl operation (backline payout → bearing rises → rotor should
tilt and spill wind) has no effect on disc orientation. The hub position changes
but the code assumes the disc tilts with it, which it doesn't physically.

## Design principle

The disc orientation should **emerge from the tension network**, the same way
torsional coupling emerges from rope attachment geometry. No analytical pitch
formula. No explicit tilt state variable. The bearing is a free particle; bridle
lines are springs; the hub vertices find equilibrium under the combined forces
of lift, backline, rotor thrust, and TRPT tension.

## Geometry

```
                    Lift kite / rotary lifter
                         |
                    lift line (tension, existing LiftDevice model)
                         |
              ┌─── bearing point ───┐
              │  NEW: free particle │
              │  3 pos + 3 vel DOF  │
              └──┬──┬──┬──┬──┬──┬──┘
            bridle lines (NEW: N springs)
            bearing → hub ring vertices
                 |  |  |  |  |  |
        ╔════ hub ring vertices (existing RingNodes) ════╗
        ║              blades attached                    ║
        ╚═════════════════╤═══════════════════════════════╝
                          |
                 TRPT tether lines (existing)
                          |
                    intermediate rings
                          |
                     ground ring
```

## Phase 1: Bearing particle + bridle springs

### Objective
Add the bearing as a free particle connected to hub vertices by spring-damper
sub-segments. The rotor ring now feels lift/backline forces distributed through
its vertices, not as a single vector at the centre.

### State changes

| What | Was | Now |
|---|---|---|
| Nodes | 241 (canonical) | 242 (+bearing) |
| ODE states | 1478 | 1484 (+6) |
| Sub-segments | 300 | 300 + N_lines (bridle segments) |

### New types

```julia
# New node type for the bearing
struct BearingNode <: AbstractNode
    id   :: Int
    mass :: Float64  # bearing mass (~0.05 kg)
end
```

### Code changes

**`src/types.jl`:**
- Add `BearingNode <: AbstractNode`

**`src/initialization.jl` (`build_kite_turbine_system` family):**
- Place bearing at `hub_centre + bearing_offset * shaft_dir` initially
- Add N bridle `RopeSubSegment`s (bearing → each hub vertex)
- Bearing mass ~0.05 kg; bridle EA = lift_line EA / N
- Bridle natural length = distance from bearing to attachment point at design geometry

**`src/rope_forces.jl`:**
- Bridle segments are standard spring-dampers — no code changes needed
  (they're just more entries in `sys.sub_segs`)

**`src/ring_forces.jl`:**
- Lift force (`T_lift` vector): apply to bearing node, not hub centre
- Back line force: apply to bearing node (attachment is ~10 cm above bearing)
- Remove the direct `forces[hub_gid] .+= T_lift ...` block
- Keep generator torque on ground ring (unchanged)
- Keep inter-ring torsional damping (unchanged)

**`src/dynamics.jl` (`multibody_ode!`):**
- Bearing node is a standard free particle: `F/m` same as RingNode (non-fixed)
- No special treatment needed — it's just another AbstractNode

**`src/structural_safety.jl` (`ring_safety_frame`):**
- Now sees hub vertices under real bridle tension, not a lumped centre force
- Should give more accurate FoS at the hub ring

### Expected behaviour after Phase 1

- At design conditions: bearing sits where it was before; hub vertices under
  distributed tension; disc normal ≈ shaft axis (emergent, not imposed)
- During furl (backline payout): bearing rises → bridle lines' angles shift →
  hub vertices find new equilibrium → disc normal tilts away from wind

### Tests

- Bearing particle starts at design position, stays there in steady wind
- Bridle tension sums to lift force (equilibrium check)
- Hub centre experiences zero net force from lift/backline system
  (all forces go through vertices)
- Static: bearing position predictable from lift + backline + bridle geometry

## Phase 2: Ring-plane orientation for disc tilt

### Architecture decision (2026-05-09)

RingNodes are currently **point masses** with twist angle — 3 translational DOF
+ 1 rotational DOF (about shaft axis only). The ring plane is locked to the
shaft-perpendicular basis `perp1, perp2` from `shaft_perp_basis(shaft_dir)`.
All N line forces sum at the single ring centre. Asymmetric bridle tension
produces only twist torque, not ring-plane tilt.

For Phase 2 (disc normal + furl power spill), the rotor disc needs to tilt
under asymmetric bridle forces. Three options evaluated:

#### Option A: Individual vertex nodes (Rod's preference)

Hub ring vertices become **N separate free particles** connected by rigid
beam segments (spring-dampers). Each vertex feels its own bridle tension
directly — no lumping to centre. The polygon can deform and tilt naturally
under the tension network. TRPT tethers attach to individual vertices,
not a lumped centre.

- **Accuracy**: Highest — matches physical reality. Each vertex is a
  physical knuckle connector. Forces propagate through the polygon beam
  network, not an abstract centre.
- **DOF cost**: +N×6 (vertex particles) + 2×(N-1)×6 (beam segment
  constraints or stiff springs). Canonical 5-line: ~+30 DOF for vertices
  + ~48 DOF for beam constraints ≈ +78 DOF (1562 total). Manageable.
- **Complexity**: Medium — beam segments are standard spring-dampers
  (already have the infrastructure). Polygon closure constraint needed.
- **Emergent behaviour**: Ring normal, buckling FoS, and vertex forces
  all emerge naturally — no analytical formulas needed.

#### Option B: Ring-plane normal state

Add 2 DOF (pitch + yaw) to RingNode for ring-plane orientation. Compute
net torque from force asymmetry: `Σ(r_j × F_j)` with perpendicular
components applied to the orientation state. Disc normal = rotated shaft
perpendicular.

- **Accuracy**: Medium — captures tilt but not vertex-level force distribution
  or polygon deformation. All vertices move as a rigid plane, not individually.
- **DOF cost**: +2 DOF per ring (only needed for hub ring initially).
  Negligible (1486 states for canonical).
- **Complexity**: Low — straightforward torque computation, small state
  addition. But loses vertex-level fidelity.

#### Option C: Point-mass translation only

No new state. Compute net perpendicular force from bridle asymmetry, apply
as translational force on hub centre. Disc normal derived from hub centre
position + bridle geometry.

- **Accuracy**: Lowest — the ring can drift off-axis but can't tilt.
  Physically incorrect for furl (rotor tilts, not just translates).
- **DOF cost**: 0.
- **Verdict**: Rejected. Doesn't capture the physics.

**Decision**: Proceed with Option A for the hub ring. Intermediate TRPT
rings can remain as point masses (their tilt is constrained by the TRPT
tension network — they can't tilt independently). The hub ring alone
gets vertex particles + beam segments. This is the most physically
accurate path and Rod's stated preference.

### Objective
Compute rotor thrust and torque using the actual disc normal vector (derived
from hub ring vertices) rather than the shaft elevation axis. Add a simplified
aerodynamic restoring moment when the disc tilts relative to the wind.

### Disc normal computation

The hub ring vertices define a polygon in 3D. The disc normal is the unit
vector perpendicular to the best-fit plane through the N vertices.

```
n_disc = normalize(cross(v2-v1, v3-v1))  # for first 3 vertices
# Average over all vertex triples for robustness
```

### Thrust direction

```
thrust_vector = thrust_magnitude * n_disc
```

Applied to hub centre node (or distributed to hub vertices proportional to
their blade attachment positions).

### Wind incidence

```
cos_incidence = dot(n_disc, wind_direction)
```

Replaces `cos(elev_angle)` in the Cp/CT incidence corrections.
When the disc faces directly into the wind: `cos_incidence ≈ 1`.
When furl tilts the disc: `cos_incidence < 1` → power spills.

### Aerodynamic restoring moment

A tilted rotor experiences cyclic blade loading. The advancing blade sees
higher relative velocity and angle of attack; the retreating blade sees lower.
This creates a moment tending to restore the disc toward perpendicular to
the wind. For a physically-accurate first cut:

```
# Simplified gyroscopic + aerodynamic restoring moment
# Proportional to tilt angle for small tilts
tilt_angle = acos(abs(dot(n_disc, wind_direction)))
M_restore = k_restore * tilt_angle  # N·m/rad
```

Apply as a torque on the hub ring about an axis perpendicular to the tilt
plane (cross(n_disc, wind_direction)).

Calibration: run the multi-body ODE at progressively larger backline payout
and measure the tilt angle. Compare against:
- Blade element integration around the rotor azimuth
- Gyroscopic precession moment from the spinning rotor mass

Start with a small k_restore (1-10 N·m/rad) and tune against known behaviour.

### Code changes

**`src/ring_forces.jl`:**
- Compute `n_disc` from hub ring vertex positions each ODE step
- Use `n_disc` for thrust direction
- Use `dot(n_disc, wind_direction)` for Cp/CT incidence factors
- Add restoring moment term

**`src/geometry.jl`:**
- Add `disc_normal(vertices::Vector{Vector{Float64}})` helper

### Tests

- At design conditions: `n_disc ≈ shaft_dir` (within 1°)
- Furl: increasing backline_payout → |n_disc · shaft_dir| decreases
- Restoring moment opposes tilt direction (sign check)
- Power drops as `cos_incidence` decreases (furl working)

## Phase 3: Furl controller rewrite

### Objective
Replace the current ad-hoc furl implementation (pitch boost + winch payout
modifying backline rest length) with a simple winch controller that pays out
backline at a controlled rate and lets the physics handle everything else.

### Current furl flow (broken)
```
1. Modify backline_payout (increases rest length)
2. Boost lift device CL (up to 3×) to keep hub aloft
3. Hope the hub rises and wind incidence drops
```
Problem: the disc orientation doesn't change, so wind incidence doesn't drop.
The lift boost is a hack to prevent the hub from collapsing as the backline
goes slack.

### New furl flow (after Phases 1-2)
```
1. Winch pays out backline at controlled rate
2. Backline tension drops → bearing rises under lift
3. Bridle geometry shifts → disc normal tilts
4. cos_incidence drops → thrust drops → power spills
5. Generator MPPT law naturally reduces braking torque
6. Rotor slows, eventually stalls aerodynamically
```
No lift boost needed — the physics handles the transition.

### Code changes

**`src/visualization.jl` (`_rerun!` furl section):**
- Remove the lift device CL boost block entirely
- Keep backline_payout increment (winch model)
- Remove the `_modified_params` call for lift device modification

**`src/ring_forces.jl` (back line section):**
- Evaluate whether the single-spring backline model with catenary is sufficient
  for the full furl sequence, or whether multi-segment modelling is needed
  (see `docs/plans/2026-05-08-multi-segment-lift-backline.md`)

### Tests

- Furl from rated power to near-zero power in <10 seconds
- No NaN/Inf during transition
- Hub altitude change visible in dashboard
- Disc tilt angle visible (add to HUD or visual indicator)

## Risk areas

### Multi-segment backline stability
The explicit Euler integrator may go unstable with a multi-segment backline
model (high stiffness, short segments). This is already flagged as "numerically
unstable with explicit Euler" in memory. Options:
- Keep single-segment backline for Phase 1-2, upgrade when implicit integrator
  is available
- Use a quasi-static catenary as currently implemented

### Disc normal computation from 5-8 vertices
A polygon with 5 or 8 vertices in 3D may not be exactly planar under load.
The best-fit plane normal should be robust to small non-planarity.

### Aerodynamic moment calibration
The restoring moment coefficient is unknown without CFD or blade-element
integration. Start with a small value and treat it as a tuning parameter.
The physics is still correct — only the stiffness is approximate.

## Order of attack

1. Phase 1: Bearing particle + bridle springs (pure geometry, no aero changes)
2. Phase 2: Disc normal + restoring moment (changes aero, needs validation)
3. Phase 3: Furl controller rewrite (cleanup, should work automatically after 1-2)

Phases 1 and 2 can be tested independently. Phase 3 is blocked on 1-2 but should
be a simplification, not new complexity.

## References

- `CONTEXT.md` — domain vocabulary, system architecture
- `docs/plans/2026-05-08-multi-segment-lift-backline.md` — multi-segment
  backline modelling (deferred, but relevant to Phase 3)
- `src/rope_forces.jl` — emergent torsion from rope geometry (same design
  philosophy applied here)
- `src/ring_forces.jl:40-70` — current thrust/incidence code to replace
- `src/ring_forces.jl:117-151` — current lift force application to replace
- `src/ring_forces.jl:153-202` — current backline model
- `memory: Wind convention` — +X = DOWNWIND convention
