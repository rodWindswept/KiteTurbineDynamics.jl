# scratch/chain_fix_probe.jl
#
# Attempts to get the lift chain TAUT by replacing the seven link rest lengths
# with values derived from the measured operating geometry, WITHOUT touching src/.
#
# The bug: `bridle_L0` is computed in the builder from `bearing_offset = 6.0`, a
# placeholder carried over from other tested systems (Rod 2026-09-12).  The
# bearing's axial design point was never chosen.  The measured operating geometry
# is ~3.99 m axial / ~4.66 m bridle 3D.
#
# Method:
#   1. build + settle normally; measure the ACTUAL bridle 3D length and cyan length
#      at the operating point
#   2. replace the 6 bridle and 1 cyan rest lengths with values taken from that
#      geometry, so they are taut there instead of slack by 1.8 m
#   3. re-settle and report chain tensions plus the guard quantities V2/V3/V6
#
#   scripts/ktd-julia scratch/chain_fix_probe.jl

using KiteTurbineDynamics, LinearAlgebra, Printf, Statistics
using KiteTurbineDynamics: RopeSubSegment
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function is_bridle(ss, sys)
    na, nb = ss.end_a.node_id, ss.end_b.node_id
    h, b = sys.rotor.node_id, sys.bearing_id
    return (na == h && nb == b) || (na == b && nb == h)
end

function is_cyan(ss, sys)
    na, nb = ss.end_a.node_id, ss.end_b.node_id
    b, s = sys.bearing_id, sys.sky_anchor_id
    return (na == b && nb == s) || (na == s && nb == b)
end

"True 3D lengths of the six bridles: bearing centre -> main-rotor attachment vertex."
function bridle_lengths(u, sys, p, N, Nr)
    hub, bear = sys.rotor.node_id, sys.bearing_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    Ls = Float64[]
    for ss in sys.sub_segs
        is_bridle(ss, sys) || continue
        re = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], re.line_idx, p.n_lines, pp1, pp2)
        push!(Ls, norm(pos(u, bear) .- pa))
    end
    return Ls
end

function link_report(u, sys, p, N, Nr, sd)
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    Ls = bridle_lengths(u, sys, p, N, Nr)
    Tb = 0.0
    restb = Float64[]
    for ss in sys.sub_segs
        is_bridle(ss, sys) || continue
        push!(restb, ss.length_0)
        Tb += ss.EA * max(0.0, (Ls[1] - ss.length_0) / ss.length_0)
    end
    Tc = 0.0
    restc = 0.0
    Lc = norm(pos(u, sky) .- pos(u, bear))
    for ss in sys.sub_segs
        is_cyan(ss, sys) || continue
        restc = ss.length_0
        Tc = ss.EA * max(0.0, (Lc - ss.length_0) / ss.length_0)
    end
    d_ax = dot(pos(u, bear) .- pos(u, hub), sd)
    dperp = norm((pos(u, bear) .- pos(u, hub)) .- d_ax .* sd)
    m = 1.0
    return (bridle_L=mean(Ls), bridle_rest=mean(restb), bridle_T=Tb,
            cyan_L=Lc, cyan_rest=restc, cyan_T=Tc, d_ax=d_ax, dperp=dperp)
end

function residuals(u, sys, p, wf, lift, N, sd)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    res = Float64[]
    for gid in (sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id)
        m = (sys.nodes[gid]).mass
        push!(res, dot(m .* du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)], sd))
    end
    acc = maximum(norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
    return res, acc
end

function set_link_lengths!(sys, bridle_L0, cyan_L0)
    newsegs = RopeSubSegment[]
    for ss in sys.sub_segs
        if is_bridle(ss, sys) && bridle_L0 !== nothing
            push!(newsegs, RopeSubSegment(ss.end_a, ss.end_b, bridle_L0,
                ss.EA, ss.c_damp, ss.diameter))
        elseif is_cyan(ss, sys) && cyan_L0 !== nothing
            push!(newsegs, RopeSubSegment(ss.end_a, ss.end_b, cyan_L0,
                ss.EA, ss.c_damp, ss.diameter))
        else
            push!(newsegs, ss)
        end
    end
    sys.sub_segs[:] = newsegs
    return sys
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub = sys.rotor.node_id
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    u1 = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)
    sd1 = normalize(pos(u1, hub))
    L1 = link_report(u1, sys, p, N, Nr, sd1)
    r1, a1 = residuals(u1, sys, p, wf, lift, N, sd1)
    @printf("BEFORE (placeholder 6.0 m offset)\n")
    @printf("  bridle L=%.6f rest=%.6f T=%.4f N | cyan L=%.6f rest=%.6f T=%.3f N\n",
        L1.bridle_L, L1.bridle_rest, L1.bridle_T, L1.cyan_L, L1.cyan_rest, L1.cyan_T)
    @printf("  bearing offset axial=%.4f perp=%.4f m\n", L1.d_ax, L1.dperp)
    @printf("  residuals hub=%+.2f bearing=%+.2f sky=%+.2f | max acc=%.1f m/s2\n\n",
        r1[1], r1[2], r1[3], a1)

    @printf("operating geometry taken as the target: bridle 3D = %.6f m, cyan = %.6f m\n\n",
        L1.bridle_L, L1.cyan_L)

    println("AFTER setting the BRIDLE 3D rest length (not the centre distance):")
    for rest in (4.40, 4.50, 4.60, 4.658, 4.70, 4.80)
        sys2, u02, p2, lift2, wf2 = build_case(nothing, nothing)
        set_link_lengths!(sys2, rest, nothing)
        u2 = settle_to_operational_state(sys2, u02, p2, 60.0;
            lift_device=lift2, wind_fn=wf2, n_op=2_000)
        sd2 = normalize(pos(u2, sys2.rotor.node_id))
        L2 = link_report(u2, sys2, p2, N, Nr, sd2)
        r2, a2 = residuals(u2, sys2, p2, wf2, lift2, N, sd2)
        @printf("  rest=%.4f bridle T=%10.3f N (achieved %.6f) cyan T=%8.3f d_ax=%+.4f resid hub=%+9.2f bear=%+9.2f sky=%+9.2f acc=%9.1f\n",
            rest, L2.bridle_T, L2.bridle_L, L2.cyan_T, L2.d_ax,
            r2[1], r2[2], r2[3], a2)
    end
    println()
    @printf("lift requirement (1.5 x airborne weight) = %.3f N vertical\n",
        1.5 * expansion_airborne_mass(sys, p; include_lifter=false) * 9.81)
end

main()
