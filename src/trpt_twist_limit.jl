# src/trpt_twist_limit.jl — the TRPT over-twist authority (2026-09-25)
#
# ONE authority for how far a TRPT segment can twist, and for the torque it can carry
# at that limit. Every gate, floor, refusal, controller margin and optimiser capacity
# reads this file. Four copies of a mis-derived criterion is how the repo lost its
# footing against the thesis.
#
# Source: Oliver Tulloch, PhD thesis, University of Strathclyde (2021).
#   (4.28)–(4.31) the chord, the ring separation and the transmitted torque
#   (4.34)/(5.4)  the critical deformation angle δcrit
#   Fig 5.25      the operating curve and its peak, checked numerically below
#   §5.3.1        "the torsional deformation must be kept below δcrit"
#   §3.1.3        for a tether shorter than the ring diameter the lines cannot reach
#                 the axis, so the limit is material strength and not geometry

"""
    trpt_twist_limit(r_a, r_b, l_t) -> NamedTuple

Return the Tulloch (2021) over-twist limit for one TRPT segment.

Arguments, in SI units:

- `r_a`, `r_b` — the attachment radii of the two rings, in metres.
- `l_t` — the tether length at the design tension, in metres. This is the repo's
  `chord` at the operating point, not the axial ring separation.

Fields of the result:

- `has_limit` — `true` when an over-twist limit exists.
- `dcrit`, `dcrit_deg` — the critical deformation angle δcrit, the twist at which the
  transmitted torque reaches its maximum. NaN when `has_limit` is `false`.
- `sin_dcrit` — `sin(δcrit)`. NaN when there is no limit.
- `l_ax_dcrit` — the ring separation at the limit, in metres. NaN when there is no limit.
- `disc` — the discriminant `(l_t² − (r_a+r_b)²)(l_t² − (r_a−r_b)²)`. Its sign splits the
  two cases, and `disc ≥ 0` is exactly `l_t ≥ r_a + r_b`.
- `d_touch`, `d_touch_deg` — the twist at which the rings meet, valid when there is no
  limit. NaN when there is one, because then the lines reach the axis at 180° first.

Case A, `disc ≥ 0`, the tether spans at least the sum of the two radii:

    cos δcrit = [ r_a² + r_b² − l_t² + √disc ] / (2·r_a·r_b)          (4.34)

The `+` root is the torque maximum and always lies in [−1, 1] here. The maximum is a
maximum of the operating curve of `trpt_torque_capacity_axial`, which holds the axial
force and lets the rings contract. Past δcrit the deformation runs away and the
equilibrium is lost, so δcrit is the operating ceiling.

Case B, `disc < 0`, the tether is shorter than the sum of the radii:

The lines cannot reach the axis, so they cannot cross and there is no stability limit.
The geometry ends when the rings meet, at
`d_touch = acos((r_a² + r_b² − l_t²)/(2·r_a·r_b))`, which for equal radii is the identity
`2·asin(l_t/2r)`. Past that twist the rings cannot stay apart, so tether break strain and
ring compression carry the limit, and neither is a twist limit.

See `trpt_torque_capacity_axial` for the torque the segment can carry at its limit.
"""
function trpt_twist_limit(r_a::Real, r_b::Real, l_t::Real)
    r_a > 0 || throw(ArgumentError("ring radius r_a must be positive, got $r_a"))
    r_b > 0 || throw(ArgumentError("ring radius r_b must be positive, got $r_b"))
    l_t > 0 || throw(ArgumentError("tether length l_t must be positive, got $l_t"))
    # A tether spans at least the smallest distance between its two attachment points,
    # which is the ring radius difference. A shorter one is a units error upstream.
    l_min = abs(r_a - r_b)
    l_t >= l_min || throw(
        ArgumentError(
            "tether length l_t = $l_t m is shorter than the ring radius difference " *
            "$l_min m; no twist can span that geometry",
        ),
    )

    # Factored discriminant: disc < 0 is exactly l_t < r_a + r_b.
    disc = (l_t^2 - (r_a + r_b)^2) * (l_t^2 - (r_a - r_b)^2)
    c_mid = (r_a^2 + r_b^2 - l_t^2) / (2 * r_a * r_b)

    if disc < 0
        d_touch = acos(clamp(c_mid, -1.0, 1.0))   # |c_mid| ≤ 1 follows from l_min ≤ l_t < r_a+r_b
        return (
            has_limit=false,
            dcrit=NaN,
            dcrit_deg=NaN,
            sin_dcrit=NaN,
            l_ax_dcrit=NaN,
            disc=disc,
            d_touch=d_touch,
            d_touch_deg=rad2deg(d_touch),
            r_a=float(r_a),
            r_b=float(r_b),
            l_t=float(l_t),
        )
    end

    c = (r_a^2 + r_b^2 - l_t^2 + sqrt(disc)) / (2 * r_a * r_b)
    dcrit = acos(clamp(c, -1.0, 1.0))
    # (4.28) rearranged: the ring separation that pairs with this twist.
    l_ax = sqrt(max(l_t^2 - r_a^2 - r_b^2 + 2 * r_a * r_b * cos(dcrit), 0.0))
    return (
        has_limit=true,
        dcrit=dcrit,
        dcrit_deg=rad2deg(dcrit),
        sin_dcrit=sin(dcrit),
        l_ax_dcrit=l_ax,
        disc=disc,
        d_touch=NaN,                              # the lines reach the axis at 180° first
        d_touch_deg=NaN,
        r_a=float(r_a),
        r_b=float(r_b),
        l_t=float(l_t),
    )
