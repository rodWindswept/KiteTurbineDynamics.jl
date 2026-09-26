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

## F13. The screen's tether drag power breaks the bound, and the ODE does not

- Found on 2026-09-26 while validating F11. The two models of the same loss disagree by
  4.5 times, and the screen holds the value that cannot be right.
- Measured at the settled operating point of the live seed, omega 13.452 rad/s, CD 1.0:
  - `settle_parasitic_drag_power`, tether term isolated with the coefficient setting:
    **3.866 kW**
  - the ODE's isolated tether drag torque: **63.717 N·m**, which is 0.857 kW at that spin
- The rotor delivers about 290 N·m at 13.452 rad/s, which is 3.9 kW. So the screen says the
  tether drag alone consumes the whole rotor output.
- That breaks the bound Rod set on 2026-09-26. The drag torque can never exceed the rotor
  torque, because the drag only comes from the rotation the rotors initiated. A machine in
  that state could not spin up at all.
- The same formula sits in the objective's line drag, `src/objective_v6.jl:338`, so the DE
  may be fitting against the same excess.
- The history is worth reading. The 2026-08-24 change multiplied the screen's tether drag
  by six, replacing a line count that was always 1 with `p.n_lines`, and it removed a 0.5
  curvature factor, which together are a 12 times rise in one commit. If the line count was
  right, the screen is right and the ODE is six times low. If the ODE is right, the screen
  carries a large excess.
- Status: Open, and it outranks F11. Three questions settle it: which term carries the
  excess, whether the objective carries the same one, and whether the 2026-08-24 change was
  right.
- For reference, the pre-F11 ODE value was 22.771 N·m, which is 0.306 kW, or 7.8 percent of
  the rotor torque. That value is plausible, and it sat below the printed anchor scaled to
  this geometry at 29.4 N·m. That gap is what started the F11 investigation, and it now has
  a rival explanation: the anchor scaling is crude, and the screen may be the outlier.
- 2026-09-26, second pass. THE FIRST EXPLANATION WAS WRONG, and a probe written to confirm it
  refuted it instead. The proposal was that the screen over-counts because it does not
  project the flow onto the component perpendicular to the line, and that the oblique line
  angle supplies the missing 4.5 times. The settled twist says otherwise: the line slants
  only 5 to 27 degrees from the axial direction, bay by bay, so its tangential flow is very
  nearly perpendicular and the projection factor is close to one. It is not 0.22. The
  screen's perpendicular assumption is therefore almost right, and the projection cannot
  carry this gap.
- THE COMPARISON ITSELF WAS INVALID, and that is the larger lesson. The balance test reads
  `sum(torques)`, and that array holds only the drag moment at the RING ends. A sub-segment
  whose far end is an interior rope node applies its drag there, and that torque reaches the
  shaft through the rope path instead. So 63.717 N·m is a partial figure. It must not be
  compared with the screen's total.
- With the geometry agreeing, length ratio 1.019 and implied line count 6.11 against 6, and
  with the slants small, the two models describe the same physics and probably agree. If they
  do, then the line drag at this operating point is about 3.9 kW against a rotor delivering
  about 3.9 kW, and the bound fails for BOTH models.
- That moves the question. The suspect is no longer the projection. It is the operating point
  and the line itself: 115 m of 3.651 mm line at a tip speed of 32 m/s. Drag power scales with
  the diameter and with the cube of the speed, so either is worth a factor of three.
- Next, and it is a measurement rather than an argument: sum the drag power the ODE's own
  model dissipates, the force times the velocity over every sub-segment, at the settled
  state. That figure is a total. It is comparable with the screen and with the rotor, and it
  decides which of three suspects, a wrong diameter, a wrong tip speed, or a wrong
  coefficient, carries the error.
