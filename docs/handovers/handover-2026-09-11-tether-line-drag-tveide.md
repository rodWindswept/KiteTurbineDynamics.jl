# Handover: tether line drag for a rotating shaft (TRPT)

Date: 2026-09-11
Topic: line drag formulation for TRPT, and validation of the tether drag factor
Applies to: `src/objective_v6.jl` lines 316-322 (`tether_curvature_factor = 0.5`)

## 1. Purpose

Review the tether line drag model against the published method. Validate or
replace the 0.5 curvature factor. The current comment says the factor is
"pending ODE validation at TRPT operating conditions". This brief supplies
the method and the validation steps.

## 2. Sources

1. Tveide, T. **TetherDragODESolver**. MIT licence, Julia.
   https://github.com/tallakt/TetherDragODESolver
   Method paper: `docs/a_simplified_drag_estimate_for_a_tether_with_a_belly.pdf`
2. Tveide, T. **The second law of tether scaling**. AWEC 2019 poster, Kitemill.
   In the AWEC 2019 book of abstracts.
3. Dunker, S. **Tether and Bridle Line Drag in Airborne Wind Energy
   Applications**. In Schmehl, R. (ed.) Airborne Wind Energy, Green Energy and
   Technology, Springer, 2018, pp. 29-56. DOI 10.1007/978-981-10-1947-0_2
4. Dunker, S. **Experiments in Line Vibration and Associated Drag for Kites**.
   AIAA 2015-2154. DOI 10.2514/6.2015-2154

## 3. The key distinction: yoyo against TRPT

For a yoyo or fly-gen system, the ground attachment point does not move. Drag
near the ground side does not cause a power loss. Only the kite-side angle
matters. The method allocates drag to the kite by position along the tether,
so drag near the ground counts less.

For a TRPT shaft, the ground ring moves. The system receives the shaft energy
at that ring. Both ends of the tether count as energy losses. Treat the whole
tether drag as a loss from system performance.

This distinction is structural. It does not depend on any coefficient.

## 4. Straight-line tether: closed-form results

Symbols:

- `omega` shaft rotation rate (rad/s)
- `rho` air density (kg/m3)
- `d` tether diameter (m)
- `l` tether length (m)
- `CDt` tether drag coefficient
- `r0` ring radius at the ground end (m)
- `r1` ring radius at the kite end (m)
- `s` position along the tether, measured from the ground end

Yoyo:

    D_yoyo = (1/8) * rho * omega^2 * r1^2 * CDt * d * l

TRPT:

    D_TRPT = (1/6) * rho * omega^2 * (r0^2 + r0*r1 + r1^2) * CDt * d * l

Both assume a straight tether with a linear radius change:

    r(s) = r0 + (r1 - r0) * s / l

## 5. Limiting cases

1. Constant radius, `r0 = r1 = r`:

       D_TRPT = (1/2) * rho * (omega*r)^2 * CDt * d * l

   The whole tether moves at shaft speed. The drag equals the drag of the full
   tether at that speed.

2. Straight yoyo. Compare `D_yoyo` with the full drag at kite speed:

       D_full_kite = (1/2) * rho * (omega*r1)^2 * CDt * d * l

   The ratio is 1/4. This reproduces the standard quarter rule.

## 6. Shaft twist

The closed forms above assume zero twist. This is the worst case.

Tether drag approaches the non-TRPT value when the shaft twist is about 90
degrees. It falls below that value between 90 and 180 degrees.

## 7. Reference values from the solver

The repository README prints these values:

| Case | drag_coefficient_multiplier |
|---|---|
| Non-TRPT | 0.2505 |
| TRPT shaft, 90 degrees twist | 0.2658 |

The TRPT run also prints `solved_efficiency_ratio = 0.4948` and
`solved_lambda = 0.0478`.

## 8. Warning: normalisation is not the same as KTD

Do not copy 0.2658 into the model as a replacement for 0.5.

Tveide normalises the multiplier against a straight-tether reference. That
reference is one quarter of the full tether drag at kite speed:

    reference = (1/4) * (1/2) * rho * (omega*r1)^2 * CDt * d * l

The model multiplies a per-segment drag sum. Each segment uses the local
tangential speed `v = omega * r_mid`. See `src/objective_v6.jl` lines 324-335:

    P_seg_raw = 0.5 * rho * TETHER_DRAG_CD * d_tether * L_seg * v_t_mid^3

