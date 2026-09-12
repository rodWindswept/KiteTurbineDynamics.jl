# scratch/preload_chain_search.jl
#
# READ-ONLY. Rod (2026-09-12): "I don't think I chose a length yet along the axis
# for the bearing design point to guide the lifting bridle lengths... I think this
# came from an approximation of the other tested systems."
#
# So `bearing_offset = 6.0` (initialization.jl:166) and hence the bridle rest
# length (6.462198 m) are placeholders, and the settled chain is slack against
# them.  The physical constraint is the opposite direction: the bridles, cyan line
# and backline are fixed lengths on a real machine, and the operating position is
# wherever the tension balance puts them -- with the lift chain TAUT and carrying.
#
# This searches for that balance.  For each candidate lift-line elevation it places
# the kite at sky_anchor + L_line * lift_dir, re-runs the settle, and reports:
#   - the three chain tensions (bridle total, cyan, and whether the backline is taut)
#   - the bearing's axial offset from the hub that results
#   - the hub axial residual
#
# A configuration with bridle tension > 0 is one where the lift actually reaches
# the rotor.
#
#   scripts/ktd-julia scratch/preload_chain_search.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function chain_report(u, sys::KiteTurbineSystem, p, N, Nr)
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    # bridle: mean true 3D length, bearing centre -> hub attachment vertex
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    Lb = 0.0
    for j in 1:p.n_lines
        pa = attachment_point(pos(u, hub), R, u[6N + node.ring_idx], j, p.n_lines, pp1, pp2)
        Lb += norm(pa .- pos(u, bear))
    end
    Lb /= p.n_lines
    rest = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        if (na == hub && nb == bear) || (na == bear && nb == hub)
            rest = ss.length_0
            break
        end
    end
    Tb = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        if (na == hub && nb == bear) || (na == bear && nb == hub)
            Tb += ss.EA * max(0.0, (Lb - ss.length_0) / ss.length_0)
        end
    end
    Tc = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        if (na == bear && nb == sky) || (na == sky && nb == bear)
            L = norm(pos(u, sky) .- pos(u, bear))
            Tc = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        end
    end
    # backline tautness
    ba = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    Lax = p.tether_length + 6.0 + 5.0
    bL0 = sqrt((Lax * cos(p.elevation_angle) - ba)^2 + (Lax * sin(p.elevation_angle))^2) +
          p.backline_payout
    s = pos(u, sky)
    bd = sqrt((s[1] - ba)^2 + s[2]^2 + s[3]^2)
    d_ax = dot(pos(u, bear) .- pos(u, hub), normalize(pos(u, hub)))
    return Tb, rest, Lb, Tc, bd - bL0, d_ax
end

function main()
    sysb, u0b, pb, liftb, wfb = build_case(nothing, nothing)
    N, Nr = sysb.n_total, sysb.n_ring
    hub = sysb.rotor.node_id

    @printf("bridle rest length (from bearing_offset=6.0) = %.6f m\n", sysb.sub_segs[193].length_0)
    @printf("lift line length = %.3f m   lifter_elevation = %.1f deg (p)\n\n",
        liftb.line_length, rad2deg(pb.lifter_elevation))

    println("sweep lift-line elevation (kite placed at sky + L*dir before settle):")
    @printf("  %7s %12s %12s %12s %12s %12s %12s\n",
        "elev", "bridleT_N", "|hub-bear|", "cyanT_N", "backline", "d_axial", "hub_resid")

    for elev_deg in (40.0, 50.0, 60.0, 70.0, 80.0, 90.0)
        p = override_params(pb; lifter_elevation=deg2rad(elev_deg))
        # rebuild with the overridden lifter elevation
        sys, u0, pc, lift, wf = build_case(nothing, nothing)
        # re-place the kite at the new elevation from the initial sky anchor
        sky0 = pos(u0, sys.sky_anchor_id)
        sys.kite_pos .= sky0 .+
                        lift.line_length .*
                        [cos(deg2rad(elev_deg)), 0.0, sin(deg2rad(elev_deg))]
        u = settle_to_operational_state(sys, u0, pc, 60.0;
            lift_device=lift, wind_fn=wf, n_op=2_000)
        Tb, rest, Lb, Tc, back_margin, d_ax = chain_report(u, sys, pc, N, Nr)
        sd = normalize(pos(u, hub))
        du = zeros(length(u))
        KiteTurbineDynamics.multibody_ode!(du, u, (sys, pc, wf, lift), 0.0)
        m_hub = (sys.nodes[hub]::RingNode).mass
        f = m_hub * dot(du[(3N + 3 * (hub - 1) + 1):(3N + 3 * hub)], sd)
        @printf("  %7.1f %12.4f %12.6f %12.4f %+12.4f %12.4f %+12.4f\n",
            elev_deg, Tb, Lb, Tc, back_margin, d_ax, f)
    end
    println("\nbackline column = distance to rest length; negative = slack by that many m")
    println()
end

main()
