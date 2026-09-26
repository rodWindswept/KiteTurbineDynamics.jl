# Tulloch's TRPT relations, from the printed source

This file records the TRPT relations of the thesis. Each entry gives the equation as
printed, the symbols, and the page anchor. Use it to check our code.

Source: O. Tulloch, PhD thesis, University of Strathclyde, 2021, 308 pages.
Text extract: `../tulloch-thesis-extract.txt` (309 pages, split on the form feed
character, so page index equals PDF page number).

## Symbols

| Symbol | Name | Unit |
|---|---|---|
| `R` | ring radius. Both rings of the section have the same radius in this analysis. | m |
| `r_a`, `r_b` | radius of ring A and ring B. Our code uses these for a tapered section. | m |
| `l_t` | tether length | m |
| `delta` | torsional deformation. The twist between the two rings. | rad |
| `delta_crit` | critical torsional deformation | rad |
| `Q` | torque transmitted by the section | N·m |
| `F_x` | axial force on the section | N |
| `T` | tension in one tether | N |
| `L_ax` | axial distance between the two rings | m |
| `phi` | the ratio `l_t / R` | – |
| `force ratio` | `(Q / R) / F_x`. The tangential force at the ring, divided by the axial force. | – |

## 1. Torque of one section — equation (5.3), printed page 198

Printed form:

    Q = (R·F_x / root(2)) · sin(delta) / root( l_t^2 / (2·R^2) + cos(delta) - 1 )

Multiply the numerator and denominator by `root(2)·R`. The result uses the ring
separation:

    Q = R^2 · F_x · sin(delta) / root( l_t^2 - 2·R^2·(1 - cos(delta)) )

The denominator is the ring separation `L_ax`, because

    L_ax^2 = l_t^2 - 2·R^2·(1 - cos(delta))

Our code uses the same law in the line-tension form. The line tension and the axial
force have this relation:

    T = F_x · l_t / L_ax

Contraction: `Q` is zero at zero twist, because `sin(0) = 0`. `Q` is zero again at
`delta = 180°`, because `sin(180°) = 0`. The curve has one maximum between them.

Source: printed page 198, extract page 225. Figure of the curve: Figure 5.25, printed
page 199, extract page 222.

## 2. The critical twist angle — equation (5.4), printed page 198

Printed form:

    cos(delta_crit) = 1 - phi^2 / 2 + (phi / 2) · root( phi^2 - 4 )

This is the solution of `dQ/ddelta = 0`. The angle therefore gives the maximum torque.
Equation (5.5) defines `phi`:

    phi = l_t / R    (5.5)

Notes from the text, printed page 198:

- `delta_crit` depends on `phi` only. It does not depend on the torque or the axial force.
- The minimum value of `delta_crit` is 90°. The value approaches 90° as `phi` grows.
- At `phi = 2` the equation gives `delta_crit = 180°`.

The last point follows from the equation. Put `phi = 2`. Then `cos(delta_crit) = 1 - 2 +
1·0 = -1`, so `delta_crit = 180°`.

## 3. The two failure regimes — printed page 198

The text splits the behaviour at `phi = 2`. Verbatim:

> Below a phi value of 2 it is not geometrically possible for the torsional deformation
> to reach 180°. The tethers are therefore not able to cross. In this situation the
> material strength of the tethers and rings will dictate the failure point. In the case
> where phi is less than 2, it is possible for the axial distance between two rings to
> reduce to zero, although in practise the rings or tethers will fail prior to this
> occurring. It can be seen in Figure 5.27 that the minimum value of delta_crit is 90°.
> It can be stated that if phi is less than 2 or the torsional deformation is lower than
> 90° the operation is stable, unless the torque and axial forces are larger than the
> strength of the tethers or rings can withstand.

Consequences for this repo:

| `phi` | Crossing of tethers | Limit that binds |
|---|---|---|
| `phi < 2` | not possible | tether and ring strength |
| `phi = 2` | possible at 180° only, with the rings closed | tether and ring strength |
| `phi > 2` | possible | `delta_crit` from (5.4) |

