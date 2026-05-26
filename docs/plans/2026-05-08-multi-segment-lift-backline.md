# Multi-Segment Lift & Backline Model

## Problem

The lift line and backline are currently modeled as single spring-dampers with
prescribed force directions in `ring_forces.jl`.  This causes two failures:

1. **Lift line direction is wrong** — `lift_line_direction()` returns `[-cos(θ), 0, sin(θ)]`
   which pulls the hub UPWIND (-X).  A kite flies DOWNWIND of its tether point.
   The correct direction is `[+cos(θ), 0, sin(θ)]`.

2. **Furl breaks physics** — the backline stiffness is reduced to 5% (slack) while
   lift pitch is boosted 3×.  With no taut backline, the net force on the hub
   is uncontrolled.  The hub flies upwind through the TRPT rings.

The real system has heavy Dyneema lines with mass and aerodynamic drag.  Their
shape is a catenary, not a straight line.  The force at the hub EMERGES from
that catenary — it's not prescribed by a geometry assumption.

## Design

### Node types

Add a `LiftLineNode <: AbstractNode` for nodes on the lift line and backline.
These are identical to `RopeNode` but tagged so force computation can distinguish
them:

```julia
struct LiftLineNode <: AbstractNode
    id        :: Int
    mass      :: Float64
    line_type :: Symbol    # :lift or :back
    seg_idx   :: Int       # segment index (1-based, 1 = closest to hub)
    sub_idx   :: Int       # position within segment (1–N_sub)
end
```

### Construction

Extend `_build_kite_turbine_system_impl` to append lift and backline nodes
after the TRPT nodes:

- **Lift line**: N_sub sub-segments per segment, N_seg segments from hub to
  lift device position.  Parameters: `lift_line_length`, `lift_line_diameter`,
  `lift_line_n_segs`.  Default: 20 m, 4 mm Dyneema, 5 segments.

- **Backline**: Same treatment, from hub to ground back-anchor point.
  Default: ~32 m (from hub at β=30°, L=30m to anchor 5m downwind),
  3 mm Dyneema, 5 segments.

Node IDs continue from where TRPT construction left off.  State vector size
increases by `6 * (n_lift_nodes + n_back_nodes)`.

### Physics

Lift line and backline sub-segments use the same tension-only spring-damper
as TRPT ropes, plus gravity and aerodynamic drag (via `tether_drag_force`).
The key difference: their endpoints are NOT ring attachment points.

- **Lift line bottom**: attaches to the hub bearing (shares hub node position)
- **Lift line top**: the lift device aerodynamic force is applied here
- **Backline bottom**: fixed ground anchor point
- **Backline top**: attaches to the lift line 30 cm above the hub bearing

### Lift device force

Move from `ring_forces.jl` to the new force computation.  The lift device
aerodynamic force (from `lift_force_steady`) is applied to the TOP node of
the lift line.  The lift kite elevation angle is EMERGENT — it's the angle of
the top segment of the lift line after settling, not a prescribed parameter.

### Backline anchor

The backline ground anchor is a FIXED point in space (like the TRPT ground ring
but with no rotational DOF).  Position: `[tether_length·cos(β) + back_anchor_fwd_x, 0, 0]`.
The backline top attaches to the lift line 30 cm above the hub bearing.

### Changes to ring_forces.jl

Remove:
- Lift kite force block (lines 126–150) — now applied to lift line top node
- Backline spring-damper block (lines 152–184) — now multi-segment

### Wind function

The existing `wind_fn(pos, t)` closure already computes wind at any 3D position.
Lift line nodes call it directly — no change needed.

### Initial state and settling

1. Place lift line nodes in a straight line from hub position to an initial
   kite position (downwind of hub at lifter_elevation angle)
2. Place backline nodes in a straight line from hub to ground anchor
3. `settle_to_equilibrium` handles the new nodes automatically — it applies
   gravity and zero wind to all nodes
4. `settle_to_operational_state` only touches TRPT ring twist states — the
   lift/backline nodes just sag under gravity during settle

### Furl controller

After this change, the furl controller becomes much simpler:
- No need to modify `EA_back_line` or `c_back_line` — the backline stays taut
- Winch payout = increase `back_anchor_fwd_x` by 25 m over 5 s
- This changes the rest length of the backline sub-segments → the hub rises
- Pitch boost: 1× → 1.5× (modest, not 3×) to keep rotor elevated
- The line catenary handles the rest: hub rises, rotor pitches away from wind,
  power drops

## Implementation order

1. Fix `lift_line_direction` sign (1 line — immediate)
2. Add `LiftLineNode` type to `types.jl`
3. Extend `_build_kite_turbine_system_impl` with lift/backline nodes
4. Add lift/backline force computation (reuse TRPT rope spring-damper + drag)
5. Move lift device force to top of lift line
6. Remove hardcoded lift/backline from `ring_forces.jl`
7. Update `settle_to_operational_state` (should be transparent — only touches ring twist)
8. Update dashboard for new state vector size
9. Fix furl controller (simplify: just extend back_anchor_fwd_x)

## State vector layout (current → new)

```
Current: [pos(1:N), vel(1:N), α(1:Nr), ω(1:Nr)]      = 6N + 2Nr
                                                         = 1478 (canonical)

New:     [pos(1:N+NL+NB), vel(1:N+NL+NB), α(1:Nr), ω(1:Nr)]
                                                         = 6(N+NL+NB) + 2Nr
  NL = lift_line_n_segs × N_sub_per_seg
  NB = back_line_n_segs × N_sub_per_seg
```

Default: 5 segments × 4 sub-segments = 20 nodes each line = 40 new nodes.
State size increase: 6 × 40 = 240 states.  Total: 1478 + 240 = 1718 (canonical).
