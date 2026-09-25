# src/trpt_twist_limit.jl — the TRPT over-twist authority (2026-09-25)
#
# ONE authority for how far a TRPT segment can twist. Every gate, floor, refusal,
# controller margin and optimiser capacity reads this function. Four copies of a
# mis-derived criterion is how the repo lost its footing against the thesis.
#
# Source: Oliver Tulloch, PhD thesis, University of Strathclyde (2021).
#   (4.34)/(5.4)  the critical deformation angle δcrit
#   (4.28)–(4.31) the chord, the ring separation and the transmitted torque
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
- `sin_dcrit` — `sin(δcrit)`, for capacity arithmetic. NaN when there is no limit.
- `l_ax_dcrit` — the ring separation at the limit, in metres. NaN when there is no limit.
- `disc` — the discriminant `(l_t² − (r_a+r_b)²)(l_t² − (r_a−r_b)²)`. Its sign splits the
  two cases, and `disc ≥ 0` is exactly `l_t ≥ r_a + r_b`.
- `d_touch`, `d_touch_deg` — the twist at which the rings meet, valid when there is no
  limit. NaN when there is one, because then the lines reach the axis at 180° first.

Case A, `disc ≥ 0`, the tether spans at least the sum of the two radii:

    cos δcrit = [ r_a² + r_b² − l_t² + √disc ] / (2·r_a·r_b)          (4.34)

The `+` root is the torque maximum and always lies in [−1, 1] here. The maximum is a
maximum of the operating curve in `trpt_torque_capacity_axial`, which holds the axial
force and lets the rings contract. Past δcrit the deformation runs away and the
equilibrium is lost, so δcrit is the operating ceiling.

Case B, `disc < 0`, the tether is shorter than the sum of the radii:

The lines cannot reach the axis, so they cannot cross and there is no stability limit.
The geometry ends when the rings meet, at
`d_touch = acos((r_a² + r_b² − l_t²)/(2·r_a·r_b))`, which for equal radii is the identity
`2·asin(l_t/2r)`. Past that twist the rings cannot stay apart, so tether break strain and
ring compression carry the limit, and neither is a twist limit.

See `trpt_torque_capacity_axial` and `trpt_torque_capacity_lines` for the torque a segment
transmits at its limit. They differ in which quantity the caller holds, not in physics.
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

The torque a TRPT segment transmits at its over-twist limit, in N·m, when the caller
holds the **total axial force** the segment carries (`F_axial`, in newtons — the repo's
cumulative thrust above the segment).

    τ_max = F_axial · r_a · r_b · sin(δcrit) / L_ax(δcrit)      (4.31 at δcrit)

The rings contract as the twist grows, so the separation at the limit is the contracted
one. This is the form of Tulloch's own torque-against-twist curves (Figs 5.25–5.27) and
it reproduces them: the Fig 5.25 geometry (r = 0.4 m, l_t = 1 m) gives 0.2 N·m per
newton, so 100 N·m at his 500 N.

Returns `Inf` when `lim.has_limit` is `false`: a segment with no over-twist limit has no
torque ceiling, and its real limit is tether break strain.
"""
function trpt_torque_capacity_axial(lim::NamedTuple, F_axial::Real)
    lim.has_limit || return Inf
    return F_axial * lim.r_a * lim.r_b * lim.sin_dcrit / lim.l_ax_dcrit
end

"""
    trpt_torque_capacity_lines(lim, T_lines) -> Float64

The torque a TRPT segment transmits at its over-twist limit, in N·m, when the caller holds
the **sum of the line tensions** in the segment (`T_lines`, in newtons — the repo's
`seg_tension`).

    τ_max = T_lines · r_a · r_b · sin(δcrit) / l_t              (4.31 at δcrit)

This is the same torque as `trpt_torque_capacity_axial`, because the two held quantities
relate by the line inclination: `T_lines = F_axial · l_t / L_ax`. Reach for this one when
the tension is a state variable, as it is in the ODE.

Returns `Inf` when `lim.has_limit` is `false`.
"""
function trpt_torque_capacity_lines(lim::NamedTuple, T_lines::Real)
    lim.has_limit || return Inf
    return T_lines * lim.r_a * lim.r_b * lim.sin_dcrit / lim.l_t
end