end

"""
    trpt_torque_capacity_axial(lim, F_axial) -> Float64

The most torque a TRPT segment can transmit, in N·m, when its **total axial force** is
`F_axial` newtons. This is the peak of Tulloch's operating curve (Figs 5.25–5.27).

    τ_max = F_axial · r_a · r_b · sin(δcrit) / L_ax(δcrit)      (4.31 at δcrit)
          = F_axial · ( √(l_t² − (r_a−r_b)²) − √(l_t² − (r_a+r_b)²) ) / 2

The second line is the first with (4.34) substituted. Use it. The first is 0/0 exactly
where `l_t = r_a + r_b`, which is the ϕ = 2 boundary and a live design corner: the belt
of regions a gene can sit in, and the old `target_L/r` seed sat at exactly 2.0. The
factored form is finite everywhere in Case A and returns `F_axial·√(r_a·r_b)` at the
boundary, which is the limit of the first form.

Checks against the thesis: Fig 5.25 (r = 0.4 m, l_t = 1 m) returns 0.2 N·m per newton,
so 100 N·m at his 500 N. The live seed's segment 9 (r = 0.575 m, l_t = 1.60 m) returns
0.24379 N·m per newton. Both are asserted in the test suite, against a numerical maximum
of the curve, not against this formula.

A cap at this value never bites below δcrit, because it is the maximum of the curve that
δcrit belongs to. `trpt_torque_capacity_lines` used to offer the same torque expressed in
the line tension at the limit, and a caller multiplied it by the tension at a *smaller*
twist, which caps a ϕ = 2.01 bay at a third of its capacity. The tension basis is gone.

Returns `Inf` when `lim.has_limit` is `false`: a segment with no over-twist limit has no
torque ceiling, and its real limit is tether break strain.
"""
function trpt_torque_capacity_axial(lim::NamedTuple, F_axial::Real)
    lim.has_limit || return Inf
    # P < 0 in Case B, so this branch is the only one that may evaluate it.
    P = lim.l_t^2 - (lim.r_a + lim.r_b)^2
    Q = lim.l_t^2 - (lim.r_a - lim.r_b)^2
    return F_axial * (sqrt(Q) - sqrt(max(P, 0.0))) / 2
end

"""
    trpt_axial_force(T_lines, l_t, l_ax) -> Float64

The axial force a segment carries, in newtons, from the state the ODE actually has:
the sum of its line tensions `T_lines`, its tether length `l_t`, and its current ring
separation `l_ax`, all in SI.

    F_axial = T_lines · l_ax / l_t

This is the line-inclination projection, exact for a straight taut line. Reach for it
before `trpt_torque_capacity_axial` when the tension is a state variable. Never multiply
a capacity by a tension from a different twist: that is how the ϕ = 2 corner broke.
"""
trpt_axial_force(T_lines::Real, l_t::Real, l_ax::Real) = T_lines * l_ax / max(l_t, 1e-9)