- No code change follows from F13 until that number exists.
- 2026-09-26, third pass. The total drag measurement is in, and it clears the drag models.
  Measured at the same settled state, by summing force times velocity over every node:
  - total drag power, wind on: 2.404 kW, which is 65 percent of the rotor power
  - total drag power, calm, rotation only: 2.158 kW, which is 58 percent of the rotor power
  - the screen's tether term: 3.866 kW, so the screen is 1.6 to 1.8 times the ODE total
  - the ring-end share of the drag torque: 22.771 N.m. The total drag torque is about
    160 N.m, so the ring ends carry 13 percent. That confirms the partial-sum correction
    above and it sets the size of the earlier error.
- The screen and the ODE therefore agree to within a factor of two, and the parked F11 fix
  closes that gap, because F11 is the correct treatment of a line that ends on a spinning
  rim. Neither drag model breaks Rod's bound at 65 percent.
- THE SUSPECT HAS MOVED TO THE ROTOR. At the same state the settle's own aerodynamic model
  claims 9.689 kW, while the ODE rotor at the topmost ring delivers about 3.71 kW. That is a
  factor of 2.6. Remove the drag from the settle's figure and 7.28 kW remains against
  3.71 kW delivered. About 3.6 kW is then unexplained beyond drag.
- So the bound appears to fail because the denominator is under-modelled, not because the
  drag is over-modelled. The diameter and tip-speed suspects recorded above are withdrawn.
- Open, and it is the owner's question: which rotor power scheme is authoritative, and where
  is each one calibrated. An audit of both paths is in progress, recorded separately.
- Also open: the rotor torque reads minus 276.0 N.m here, where the balance test recorded
  plus 290.663 N.m for the same ring and the same spin. A sign or a term differs between
  those two derivations. That is unresolved. Treat the magnitude as usable, and treat the
  sign as open.
- 2026-09-26, fourth pass, and the rotor question is answered. The measurement was taken
  again with the scopes matched, term by term.
- FIRST, A DURABLE FACT ABOUT THE TORQUE ARRAY. `sum(torques)` is exactly zero at a settled
  state, because the array is a NET array. It carries the rotor drive, the generator load and
  the drag together. The ground ring reads plus 415.81 N.m, which is the generator, 2.24
  times the square of 13.452. The topmost ring reads minus 276.02 N.m, which is the hub
  rotor. They cancel. So the sum is never a rotor power, and reading it as one produced four
  phantom discrepancies in this workstream. Measure the terms, not the sum.
- The per ring split at the settled state, spin 13.452 rad/s:
  - hub rotor, topmost ring: 3.713 kW, against the settle's hub term of 3.994 kW. Ratio 0.930
  - expansion rotors, rings 10 to 12: 2.212 kW, against the settle's 5.695 kW. Ratio 0.388
  - rotor total: 5.925 kW, against the settle's total of 9.689 kW. Ratio 0.611
  - generator load: 5.594 kW
- THE VERDICT. Both paths use one authority, the AeroDyn v5.0.0 tables at 0 degrees elevation,
  reached through `cp_at_tsr`. The hub rotor agrees between the paths to 7 percent, and the
  residual is the design against live elevation angle. The whole discrepancy is the SETTLE'S
  EXPANSION ROTOR TERM, which over counts by 2.6 times. It computes a bare annulus power from
  the table with no induction model and no elevation factor. The ODE solves the momentum
  balance instead, through `solve_expansion_induction` with the Buhl/Glauert thrust
  coefficient. The ODE model is the more physical of the two.
- The remaining weakness is the ODE expansion polars, and the repo states it itself at
  `src/expansion_rotor.jl:65-69`: textbook values from Abbott and von Doenhoff 1959, marked
  CALIBRATED not VALIDATED, with an AeroDyn BEM sweep or XFOIL run at Re 2e6 named as the
  authoritative source. See item M5.
- THE BOUND HOLDS. Against the full rotor stack, 440.41 N.m of drive against 415.81 N.m of
  generator load, the total drag of 2.4 kW is 41 percent of the rotor power. The earlier 65
  percent figure came from measuring against a single ring. Nothing is over the bound.
