# scratch/assembly_relax_trial.jl
#
# TRIAL (Rod-approved 2026-09-12): instead of pinning the rings and running a
# fixed number of steps, relax the WHOLE airborne assembly until it is in force
# balance, and see whether a resting state exists at all.
#
# What changes vs the current settle:
#   - ring positions are NOT overwritten every step (they are free)
#   - translational velocities of all airborne nodes are damped (convergence aid,
#     standing in for the drag/hysteresis/gyroscopic dissipation the ODE lacks)
#   - the loop runs until the largest node acceleration is small, not for N steps
#
# The question that decides everything: the lift (1.5 * weight = 431 N) exceeds
# the total airborne weight (288 N).  With the backline SLACK nothing resists the
# surplus, so the machine should simply rise forever.  That would mean there is no
# resting state, and the backline -- an ALTITUDE LIMITER (Rod) -- is what is
# supposed to provide it.  So this trial runs both cases:
#     CASE A: backline exactly as built (measured slack by ~1 m)
#     CASE B: backline shortened to the taut length, so it can limit altitude
#
#   scripts/ktd-julia scratch/assembly_relax_trial.jl

using KiteTurbineDynamics, LinearAlgebra, Printf, Statistics
using KiteTurbineDynamics: RopeSubSegment
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

"Strong damping on the translational velocity of every node except the ground ring."
function damp_translations!(u, sys, N, rate)
    for gid in 2:N
        b = 3N + 3 * (gid - 1) + 1
        for k in 0:2
            u[b + k] *= rate
        end
    end
end

"Set the six bridle rest lengths in place (builder uses a placeholder)."
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

function chain_tensions(u, sys, p, N, Nr)
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)
    node = sys.nodes[hub]::RingNode
    R = isempty(sys.expansion_rotors) ? node.radius : sys.effective_radii[node.ring_idx]
    bridle = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == hub && nb == bear) || (na == bear && nb == hub)) || continue
        re = ss.end_a.is_ring ? ss.end_a : ss.end_b
        pa = attachment_point(pos(u, hub), R, u[6N + Nr], re.line_idx, p.n_lines, pp1, pp2)
        L = norm(pos(u, bear) .- pa)
        bridle += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    cyan = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        ((na == bear && nb == sky) || (na == sky && nb == bear)) || continue
        L = norm(pos(u, sky) .- pos(u, bear))
        cyan = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return bridle, cyan
end