The per-segment form already contains the radial change of speed. The Tveide
reference does not. The two quantities are different. Derive the equivalent
factor in the model's own units before you change the constant.

## 9. Belly-aware method (the full ODE form)

The closed forms use a straight tether. The full method solves the tether
shape. The shape curves for two reasons: centrifugal force on the tether mass,
and tether drag. The method treats the shape as quasi-static at constant
rotation rate `omega`.

Path: `x(s)`, with `|dx/ds| = 1`.

Centrifugal force per unit length, with `mu` the tether mass per metre:

    c(s) = mu * omega^2 * r(s),    r(s) = x(s) . (i_hat + j_hat)

Drag force per unit length:

    f_drag(s) = (1/2) * rho * omega^2 * |r(s)|^2 * CDt * d * Kapp(s) * d_hat(s)

where

    d_hat(s) = A90 * r_hat(s)

`A90` is the -90 degree rotation matrix about the z axis, and

    Kapp(s) = |dx/ds x d_hat|

Total force per unit length:

    f(s) = c(s) + f_drag(s)

Only the part of `f` normal to the tether curves the tether:

    f_n(s) = dx/ds x [dx/ds x f(s)]

Newton's first law in differential form along the tether gives three equations.
Feed them to a numerical differential equation solver. Solve the three unknown
second derivatives by matrix inversion.

    (I)    (d2x/ds2) . [dx/ds x f(s)] = 0

    (II)   f_n(s) . d2x/ds2 = (1/T) * (dx/ds . k_hat) * (f_n(s) . f_n(s))

    (IIIb) (dxx/ds)*(d2xx/ds2) + (dxy/ds)*(d2xy/ds2) + (dxz/ds)*(d2xz/ds2) = 0

   Equation (IIIb) is the derivative of the unit-length condition. Use the
   unit-length condition itself to solve `xz(s)`. This avoids numerical drift:

    (III)  (dxx/ds)^2 + (dxy/ds)^2 + (dxz/ds)^2 = 1

Shaft tension `T` is constant, measured along the centreline:

    Tt(s) * (dx/ds . k_hat) = T

Julia entry points:

    solve_tether(omega, tension, r0, r1, l, theta, d; mu)
    solve_tether_for_non_trpt(omega, tension, r0, r1, l, theta, d; mu)
    solved_moment_loss(solution)

The solver returns `solved_efficiency_ratio`, `solved_lambda`, and
`solved_drag_coefficient_multiplier`.

## 10. Validation case from the method paper

The paper compares the belly-aware result with the straight-line result for:

| Parameter | Value |
|---|---|
| Tether diameter | 3 mm |
| Tether length | 200 m, 400 m, 600 m |
| Shaft tension | 2.5 kN, 5.0 kN, 7.5 kN |
| `r0` | 10 m |
| `r1` | 40 m |
| `CDt` | 1.0 |
| `omega` | 1.0 rad/s |
| `rho` | 1.225 kg/m3 |
| `mu` | 0.005 kg/m |
| Twist | 0 degrees |

Result: the belly-aware drag is close to the straight-line drag at high
tension. The difference grows with tether length. The difference falls as
tension rises.

## 11. Validation tasks

1. Run `TetherDragODESolver` at the model's shaft geometry, tension, rotation
   rate, and twist angle. This is the ODE validation named in the code comment.
2. Derive the equivalent curvature factor in the model's own units. Use the
   `P_seg_raw` form above as the basis. Compare against the current 0.5.
3. Check `TETHER_DRAG_CD = 1.0` against the Dunker data. Dunker measured drag
   increases up to 300 percent from vortex-induced vibration, and up to 210
   percent from galloping. A static smooth-cylinder value may be too low if
   the tether vibrates at the operating Reynolds number.
4. Cross-check the loss budget. Wacker (2022) found that frame drag accounts
   for about 50 percent of total TRPT drag losses. The ring struts are a
   separate term in the model (`TUBE_DRAG_CD = 1.2`). Confirm both terms are
   counted once.

## 12. Guard rules

Any change here is a physics change. Write the proposal and the acceptance
test first. Do not change the constant without a run that shows the effect.

## 13. Limits of this brief

The two closed forms and the ODE form come from the sources in section 2. The
section 7 values are the author's own printed output. The equivalence in
section 8 is not yet demonstrated. Treat section 8 as a hypothesis to test.