- The only measurement backed rotor validation in the repo is the ledger row A4, system Cp
  band 0.15 to 0.18, model 234 W against measured 223 W plus or minus 79 W at 6.25 m/s. It is
  a system comparison, so it validates the stack, not the rotor alone. No test gates any rotor
  power level.
- Recommended, for the owner to rule on: make the settle use the ODE expansion model so the
  two agree by construction, pursue item M5 for the polars, and add the field data comparison
  as an acceptance test.
- 2026-09-26, fifth pass. THE OWNER CHALLENGED MY RING LABELS AND HE WAS RIGHT. I had labelled
  rings 2 to 12 as expansion rotors, by inference from the torque magnitudes. The build
  carries two expansion rotors, not eleven.
- The confirmed roles, read from `sys.expansion_rotors` and checked against
  `docs/agents/physics-topology.md`:
  - ring 1, radius 0.5751 m: the ground ring. The generator sits here.
  - rings 2 to 9, radius 0.5751 m: straight TRPT rings. No rotor.
  - ring 10, radius 1.1748 m: the transition ring. No rotor.
  - rings 11 and 12, radius 2.4000 m: the two expansion rotors, banked blades.
  - ring 13, radius 2.4000 m: the MAIN rotor, on the cp/ct disc model.
- The mapping function is `expansion_params_from_rotors`, `src/builders_util.jl`. Its docstring
  excludes the top rotor by design and it records a 2026-08-26 fix where an off-by-one `+1`
  shifted every expansion rotor one ring toward the hub, landing a rotor on the main rotor's
  ring.
- The measured torques stand, because they were read per ring. The corrected totals:
  - main rotor, ring 13: 3.713 kW, against the settle hub term of 3.994 kW. Ratio 0.930
  - expansion rotors, rings 11 and 12: 2.010 kW, against the settle's 5.695 kW. Ratio 0.353
  - rotor total: 5.724 kW, against the settle total of 9.689 kW. Ratio 0.591
- So the settle over counts the expansion rotor term by 2.8 times, not 2.6. The finding holds
  and it grows. The main rotor still agrees to 7 percent.
- The bound still holds. 2.4 kW of drag against 5.724 kW of rotor is 42 percent.
- STILL UNIDENTIFIED, and not to be guessed. Rings 2 to 9 each carry about plus 2 N.m, and
  ring 10 carries minus 14.93 N.m. None of those rings has a rotor, so those terms are not
  rotor power. A term split is owed: run the kernel with the generator gain at zero, with the
  expansion load withheld through `expansion_aero_on`, and with the tether drag differenced.
- Lesson. A ring's role is a build input, not a geometric inference. Read
  `sys.expansion_rotors`, and do not read a torque magnitude as evidence of a rotor.
- 2026-09-26, sixth pass, the term split. Measured at the settled state by differencing three
  things. It corrects two assumptions of mine.
- THE GENERATOR IS NOT IN THIS ARRAY. Setting the MPPT gain, `sys.k_mppt_ref[]`, to zero
  changes no ring at all. So the ground ring's plus 415.78 N.m is NOT the generator, as I had
  stated in the fourth pass. It is the ground ring's reaction to the transmitted torque. The
  generator is applied on another path.
- WHAT THE ARRAY ACTUALLY HOLDS:
  - the aerodynamic torques, which sum to zero across the stack by Newton's third law, and
  - the tether drag, the only unbalanced term. The whole array sums to minus 22.7713 N.m, which
    is exactly the ring end drag figure.
- THE MAIN ROTOR CARRIES THE OPPOSITE SIGN CONVENTION to the drive. Ring 13 measures minus
  280.48 N.m where the site formula at `ring_forces.jl:216-223`, computed live, gives plus
  296.92 N.m. That is 5.5 percent agreement, not a contradiction. The difference is the drag
  plus the live against design elevation angle. The earlier open note, minus 276.0 here against
  plus 290.663 in the balance test, is therefore resolved: one number in two conventions.
