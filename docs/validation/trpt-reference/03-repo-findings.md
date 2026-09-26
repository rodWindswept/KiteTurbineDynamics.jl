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

## F7. The drag torque path is unverified

- Repo claim: the tether drag enters the model as a force. The code splits the force in
  two and applies each half to the node at one end of the line.
- Site: `src/rope_forces.jl:437-446`.
- Source: section 4.5.2 and section 4.6 give the split and the direction. The source does
  not give a torque route.
- Difference: the split matches. Whether the drag torque arrives at the shaft is untested.
  The code adds the drag force to node forces only. Nobody has traced how a force on a
  ring attachment node becomes a torque on the ring.
- Status: Open. Work package WP2b. The test is an energy balance. In steady wind, the
  torque the sections apply to the rings must equal the line drag torque.
