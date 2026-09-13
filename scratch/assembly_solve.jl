# scratch/assembly_solve.jl
#
# Whole-assembly settle solve (Rod-approved rebuild).  Replaces the old
# pin-the-rings-then-drift settle.
#
# Method: dynamic relaxation of every airborne node with the aerodynamic state
# FROZEN (omega held at the operating point, kite held at its equilibrium offset).
# Freezing the aerodynamics is what separates the structural solve from the
# aeroelastic time-marching: it removes the long-period aero feedback, which is
# the slow part.
#
# Three accelerations of convergence, none of which change the equilibrium (the
# static solution is a force balance, independent of mass, damping or path):
#
#   1. KINETIC-ENERGY ADAPTIVE DAMPING (dynamic relaxation, Otter/Day).
#      Scale velocities by a factor chosen from the change in kinetic energy:
#      if KE rose this step the state is diverging from the minimum, so damp hard;
#      if it fell we are descending, so damp lightly and let it roll.
#   2. MASS SCALING on the light free nodes only (bearing, sky anchor).  A 0.3 kg
#      node on a 500 kN/m line sets a timestep we then have to run 2M times.  The
#      equilibrium is unchanged by mass; only the path changes.  This is a
#      convergence device, NOT physics.
#   3. NO PINNING of ring positions.
#
#   scripts/ktd-julia scratch/assembly_solve.jl            # default run
#   KTD_ITERS=5000000 KTD_MS=100 scripts/ktd-julia scratch/assembly_solve.jl

using KiteTurbineDynamics, LinearAlgebra, Printf, Statistics
using KiteTurbineDynamics: RopeSubSegment
include(joinpath(@__DIR__, "..", "test", "test_settle_preload_consistency.jl"))

const NODE1_IS_ANCHOR = 1     # node 1 = ground ring, deliberate 1e30 kg fix

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

"Scale the translational mass of the light free nodes (equilibrium is unchanged)."
function mass_scale_nodes!(sys, factor)
    factor == 1.0 && return sys
    for gid in 1:sys.n_total
        gid == NODE1_IS_ANCHOR && continue
        nd = sys.nodes[gid]
        if nd isa BearingNode || nd isa SkyAnchorNode
            if nd isa BearingNode
                sys.nodes[gid] = BearingNode(nd.id, nd.mass * factor)
            else
                sys.nodes[gid] = SkyAnchorNode(nd.id, nd.mass * factor)
            end
        end
    end
    return sys
end

function set_bridle_length!(sys, L0)
    L0 === nothing && return sys
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
    return sys
end

"Net force residual per node (mass x acceleration)."
function residual(u, sys, p, wf, lift, N)
    du = zeros(length(u))
    KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    return [ (sys.nodes[g]).mass .* du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)] for g in 1:N ], du
end

"""
Dynamic relaxation with kinetic-energy adaptive damping.
`beta` is the velocity scale; it is adapted so the total kinetic energy decreases
monotonically (Day's scheme).
"""
function relax!(u, sys, p, wf, lift, N, Nr; omega_eq, iters, beta0=0.9,
                beta_min=0.5, beta_max=0.9999, report=50_000, tol=0.05,
                mass_factor=1.0, pin_omega=true, freeze_kite=true)
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, p)
    du = zeros(length(u))
    beta = beta0
    prev_ke = Inf
    hist = NamedTuple[]
    for it in 1:iters
        fill!(du, 0.0)
        KiteTurbineDynamics.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]

        # ── kinetic-energy adaptive damping (Day's dynamic relaxation) ────────
        ke = 0.0
        for gid in 1:N
            gid == NODE1_IS_ANCHOR && continue
            m = (sys.nodes[gid]).mass
            v = @view u[(3N + 3 * (gid - 1) + 1):(3N + 3 * (gid - 1) + 3)]
            ke += 0.5 * m * sum(abs2, v)
        end
        if it > 1
            if ke > prev_ke
                beta = max(beta_min, beta * 0.9)        # diverging: damp harder
            else
                beta = min(beta_max, beta * 1.0005)     # descending: ease off
            end
        end
        prev_ke = ke
        for gid in 1:N
            gid == NODE1_IS_ANCHOR && continue
            b = 3N + 3 * (gid - 1) + 1
            for k in 0:2
                u[b + k] *= beta
            end
        end

        pin_omega && (u[(6N + Nr + 1):(6N + 2Nr)] .= omega_eq)
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0
        if lift !== nothing && !freeze_kite
            KiteTurbineDynamics.update_kite_pos!(sys, u, lift, p, dt)
        end

        if it % report == 0
            res, _ = residual(u, sys, p, wf, lift, N)
            amax = maximum(norm.(res[2:N]) ./ [ (sys.nodes[g]).mass for g in 2:N ])
            fmax = maximum(norm.(res[2:N]))
            push!(hist, (it=it, amax=amax, fmax=fmax, ke=ke, beta=beta))
            amax < tol && break
        end
    end
    return u, hist
end

function main()
    iters = parse(Int, get(ENV, "KTD_ITERS", "3000000"))
    ms = parse(Float64, get(ENV, "KTD_MS", "1.0"))
    omega_eq = 12.983466

    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    ms != 1.0 && mass_scale_nodes!(sys, ms)

    u = KiteTurbineDynamics.settle_to_equilibrium(sys, u0, p; lift_device=lift, wind_fn=wf)
    for k in 1:Nr
        u[6N + Nr + k] = omega_eq
    end
    # freeze the kite at its equilibrium offset from the STARTING sky position
    sd = normalize(pos(u, sys.sky_anchor_id))
    sys.kite_pos .= pos(u, sys.sky_anchor_id) .+
                    lift.line_length .* [cos(p.lifter_elevation), 0.0, sin(p.lifter_elevation)]

    @printf("relaxing: iters=%d  mass_factor=%.1f  frozen kite, omega pinned\n\n", iters, ms)
    @printf("  %10s %12s %12s %14s %8s\n", "iter", "max_accel", "max_force_N", "kinetic_E_J", "beta")
    t0 = time()
    u, hist = relax!(u, sys, p, wf, lift, N, Nr;
        omega_eq=omega_eq, iters=iters, report=max(1, iters ÷ 20), tol=0.05,
        mass_factor=ms, freeze_kite=true)
    el = time() - t0
    for h in hist
        @printf("  %10d %12.4f %12.4f %14.6e %8.5f\n", h.it, h.amax, h.fmax, h.ke, h.beta)
    end
    @printf("\nwall time %.1f s\n", el)

    res, du = residual(u, sys, p, wf, lift, N)
    println("\nlargest remaining per-node imbalance:")
    idx = sortperm([norm(res[g]) for g in 1:N]; rev=true)[1:6]
    for g in idx
        @printf("  node %3d %-14s |F|=%10.4f N  accel=%10.3f m/s2\n",
            g, string(typeof(sys.nodes[g])), norm(res[g]),
            norm(res[g]) / (sys.nodes[g]).mass)
    end
    hub = sys.rotor.node_id
    @printf("\nhub |r| = %.4f ; bearing |r| = %.4f ; sky |r| = %.4f\n",
        norm(pos(u, hub)), norm(pos(u, sys.bearing_id)), norm(pos(u, sys.sky_anchor_id)))
end

main()
