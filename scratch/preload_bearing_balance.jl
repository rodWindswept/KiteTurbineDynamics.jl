# scratch/preload_bearing_balance.jl
#
# READ-ONLY. Tests whether the lift chain can carry the top rotor at all with the
# bridle and cyan rest lengths AS BUILT, by sweeping the lift bearing's position
# along the shaft axis and measuring, at each position:
#
#   - total bridle tension (bearing -> topmost ring, 6 equal-length lines)
#   - cyan line tension (sky anchor -> bearing)
#   - the axial net force on hub, bearing and sky anchor
#
# The TRPT column is a tensegrity structure: its form follows the tension balance
# (Rod, 2026-09-12).  The bearing's position is therefore not prescribed -- it is
# wherever the chain balances.  The bridle rest lengths are FIXED (equal, set once);
# only the positions respond.  The question this answers: is there a bearing
# position where the chain balances AND the bridles carry load?
#
# The bridle length used is the true 3D distance from the bearing to the ring-end
# attachment vertex (the ring end is a ring vertex, not the ring centre), so this
# measures the same quantity the ODE's sub-segment does.
#
#   scripts/ktd-julia scratch/preload_bearing_balance.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

# true bridle length: bearing centre -> hub attachment vertex, using the hub's
# tilted ring basis exactly as `get_segment_tension` does
function bridle_len(u, sys, p, N, Nr)
    hub, bear = sys.rotor.node_id, sys.bearing_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    α = u[6N + node.ring_idx]
    L = 0.0
    n = 0
    for j in 1:p.n_lines
        pa = attachment_point(pos(u, hub), R, α, j, p.n_lines, pp1, pp2)
        L += norm(pa .- pos(u, bear))
        n += 1
    end
    return L / n, n
end

function chain_tensions(u, sys, p, N, Nr)
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    Lb, nb = bridle_len(u, sys, p, N, Nr)
    # bridle rest length from the build
    rest = 0.0
    for ss in sys.sub_segs
        na, nbb = ss.end_a.node_id, ss.end_b.node_id
        if (na == hub && nbb == bear) || (na == bear && nbb == hub)
            rest = ss.length_0
            break
        end
    end
    Tb = 0.0
    for ss in sys.sub_segs
        na, nbb = ss.end_a.node_id, ss.end_b.node_id
        if (na == hub && nbb == bear) || (na == bear && nbb == hub)
            Tb += ss.EA * max(0.0, (Lb - ss.length_0) / ss.length_0)
        end
    end
    cyan = 0.0
    for ss in sys.sub_segs
        na, nbb = ss.end_a.node_id, ss.end_b.node_id
        if (na == bear && nbb == sky) || (na == sky && nbb == bear)
            L = norm(pos(u, sky) .- pos(u, bear))
            cyan = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
        end
    end
    return Tb, nb, rest, Lb, cyan
end

function net_axial(u, sys, p, wf, lift, N, sd)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    out = Float64[]
    for gid in (sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id)
        m = (sys.nodes[gid]).mass
        push!(out, dot(m .* du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)], sd))
    end
    return out
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id

    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    sd = normalize(pos(u, hub))
    hub_pos = pos(u, hub)
    base_bear = pos(u, bear)

    Tb0, nb, rest, Lb0, _ = chain_tensions(u, sys, p, N, Nr)
    @printf("kite mass = %.3f kg   m_airborne(no lifter) = %.3f kg\n",
        sys.kite.mass, expansion_airborne_mass(sys, p; include_lifter=false))
    @printf("bridle: %d lines, rest length = %.6f m\n", nb, rest)
    r_ax = dot(base_bear .- hub_pos, sd)
    r_perp = norm((base_bear .- hub_pos) .- r_ax .* sd)
    @printf("settled bearing offset from hub: axial=%.4f m  perp=%.4f m  |d|=%.4f m  T=%.4f N\n\n",
        r_ax, r_perp, Lb0, Tb0)

    println("sweep bearing position along +shaft from the hub (sky held 5 m beyond):")
    @printf("  %8s %10s %10s %12s %12s %12s %12s %12s\n",
        "d_axial", "|hub-bear|", "bridleT", "cyanT", "hub_ax", "bear_ax", "sky_ax", "bridles")

    for d_ax in (4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0)
        uu = copy(u)
        new_bear = hub_pos .+ d_ax .* sd
        new_sky = new_bear .+ 5.0 .* sd
        uu[(3 * (bear - 1) + 1):(3 * bear)] .= new_bear
        uu[(3 * (sky - 1) + 1):(3 * sky)] .= new_sky
        uu[(3N + 1):6N] .= 0.0
        Tb, _, _, Lb, c = chain_tensions(uu, sys, p, N, Nr)
        ax = net_axial(uu, sys, p, wf, lift, N, sd)
        @printf("  %8.3f %10.4f %10.4f %12.3f %+12.3f %+12.3f %+12.3f %12s\n",
            d_ax, norm(new_bear .- hub_pos), Lb, c, ax[1], ax[2], ax[3],
            Tb > 1.0 ? "TAUT" : "slack")
    end
    println()
end

main()
