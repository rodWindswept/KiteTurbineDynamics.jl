# scratch/assembly_force_audit.jl
#
# READ-ONLY. After the relaxation trial showed a resting state exists, this checks
# the whole-assembly vertical force balance, which decides where the lift surplus
# goes.
#
# The question: lift delivers 1.5 x airborne weight = 431 N vertical, the airborne
# weight is 288 N.  The surplus must be reacted by SOMETHING or the assembly rises.
# The only candidate is the backline, which Rod describes as the altitude limiter.
# This measures it.
#
# Reports, at the relaxed state:
#   - total vertical force on every node (should be ~0 at equilibrium)
#   - the backline tension and its vertical component
#   - the lift actually applied at the sky anchor
#   - per-node acceleration, to see whether the residual is concentrated in the
#     light bearing/sky nodes
#
#   scripts/ktd-julia scratch/assembly_force_audit.jl

using KiteTurbineDynamics, LinearAlgebra, Printf, Statistics
using KiteTurbineDynamics: RopeSubSegment
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function set_bridle_length!(sys, L0)
    newsegs = RopeSubSegment[]
    h, b = sys.rotor.node_id, sys.bearing_id
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        if (na == h && nb == b) || (na == b && nb == h)
            push!(newsegs, RopeSubSegment(ss.end_a, ss.end_b, L0, ss.EA, ss.c_damp, ss.diameter))
        else
            push!(newsegs, ss)
        end
    end
    sys.sub_segs[:] = newsegs
end

function damp_translations!(u, sys, N, rate)
    for gid in 2:N
        b = 3N + 3 * (gid - 1) + 1
        for k in 0:2
            u[b + k] *= rate
        end
    end
end

function relax(sys, p, u0, lift, wf, N, Nr; omega_eq, max_iter=400_000, tol=0.5, damp=0.99)
    u = copy(u0)
    du = zeros(length(u))
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    for it in 1:max_iter
        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]
        damp_translations!(u, sys, N, damp)
        u[(6N + Nr + 1):(6N + 2Nr)] .= omega_eq
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0
        lift === nothing || KiteTurbineDynamics.update_kite_pos!(sys, u, lift, p, dt)
        if it % 20_000 == 0
            fill!(du, 0.0)
            KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
            amax = maximum(norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
            amax < tol && break
        end
    end
    return u
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    omega_eq = 12.983466

    set_bridle_length!(sys, 5.2)     # the most-loaded bridle case from the sweep
    us = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    for k in 1:Nr
        us[6N + Nr + k] = omega_eq
    end
    u = relax(sys, p, us, lift, wf, N, Nr; omega_eq=omega_eq)

    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)

    @printf("relaxed state, bridle rest = 5.2 m\n")
    @printf("  hub |r|=%.4f bearing |r|=%.4f sky |r|=%.4f\n\n",
        norm(pos(u, hub)), norm(pos(u, bear)), norm(pos(u, sky)))

    # per-node masses and z-accelerations
    m = Float64[]
    az = Float64[]
    for gid in 1:N
        mm = (sys.nodes[gid]).mass
        push!(m, mm)
        push!(az, du[(3N + 3 * (gid - 1) + 3)])
    end
    @printf("total vertical force over all nodes = %+.6f N  (sum m*az)\n",
        sum(m .* az))
    @printf("total airborne mass                 = %.4f kg\n", sum(m))
    @printf("total weight (down)                 = %.4f N\n", sum(m) * 9.81)

    # biggest offenders
    idx = sortperm(abs.(m .* az); rev=true)[1:6]
    @printf("\nlargest per-node vertical imbalance:\n")
    for i in idx
        @printf("  node %3d %-14s mass=%8.4f kg  m*az=%+10.4f N  az=%+12.2f m/s2\n",
            i, string(typeof(sys.nodes[i])), m[i], m[i] * az[i], az[i])
    end

    # the lift as the ODE applies it
    ldir = sys.kite_pos .- pos(u, sky)
    @printf("\n|kite-sky| = %.6f (line %.4f)\n", norm(ldir), lift.line_length)
    _, T_lift, el = lift_force_steady(lift, p.rho, norm(wf(pos(u, sky), 0.0)), p)
    @printf("lift force applied = %.3f N along [%.4f %.4f %.4f]\n",
        T_lift, (ldir ./ norm(ldir))...)
    @printf("  vertical component = %.3f N\n", T_lift * ldir[3] / norm(ldir))

    # backline: recompute as ring_forces does
    ba = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    s = pos(u, sky)
    b_dx = sqrt((s[1] - ba)^2 + s[2]^2)
    b_dz = s[3]
    Lax = p.tether_length + 6.0 + 5.0
    bL0 = sqrt((Lax * cos(p.elevation_angle) - ba)^2 + (Lax * sin(p.elevation_angle))^2) +
          p.backline_payout
    bd = sqrt(b_dx^2 + b_dz^2)
    @printf("\nbackline: distance=%.4f rest=%.4f -> %s by %.4f m\n",
        bd, bL0, bd > bL0 ? "TAUT" : "SLACK", abs(bd - bL0))
end

main()
