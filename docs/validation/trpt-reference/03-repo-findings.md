# Repo claims that disagree with the printed source

Written 2026-09-26. Each entry gives the site in this repo, the printed source, and the
difference. "Open" means nobody has ruled on the fix. Do not change a search bound or a
physics constant without a ruling.

## F1. The over-twist angle is not the source limit

- Repo claim: the tether crossing limit is `δα* = 2·asin(L / root(2·(L² + 2r²)))`.
- Sites: `src/initialization.jl:1425`, `src/initialization.jl:1454`,
  `src/objective_evaluator.jl:313`, `src/objective_evaluator.jl:320`,
  `src/rope_forces.jl:582`.
- Source: equation (5.4) with (5.5) on printed page 198. The limit depends on `ϕ = l_t/R`
  alone. It does not depend on the ring spacing or the twist.
- Difference: the repo form gives the torque peak of a fixed-gap kinematic. It is not a
  crossing limit. Below `ϕ = 2` the source states that the tethers cannot cross at all.
- Effect: the gate, the preload floor, the controller margin and the optimiser constraint
  all read this form. Ten of the twelve sections of the live seed have `ϕ < 2`.
- Status: the authority now exists in `src/trpt_twist_limit.jl`, commit 996c970. The call
  sites still read the old form. Work package WP3.

## F2. The whole gene range sits at or below the regime split

- Repo claim: the gene `target_Lr` ranges from 0.4 to 2.0.
- Site: `src/ring_spacing.jl:29`.
- Source: printed page 198. The behaviour splits at `ϕ = 2`. Below 2 the tethers cannot
  cross, so tether and ring strength sets the failure point.
- Difference: every design in the range has `ϕ` at or below the split. A crossing limit
  cannot bind for any of them.
- Status: Open. The bound is a search-space decision, not a defect. Rod rules.

## F3. A misattributed bound in the seed generator

- Repo claim: "Tulloch: L/r can be as high as 6; minimum ~1.0 for stability".
- Sites: `scripts/compute_seeds.jl:141`, `scripts/compute_seeds.jl:170`.
- Source: printed page 201 gives the 6, but as the **maximum** length to radius ratio at a
  force ratio of 0.17. The thesis gives no minimum of 1.0. Its statements on page 198 are:
  no crossing below `ϕ = 2`. `δcrit` never falls below 90°. Operation is stable when
  `ϕ < 2` or `δ < 90°`, unless strength binds.
- Difference: the repo inverts the 6 into a lower bound. It also adds a minimum of 1.0
  that the source does not carry.
- Effect: the seed ladder and the spread use `lo = 1.0`. Every seed therefore sits inside
  the no-crossing class.
- Status: Open. The comment is wrong. The bound it justifies is a search-space decision.

## F4. The optimiser constraint uses a capacity with no source

- Repo claim: `τ_cap = T_total_rated · r_min² / root(L² + 2·r_min²)`, with a required
  factor of safety of 1.5.
- Sites: `src/trpt_optimization.jl:871`, `src/trpt_optimization.jl:875`, constant at
  `src/trpt_optimization.jl:39`.
- Source: printed page 198 for the curve and page 199 for the maximum. The maximum torque
  at a fixed axial force is the peak of (5.3), at the angle from (5.4).
- Difference: the repo form gives a value on the curve at a generic angle. It does not
  give the peak. It understates the capacity by about 20 percent on section 9 of the live
  seed.
- Status: Open. Work package WP3.

## F5. The transition cone angle is unverified

- Repo claim: `cone_slope_deg = 22.0`, described as the "TRPT cone half-angle
  (Tulloch/Jensen reference)".
- Sites: `src/objective_evaluator.jl:145`, `src/objective_v10.jl:195`. The code uses the
  value as a slope at `src/objective_v10.jl:264`.
- Source: the text says the TRPT "was designed to have a cone angle of 22°". The text does
  not say whether that is the apex angle or the half-angle.
- Difference: if the printed angle is the apex angle, then the slope on each side is 11°.
  The repo cone is then twice as steep as the source.
- Status: Open. A figure decides this, not a sentence. Work package WP2d.

## F6. The tether drag coefficient

- Repo claim: `TETHER_DRAG_CD = 1.0`.
- Site: `src/aerodynamics.jl:335`.
- Source: printed page 218. At a drag coefficient of 1.2 the torque loss in TRPT#4 is
  4.9 N·m at a tip speed ratio of 4.0. At 2.7 the loss is 9.9 N·m at a tip speed ratio
  of 3.8.
- Difference: the repo value sits below both printed cases.
- Status: Open. Rod ruled: 1.2 for the scaled campaigns, 2.7 for Daisy-class prototypes.
  Report the loss at both. Work package WP2c.

## F7. The drag torque path is missing — CONFIRMED by code reading, 2026-09-26

- Repo claim: the tether drag enters the model as a force. The code splits the force in
  two and applies each half to the node at one end of the line.
- Site: `src/rope_forces.jl:441-447`. The counterpart for the ring tube is
  `src/dynamics.jl:140-144`.
- Source: section 4.5.2 and section 4.6 give the split and the direction. The source does
  not give a torque route.
- The split matches. The torque does not arrive at the shaft. The chain:
  - the ring spin acceleration reads the torque accumulator only (`src/dynamics.jl:189`)
  - a force enters the translational equation only (`src/dynamics.jl:179`)
  - the drag writes to forces only, at both sites
  - the same function applies the moment for the tension force
    (`src/rope_forces.jl:458-466`), so the pattern was available
  - no drag torque exists anywhere else in the tree
