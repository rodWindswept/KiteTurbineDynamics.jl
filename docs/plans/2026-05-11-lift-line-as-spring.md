# Lift line as a real spring to a lifter point

**Status:** ready to execute
**Owner:** next session
**Gate:** `test/test_bearing_alignment.jl` (already in `runtests.jl`)
**Pass condition:** all five `@test` checks green, including `F_horiz < 50` and `abs(F_z) < 50`.

## Why

The dashboard "snap" on frame 1 + the slow re-equilibration over the first
~12 s of every run trace to one root cause: the lift line in
`ring_forces.jl:123‑149` is a **fixed-direction force vector** at the
bearing, not a tension to a point. Direction is `cos(elev_lift)·downwind +
sin(elev_lift)·ẑ` (~80° elevation), which never aligns with the 30° TRPT
shaft.

Empirical evidence from the regression test (`test/test_bearing_alignment.jl`)
after `settle_to_operational_state`:

| Quantity | Value |
|---|---|
| Bearing perpendicular distance from shaft axis | 0.06 m (on-axis ✓) |
| Bridle length spread | 0.54 % (equal ✓) |
| Bridle strain | 0.28 % max (relaxed ✓) |
| **Net horizontal force on bearing** | **890 N** (fail) |
| **Net vertical force on bearing** | **+834 N** (fail) |

Decomposed onto the shaft basis (shaft_dir ≈ [0.866, 0, 0.5]):
- Along shaft: −353 N
- Perpendicular (toward zenith): +1166 N

The +1166 N perp force is the lift line trying to drag the bearing up at
80° elevation. The operational settle's `damp_op = 0.05` masks it by
killing 95 % of bearing velocity per step, so the bearing barely moves and
is reported as "settled" while still grossly out of force balance. On
frame 1 the integrator releases the constraint and the bearing accelerates
at 4093 m/s² toward its true (off-axis) equilibrium. Visible "snap"
follows.

Geometric constraint: equal bridle lengths require the bearing to be on
the shaft axis (locus of equidistant points from N symmetric ring
vertices is the shaft axis itself). The only way to satisfy force balance
**and** equal bridle lengths is to make the lift line pull along the
shaft. That requires the lifter to sit at a position the bearing can pull
toward — i.e., the lift line must be a real spring to a real point, not
a vector with a fixed direction.

## Approach

Introduce a **lifter anchor point** above the hub along the design shaft.
Replace the fixed-direction lift force with a spring force pointing from
bearing to anchor. The anchor is a fixed world-frame point, not a
simulated node — it doesn't have its own dynamics. This keeps the change
local while giving the bearing a force vector that always points roughly
along the shaft (= along the equal-bridle-length axis).

Approximation: the lifter floats at fixed `(elev_lift, downwind)` in
absolute world coordinates set at build time, NOT relative to the moving
bearing. Real lifters do bob, but at the timescales of TRPT settling
(~ms) the lifter's own attitude can be treated as quasi-static. This is
strictly more correct than the current model (which treats the line as a
direction-locked force vector regardless of bearing position).

### Force model

```
P_lifter = ring_pos[end] + L_lift_line × lifter_dir_design
lifter_dir_design = cos(elev_lift)·downwind_design + sin(elev_lift)·ẑ

# in ring_forces.jl, replacing lines 123–149:
line_vec  = P_lifter - bearing_pos
line_len  = norm(line_vec)
if line_len > 1e-6
    line_dir = line_vec ./ line_len
    T_lift, _, _ = lift_force_steady(lift_device, p.rho, v_hmag)  # magnitude only
    # passive-kite stall floor still applies
    if T_lift > 0.0
        forces[bearing_gid] .+= T_lift .* line_dir
    end
end
```

Note: `T_lift` magnitude still comes from `lift_force_steady` based on
wind. Direction now comes from the line geometry.

### Resulting equilibrium

With lifter anchored along the design shaft above the hub:
- Lift line direction ≈ +shaft_dir (since bearing sits below anchor along
  the shaft).
- Bridle force on bearing (when bridles symmetric) is along −shaft_dir.
- Along shaft: lift cancels bridles. Equilibrium tension in bridles
  ≈ T_lift / N_bridles per bridle.
- Perpendicular to shaft: only gravity contributes a small perp
  component (m·g·cos(elevation_angle) ≈ 2.5 N). Bearing displaces by
  ~10 mm in the perp-down direction so bridles develop a tiny tilt to
  oppose. Well within the 0.5 m perp tolerance.

This means the test passes as designed: bearing on-axis, bridles equal,
forces balanced.

## Files & exact changes

### 1. `src/types.jl`

Add the lifter anchor field to `KiteTurbineSystem` so it's available
inside `ring_forces.jl` without re-deriving each step. Place after
`bearing_id`:

```julia
struct KiteTurbineSystem
    nodes          :: Vector{AbstractNode}
    sub_segs       :: Vector{RopeSubSegment}
    ring_ids       :: Vector{Int}
    rotor          :: RotorSpec
    kite           :: KiteSpec
    bearing_id     :: Int
    lifter_anchor  :: Vector{Float64}     # NEW: world-frame anchor for lift line
    n_ring         :: Int
    n_total        :: Int
    ring_tilt_axis :: Vector{Vector{Float64}}
end
```

### 2. `src/initialization.jl`

In `build_kite_turbine_system` (and `build_kite_turbine_system_v5`),
after `bearing_pos0` is computed (~line 143):

```julia
# Lifter anchor: world-frame point the lift line tensions toward.
# Placed above the design hub along the design shaft, offset by line_length.
# The line direction from bearing to anchor approximately equals shaft_dir
# at frame 0, giving an on-axis bearing equilibrium.
LIFT_LINE_LENGTH = 25.0       # m — matches RotaryLifterParams.line_length default
lifter_anchor = ring_pos[end] .+ (bearing_offset + LIFT_LINE_LENGTH) .* shaft_dir
```

Pass `lifter_anchor` to the `KiteTurbineSystem` constructor.

The bearing initial position stays at `ring_pos[end] + 6 × shaft_dir`
(unchanged) — this IS the equilibrium with the new force model.

### 3. `src/ring_forces.jl`

Replace lines 123–149 (the lift line block) with the spring formulation
above. Key points:

- Use `sys.lifter_anchor` (not a recomputed value).
- Keep the passive-kite stall floor (`PASSIVE_KITE_STALL_SPEED`).
- Keep `T_lift` magnitude via `lift_force_steady`.
- Drop `θ_lift = deg2rad(elev_lift)` and the `cos·downwind + sin·ẑ`
  decomposition entirely.

The backline block (lines 151–192) stays unchanged — it already terminates
at a real ground anchor.

### 4. `src/initialization.jl` (operational settle)

The aggressive `damp_op = 0.05` was a workaround for the off-axis
imbalance. With the lift line now spring-based, the bearing should
already be near equilibrium at frame 0. Loosen the damp:

```julia
damp_op = 0.99    # was 0.05 — let bearing actually settle, not freeze it
n_op    = 8_000   # was 4_000 — more time to find equilibrium
```

This change is independent of the force-model fix but should be made in
the same pass since the test will catch any regression.

### 5. `src/visualization.jl`

Render the lift line and lifter point. Add to the dashboard scene
construction (search for where bridles are rendered; add adjacent):

```julia
# Lift line: bearing → lifter anchor (cyan)
lift_line_pts = lift(state) do u
    bp = u[3*(sys.bearing_id-1)+1 : 3*sys.bearing_id]
    Point3f[Point3f(bp...), Point3f(sys.lifter_anchor...)]
end
lines!(ax, lift_line_pts; color = :cyan, linewidth = 2)

# Lifter anchor marker
scatter!(ax, [Point3f(sys.lifter_anchor...)];
         color = :cyan, markersize = 12, marker = :circle)
```

This sets up the rendering for a future kite/lifter representation.

### 6. `test/test_bearing_alignment.jl`

No changes. The existing test is the gate.

## Sequence of work

1. Edit `types.jl` — add `lifter_anchor` field
2. Edit `initialization.jl` — populate `lifter_anchor`, pass to constructor
3. Edit `initialization.jl` — also for `build_kite_turbine_system_v5`
4. Edit `ring_forces.jl` — replace lift line block with spring
5. Edit `initialization.jl` — relax `damp_op` and `n_op`
6. `julia --project=. -e 'using Pkg; Pkg.test()'` — verify green
7. Edit `visualization.jl` — add lift line + anchor render
8. Manual dashboard check — `julia --project=. scripts/interactive_dashboard.jl`
   - confirm cyan line from bearing to lifter point at frame 0
   - confirm no snap at frame 1
   - run furl 10s, steady 10s, default 30s — all should look smooth

## Risks & mitigations

- **Risk:** `build_kite_turbine_system_v5` constructor signature drifts
  from canonical. Mitigation: edit both call sites in the same commit;
  the test suite has v5 coverage in `test_trpt_axial_profiles.jl`.
- **Risk:** Furl scenario relies on bearing lift dropping. With spring
  model, T_lift magnitude still comes from wind speed, so furl behaviour
  is unchanged. But: as bearing rises, it gets closer to the anchor; if
  it passes the anchor, the line goes slack. Mitigation: add a `line_len
  < L0_lift` slack check (currently treats line as always-tensioned).
  Defer if the test suite passes — handle when furl regresses.
- **Risk:** `lifter_anchor` is a fixed point, but the design hub
  position depends on `elevation_angle`. If the user changes `p.elevation_angle`
  between scenarios, the anchor doesn't follow. Mitigation: anchor is
  recomputed every time `build_kite_turbine_system` is called (which
  happens on every config change in the dashboard), so this is fine.

## Out of scope (future work)

- Modeling the lifter as a true node with mass/lift/drag (real bobbing
  dynamics).
- Showing a kite or rotor mesh at the anchor.
- Backline payout coupling to bearing rise.
- Lift line slack physics during furl.