At `phi = 2` the ring separation `L_ax` goes to zero as the twist goes to 180°. The
tension `T = F_x·l_t/L_ax` then goes to infinity. The strength limit therefore binds long
before the torque limit.

## 4. The force ratio — printed page 199

Verbatim:

> The force ratio refers to the ratio between the tangential force due to torque acting
> at the ring, Q/R, and the axial force applied to the TRPT section, F_x. ... The force
> ratio is at a maximum when the torsional deformation is equal to delta_crit. The maximum
> value of the force ratio remains constant independent of the magnitudes of the torque
> and axial force. For a given TRPT geometry, limits can be calculated for the maximum
> force ratio that will avoid TRPT failure. In the case shown in Figure 5.28 this value
> is 0.5.

The printed case has `R = 0.4 m`, `l_t = 1 m`, so `phi = 2.5`. The printed maximum force
ratio is 0.5.

Our closed form for the maximum torque at a fixed axial force is

    Q_max = F_x · ( root(l_t^2 - (r_a - r_b)^2) - root(l_t^2 - (r_a + r_b)^2) ) / 2

For equal radii this becomes

    force ratio = u - root(u^2 - 1),  where u = phi / 2

The value of that expression at `phi = 2.5` is 0.5. It matches the printed value.

## 5. The stability map — Figure 5.29, printed page 200

The map plots the force ratio against `phi`. The upper boundary of the shaded region is
`delta_crit`. Verbatim:

> The shaded region on the graph indicates the TRPT geometries and operating conditions
> that are stable. The line along the top of the shaded region represents delta_crit and
> therefore above this line the ability of the TRPT to transmit torque has collapsed to
> zero.

The boundary starts at the left edge of the figure. The left edge is `phi = 2`. The
printed value there is force ratio 1.0. The boundary falls as `phi` grows.

The text on printed page 201 gives two more points:

- A force ratio of 0.17 allows a length to radius ratio "as high as 6".
- A radius of 0.35 m gives a force ratio of 0.72, "which corresponds to a maximum length
  to radius ratio of 2.11".

Both agree with the closed form in section 4. The closed form gives 0.1716 at `phi = 6`
and `phi = 2.1089` at a force ratio of 0.72.

## 6. Our tension-basis capacity limit — the defect of 2026-09-25
An earlier commit capped the torque of a section at

    T_live · R^2 · sin(delta_crit) / l_t

`T_live` is the tension at the present twist. That product equals the maximum torque at
one twist only: at `delta = delta_crit`. At every smaller twist the product is too small,
because the true maximum torque at the same axial force carries the extra factor
`L_ax(delta)/L_ax(delta_crit)`. The cap therefore bit below `delta_crit`.

At `phi` just above 2 the defect is large. At `phi = 2.01`, `delta_crit = 144.96°`. The
cap bit from 35° of twist.

## 7. The dynamic response benchmark — Table 5.13, printed page 228

The source gives one dynamic benchmark for a whole system. It is the only external
dynamic check on our model. The subject is the Daisy Kite. Its TRPT#4 is 10.3 m long and
holds 8 sections. The test runs at a tip speed ratio of 4.0.

The stimulus: hold the steady state, then reduce the generator torque by 1 N·m for 0.5 s.
The settling time is the time from that step until the ground station rotational speed
stays inside plus or minus 2 percent of the steady state speed.

| Wind speed (m/s) | Torsional stiffness (N·m) | Settling time (s) |
|---|---|---|
| 6 | 35 to 60 | 200 |
| 8 | 65 to 110 | 167 |
| 10 | 100 to 170 | 136 |
| 12 | 145 to 245 | 106 |

The stiffness rises with wind speed and the settling time falls. The source gives the
cause. The axial force rises with the square of the wind speed, and the torsional
stiffness is proportional to the axial force.

We have two checks to make. The stiffness check is static and cheap. The settling time
check needs a window of at least 200 s. That is far longer than the 20 to 30 s window
used elsewhere in this repo, so the test belongs in `test/acceptance_runtests.jl`.

Note the subject of the table. It is the Daisy Kite with a 10.3 m TRPT, not a large
rotor. A repo plan of 2026-06-30 gives "a 190 m optimised rotor" for these times. The
thesis holds no rotor of 190 m.