- Result: the ring centre lies on the shaft axis. A tangential force at the centre does no
  work on the rotation. So the drag cannot slow the shaft, and its energy leaks into the
  ring-centre translational mode and into the rope nodes.
- Status: CONFIRMED. The fix and the test are the proposal of 2026-09-26,
  `docs/plans/2026-09-26-trpt-drag-torque-fix.md`.

## F8. The ring tube drag is not a significant torque source

- Repo claim: the ring tube drag is a cross-flow drag with coefficient 1.2, applied to the
  intermediate rings only (`src/dynamics.jl:85-95`).
- Source: the printed model neglects the ring drag (printed page 219). The source notes
  only that a ring could be given an aerodynamic profile.
- The physics: the tube axis lies on the circumference, and the spin flow lies on the
  circumference. So the tube slides lengthwise through the air, and the spin flow makes no
  cross-flow drag. The code takes the part of the relative velocity perpendicular to the
  beam axis (`src/dynamics.jl:136-138`), so it already excludes the spin flow. What
  remains is the wind cross-flow and the ring translation.
- Correction to our own record: an estimate of 2026-09-26 put the ring tube drag torque at
  1051 N·m for the live seed at 13.75 rad/s. That estimate was wrong. It used the full
  tangential velocity against the frontal area. A hard bound falsifies it: at steady state
  the total drag torque must stay below the rotor torque, and 1051 N·m against a 364 N·m
  shaft torque breaks that bound.
- Status: Closed, no defect. Put the bound in the acceptance test as an assertion.

## F9. The best-fit drag coefficient of 2.7 is a lumped value

- Repo claim: `TETHER_DRAG_CD = 1.0` for the scaled campaigns.
- Source: the source uses 1.2 in every simulation, and the best fit to the Daisy
  experiment is 2.7. The source states that the models underestimate the drag of the whole
  Daisy system, and that the rings and bridle lines are absent from the model.
- Difference: our 1.0 sits below both printed values.
- Status: Open. Rod ruled 1.2 for the scaled campaigns and 2.7 for Daisy-class work, and
  to report the loss at both. The ruling stands. The reason changes: the pair is not two
  candidate line coefficients, it is one physical value and one lumped calibration.

## F10. The bridle line drag is not in the model

- Repo claim: none. The repo models the bridle lines for geometry and for torque.
- Source: the bridle lines of the three blades cause 3.7 N·m of torque loss at 25 degrees
  elevation, 8 m/s and tip speed ratio 4.0. They raise the whole loss from 4.9 to 8.6 N·m
  (printed page 219). Their mid points sit at 1.3 m and 1.6 m radius, so they work at a
  larger radius than much of the TRPT.
- Difference: the source calls the amount significant, and recommends removing the bridle
  lines or cutting their length and radius. The repo does not model their drag.
- Status: Open. Needs a check of `src/rope_forces.jl` for a bridle drag path, then a
  decision. It is a design lever as well as a loss.
- Answer, 2026-09-26: the bridle lines ARE sub-segments, so they pass through the same
  drag kernel with their own diameter and length. Their drag force was always computed.
  What was missing was its moment, which the fix of 2026-09-26 now supplies through the
  same ring-end path. So the gap is smaller than this finding first said. The design
  lesson still stands: they work at a large radius, and the source calls the amount
  significant.

## F11. The ring-end drag uses the ring centre velocity, not the attachment velocity

- Repo claim: the tether drag force uses the mean velocity of the two ends of the
  sub-segment (`src/rope_forces.jl:419-436`, then `tether_drag_force!`).
- Site: `src/rope_forces.jl:394-395`. Both velocities come from the node velocity blocks.
  A ring node holds the ring CENTRE velocity. The ring centre lies on the shaft axis, so
  in a pure rotation its velocity is zero.
- The model's own convention, recorded in `test/test_settle_validity.jl:165-169`: "rope
  nodes at their orbital velocity, ring/bearing/sky translational velocities zero, omega
  retained".
- Difference: the attachment point of a tether moves at the orbital speed, omega times the
  ring radius. The sub-segment that ends on a ring averages its speed with a stationary
  end, so its drag is low by about a factor of four. The interior sub-segments are correct,
  because their rope nodes do carry the orbital velocity.
- The ring tube path gets this right, and adds the rotational term explicitly
  (`src/dynamics.jl:125-126`). So the pattern was available here as well.
- Status: Open. This is a separate physics change from the drag torque fix, so it needs its
  own proposal and its own acceptance test. The drag torque fix of 2026-09-26 does not
  change it. Expect the measured drag torque to sit low against the printed anchor until
  this is fixed.

## F12. The objective's ring beam docstring is stale

- Our first reading of this was wrong, and the error came from trusting a docstring. The
  correction is recorded here in full, because the same trap will catch the next reader.
- What the docstring says (`src/objective_v6.jl`, the P_beam block): "Cylindrical crossflow
  drag model with `Cd = TUBE_DRAG_CD` (1.2)" at the tangential velocity `v_t = ω·rr`.
- What the code does, from line 284: skin friction `P_skin` from the tangential flow, which
  is the lengthwise form, plus a small axial crossflow term `P_axial` at `v_axial` with a
  coefficient of 0.3 for the elliptical section.
- The code is right. The beam slides lengthwise in the spin flow, and a skin friction term
  represents that. The wind crosses the beam broadside, and the axial term covers that.
- The code's own note records the repair: the old model "overestimated beam drag by
  ~1,450×". So the defect was found and fixed before this session, and the docstring stayed
  behind.
- Status: Open as a text defect only. The model needs no change. Rewrite the docstring so
  that it describes the code below it.
- Lesson, and it is the second time in this workstream: read the code before you record a
  finding. The first case was our own ring tube estimate, which the ODE corrected.
