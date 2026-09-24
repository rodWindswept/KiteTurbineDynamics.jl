# scratch/diag_cyan_after_bungee.jl
#
# 2026-09-16.  Why does `test_settle_validity.jl` now read T_cyan = 0.0 after the
# bi-linear back line landed?
#
# Rod's correction (2026-09-16): the back line can only RESTRAIN the sky anchor
# from rising beyond the sphere (centred on the ground anchor, radius = trimmed
# length).  It cannot lift the anchor.  So the cyan line going slack cannot be
# caused by the back line "lifting" anything, and this probe measures the actual
# geometry rather than assuming a mechanism.
#
# Reports, for the test's own build_case AND the L/r 1.5 candidate:
#   cyan span vs the 5.0 m cut length, the cyan sub-segment rest lengths, and the
#   back-line state, vs n_op.
#
# Self-checking: asserts finite geometry, and that the cyan tension is consistent
# with span vs the line's own rest length.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function cyan_state(u, sys)
    total = 0.0
    span = NaN
    L0s = Float64[]
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (
            (na == sys.sky_anchor_id && nb == sys.bearing_id) ||
            (na == sys.bearing_id && nb == sys.sky_anchor_id)
        ) || continue
        L = norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
        push!(L0s, ss.length_0)
        span = L
        total += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return total, span, L0s
end

function back_state(u, sys, p)
    sh = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]
    r_top = (sys.nodes[sys.rotor.node_id]::RingNode).radius
    b_off = KiteTurbineDynamics.bridle_bearing_offset(r_top)
    design_sky = (p.tether_length + b_off + KiteTurbineDynamics.CYAN_L0_DESIGN) .* sh
    sky_p = pos(u, sys.sky_anchor_id)
    back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    b_dx = sqrt((sky_p[1] - back_ax)^2 + sky_p[2]^2)
    b_dz = sky_p[3]
    b_dist = sqrt(b_dx^2 + b_dz^2)
    L0 = norm(design_sky - [back_ax, 0.0, 0.0])
    # Version-tolerant: the bi-linear element only exists after 2026-09-16, so a
    # stashed (baseline) tree has no `back_line_tension`. Fall back to the old
    # tension-only catenary test so the same probe measures both trees.
    T_back = if isdefined(KiteTurbineDynamics, :back_line_tension)
        KiteTurbineDynamics.back_line_tension(b_dist, L0, p.backline_payout, p.EA_back_line)
    else
        if b_dist > L0 + p.backline_payout + 1e-6
            p.EA_back_line * (b_dist - L0 - p.backline_payout) / L0
        else
            0.0
        end
    end
    return T_back, b_dist, L0, norm(sky_p .- design_sky)
end

println("=== cyan state vs n_op ===")
for (label, sysb) in (("test build_case", build_case(nothing, nothing)),)
    sys, u0, p, lift, wf = sysb
    println("\n  [", label, "]  EA_back_line=", p.EA_back_line, " N  n_rings=", sys.n_ring)
    for n_op in (2_000, 20_000, 100_000)
        u = settle_to_operational_state(
            sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=n_op
        )
        T_cy, span, L0s = cyan_state(u, sys)
        T_bk, b_dist, b_L0, sky_off = back_state(u, sys, p)
        @assert isfinite(span) && span > 0.0
        @assert all(>(0.0), L0s)
        println(
            "    n_op=",
            lpad(n_op, 7),
            "  cyan_span=",
            round(span; digits=5),
            "  cyan_L0=",
            if length(L0s) == 1
                round(L0s[1]; digits=5)
            else
                string(minimum(L0s), "..", maximum(L0s))
            end,
            "  span-L0=",
            lpad(round(span - minimum(L0s); digits=6), 9),
            "  T_cyan=",
            lpad(round(T_cy; digits=3), 9),
            "  T_back=",
            lpad(round(T_bk; digits=1), 8),
            "  sky_off=",
            round(sky_off; digits=3),
        )
    end
end
println("\n=== done ===")