"""
Relax the whole assembly.  Returns (u, converged, iters, history).
Ring twist stays pinned at omega_eq (we are solving the static/structural balance at
the operating speed, not re-deriving the operating point).
"""
function relax_assembly(sys, p, u0, lift, wf, N, Nr;
                        omega_eq, max_iter=200_000, tol=1.0, damp=0.90, report=20_000)
    u = copy(u0)
    du = zeros(length(u))
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    ode_params = (sys, p, wf, lift)
    hist = Tuple{Float64,Float64,Float64}[]
    converged = false
    for it in 1:max_iter
        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, u, ode_params, 0.0)
        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]
        damp_translations!(u, sys, N, damp)
        # keep the rotation at the operating point (this is a structural solve)
        u[(6N + Nr + 1):(6N + 2Nr)] .= omega_eq
        # ground ring fixed
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0
        lift === nothing || KiteTurbineDynamics.update_kite_pos!(sys, u, lift, p, dt)

        if it % report == 0 || it == 1
            fill!(du, 0.0)
            KiteTurbineDynamics.multibody_ode!(du, u, ode_params, 0.0)
            amax = maximum(norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
            sd = normalize(pos(u, sys.rotor.node_id))
            dz = dot(pos(u, sys.sky_anchor_id), sd)
            push!(hist, (Float64(it), amax, dz))
            amax < tol && (converged = true; break)
        end
    end
    return u, converged, length(hist), hist
end

function report_case(tag, sys, p, u, lift, wf, N, Nr, omega_eq, hist, converged)
    bridle, cyan = chain_tensions(u, sys, p, N, Nr)
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    sd = normalize(pos(u, hub))
    println("─"^96)
    @printf("%s   converged=%s\n", tag, converged)
    @printf("  iteration history (every report): ")
    for (it, amax, dz) in hist
        @printf("%d:%.1f ", round(Int, it), amax)
    end
    println()
    @printf("  bridle total T = %10.3f N   cyan T = %8.3f N\n", bridle, cyan)
    @printf("  hub |r|=%.4f  bearing |r|=%.4f  sky |r|=%.4f\n",
        norm(pos(u, hub)), norm(pos(u, bear)), norm(pos(u, sky)))
    @printf("  hub->bearing |d| = %.4f m (bridle rest %.6f)\n",
        norm(pos(u, bear) .- pos(u, hub)), 6.462198)
    @printf("  max node accel = %.4f m/s2\n",
        begin
            du = zeros(length(u))
            KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
            maximum(norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
        end)
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    omega_eq = 12.983466

    @printf("airborne weight   = %.7f kg  -> W = %.2f N\n",
        expansion_airborne_mass(sys, p; include_lifter=false),
        expansion_airborne_mass(sys, p; include_lifter=false) * 9.81)
    @printf("lift T_ref        = %.2f N ; vertical component = %.2f N (1.5 x W)\n",
        lift.T_ref, lift.T_ref * sind(70.0))

    # start from the equilibrium settle (rings at preload geometry)
    u_start = settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    for k in 1:Nr
        u_start[6N + Nr + k] = omega_eq
    end

    # Sweep the one real free parameter: the bridle rest length.
    println()
    @printf("  %9s %12s %12s %12s %12s %12s\n",
        "bridle_L0", "d_ax", "bridle_T", "cyan_T", "sky_r", "max_acc")
    for L0 in (5.2, 6.0, 6.2, 6.30, 6.35, 6.40, 6.4622)
        sysL, _, pL, liftL, wfL = build_case(nothing, nothing)
        set_bridle_length!(sysL, L0)
        us = KiteTurbineDynamics.settle_to_equilibrium(sysL, u0, pL; lift_device=liftL, wind_fn=wfL)
        for k in 1:Nr
            us[6N + Nr + k] = omega_eq
        end
        uL, cL, _, hL = relax_assembly(sysL, pL, us, liftL, wfL, N, Nr;
            omega_eq=omega_eq, max_iter=400_000, tol=0.5, damp=0.99, report=400_000)
        bT, cT = chain_tensions(uL, sysL, pL, N, Nr)
        sdL = normalize(pos(uL, sysL.rotor.node_id))
        d_ax = dot(pos(uL, sysL.bearing_id) .- pos(uL, sysL.rotor.node_id), sdL)
        duL = zeros(length(uL))
        KiteTurbineDynamics.multibody_ode!(duL, uL, (sysL, pL, wfL, liftL), 0.0)
        aL = maximum(norm(duL[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
        @printf("  %9.4f %12.4f %12.3f %12.3f %12.4f %12.2f\n",
            L0, d_ax, bT, cT, norm(pos(uL, sysL.sky_anchor_id)), aL)
        if get(ENV, "KTD_TRACE", "") != ""
            for (it, am, dz) in hL
                @printf("        it=%7d amax=%10.3f sky_axial=%9.4f\n", round(Int, it), am, dz)
            end
        end
    end
    @printf("\nlift requirement (1.5 x W) = %.2f N vertical ; each bridle then carries T/(6*cos(31deg))\n",
        lift.T_ref * sind(70.0))
    return
    # CASE B: shorten the backline so it is taut at the initial sky position.
    # The backline rest length is design + payout; the ODE recomputes it from
    # constants, so here we move the sky anchor DOWN onto the taut radius instead:
    # easier and equivalent for the "is there a resting state" question is to
    # shorten payout below zero.  We rebuild p with a negative payout.
    println("\n(backline rest length is fixed in the ODE; testing via payout)")
    ba = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    Lax = p.tether_length + 6.0 + 5.0
    bL0 = sqrt((Lax * cos(p.elevation_angle) - ba)^2 + (Lax * sin(p.elevation_angle))^2)
    @printf("backline design rest = %.4f m + payout %.4f\n", bL0, p.backline_payout)
    # sky anchor must sit at radius bL0 from the back anchor for it to be taut
    @printf("(taut sky radius from origin ~ %.3f m along the shaft)\n", bL0)
end

main()