- THE RING END DRAG SHARE, per ring: ring 1 minus 0.038, rings 2 to 8 about minus 0.08 each,
  ring 9 minus 0.146, ring 10 minus 1.190, ring 11 minus 7.550, ring 12 minus 8.817, ring 13
  minus 4.457. Total minus 22.7713 N.m. It concentrates at the three large radii.
- THE RESIDUAL, not yet fully identified, and printed rather than explained: rings 2 to 9 carry
  about plus 2 N.m each, ring 9 carries plus 10.78, and ring 10 carries minus 14.93. Those rings
  host no rotor and hold almost no drag, so those are transmission terms. The shape matches the
  per-segment transmitted-torque bookkeeping in the post-loop clamp path, `seg_tau_a` and
  `seg_tau_b` at `src/rope_forces.jl:321-326`, not an aerodynamic term. Naming the exact source
  needs one more read of that block, so it is not guessed here.
- 2026-09-26, seventh pass. F13 CORRECTED. The divergence is a SIGN, not a coefficient.
- Both paths see the same wind. The settle forms `v_er = v_mag * er.wind_factor`
  (`initialization.jl:1030`). The ODE forms `v_wind_mag_ring = norm(wind_fn(ring_pos, t)) *
  er.wind_factor` (`ring_forces.jl:273-277`). Those agree.
- The settle looks up `cp_at_tsr(lambda_er)` and returns a POSITIVE power: a drive.
- The ODE calls `expansion_rotor_forces` and returns `tau_net`, which the code itself defines as
  "Positive = driving (injects power). Negative = braking (parasitic)". Both expansion rotors
  come out NEGATIVE, minus 74.37 and minus 75.09 N.m. At this solidity the ODE's alpha and
  induction model BRAKES.
- The code says so itself. The HUB GUARD comment at `ring_forces.jl:255-260` records that the
  expansion alpha and induction model "brakes at high solidity" and that this "killed the 5 kW
  seed". The live seed is that 5 kW case.
- So the correction: the settle predicts plus 5.695 kW of drive where the ODE predicts minus
  2.010 kW of braking. That is a sign level disagreement of 7.7 kW in the expansion term, not a
  2.833 fold coefficient error as the fourth pass stated. The "2.833" is real arithmetic on the
  two magnitudes, but calling it a coefficient error was wrong.
- A backward solve of the settle formula against the measured torque implies a wind of 6.7 to
  6.9 m/s. That number is an artefact, because both paths receive 10 to 11 m/s. It is recorded
  here so it is not reused.
- Also confirmed from the build: the live seed's expansion rotors are NOT banked, bank angle
  0.00 deg on both, and their blade offsets are signed, tip plus 0.759 m and hub minus 0.325 m on
  ring 12.
- What is NOT established, and needs a reference rather than plumbing: which model is right at
  this solidity. The settle's coefficient comes from the AeroDyn v5.0.0 table, the better
  authority. The ODE's polars are repo-marked CALIBRATED, not VALIDATED. So the recommendation
  changes. Do NOT make the settle adopt the ODE's expansion model, because that would import a
  calibrated braking model into the screening path. The open question belongs to the reference
  library: what does the source say an expansion rotor of this solidity does.
- 2026-09-26, the residual, CLOSED. It is not drag, and the code branch settles it. At
  `rope_forces.jl:469-475` a TRPT segment's torque is accumulated for the post-loop clamp,
  `seg_tau_a[seg] += tau_a  # TRPT end, defer for C1 clamp`, while a non-TRPT ring such as a
  bridle is applied directly, `torques[ri_a] += tau_a`. Rings 2 to 10 are TRPT rings, so their
  numbers arrive by the deferred clamp path. The sign varies because the term is a SURPLUS, what
  a ring receives minus what it passes on, not a resistance. Drag cannot change sign; that
  column does not.
