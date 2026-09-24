# scratch/probe_dr_convergence.jl
#
# 2026-09-19.  Cap evidence for wiring the Barnes DR solver into
# `settle_to_operational_state` (handover 2026-09-19 §5.1, ACTIVE.md item 3).
#
# The committed prototype (scratch/prototype_static_solver.jl) reported 7.27 g at
# its 20 000-iteration cap and was STILL FALLING.  The handover is explicit that
# the cap must be chosen on evidence, not copied.  This probe settles ONCE and
# then runs DR for a long horizon, printing a fine-grained convergence trace so
# the cap can be read off the curve.  It also times the DR loop so the settle
# overhead is a measured number (+7 % was the prototype's estimate).
#
# Every loop lives in a FUNCTION (Julia soft-scope trap — see test_acceptance).

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const DT_DR = 2e-4
const MAX_ITERS = 120_000
const REPORT_EVERY = 2_000

"Net force on every node, from the CONSERVATIVE force path (velocities zeroed)."
function net_force!(F, us, sys, p, wf, lift, N)
    @views us[(3N + 1):(6N)] .= 0.0
    du = zeros(length(us))
    KiteTurbineDynamics.multibody_ode!(du, us, (sys, p, wf, lift), 0.0)
    for g in 1:N
        m = sys.nodes[g].mass
        @views F[(3 * (g - 1) + 1):(3 * g)] .= m .* du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]
    end
    return F
end

"Per-node fictitious mass from local axial stiffness: m = k * dt^2."
function fictitious_mass(sys, N, dt_dr)
    k = zeros(N)
    for ss in sys.sub_segs
        L = ss.length_0
        L > 0.0 || continue
        kk = ss.EA / L
        k[ss.end_a.node_id] += kk
        k[ss.end_b.node_id] += kk
    end
    mf = zeros(N)
    for g in 1:N
        mf[g] = max(k[g] * dt_dr^2, sys.nodes[g].mass)
    end
    return mf
end

"Max static node acceleration at the current positions (the V6 metric)."
function static_acc0(x, sys, p, wf, lift, N)
    F = zeros(3N)
    net_force!(F, copy(x), sys, p, wf, lift, N)
    a = 0.0
    for g in 1:N
        v = norm(F[(3 * (g - 1) + 1):(3 * g)]) / sys.nodes[g].mass
        a = max(a, v)
    end
    return a
end

"|F| on the worst MOVING node, and its id."
function worst_force(x, sys, p, wf, lift, N)
    F = zeros(3N)
    net_force!(F, copy(x), sys, p, wf, lift, N)
    best = 0.0
    bg = 0
    for g in 1:N
        sys.nodes[g].mass > 1e29 && continue
        v = norm(F[(3 * (g - 1) + 1):(3 * g)])
        if v > best
            best = v
            bg = g
        end
    end
    return best, bg
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    println("=== machine: n_total = ", N, "  n_ring = ", Nr, " ===")
    flush(stdout)

    t_settle = @elapsed begin
        u = settle_to_operational_state(
            sys, u0, p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
        )
    end
    @printf("  settle (n_op=300_000): %.1f s\n", t_settle)
    flush(stdout)

    mf = fictitious_mass(sys, N, DT_DR)
    mfr = repeat(mf; inner=3)

    a0 = static_acc0(u, sys, p, wf, lift, N)
    F0, g0 = worst_force(u, sys, p, wf, lift, N)
    @printf(
        "  START: static acc0 = %.2f m/s^2 (%.2f g)  worst |F| = %.2f N on node %d\n",
        a0,
        a0 / 9.81,
        F0,
        g0
    )

    x = copy(u)
    v = zeros(3N)
    Fbuf = zeros(3N)
    ke_prev = 0.0
    ndamp = 0
    best = a0
    best_it = 0
    t0 = time()
    for it in 1:MAX_ITERS
        net_force!(Fbuf, x, sys, p, wf, lift, N)
        v .+= (Fbuf ./ mfr) .* DT_DR
        @views x[1:(3N)] .+= v .* DT_DR
        ke = 0.5 * sum(mfr .* v .^ 2)
        if ke < ke_prev
            v .= 0.0
            ndamp += 1
        end
        ke_prev = ke
        if it % REPORT_EVERY == 0 || it == 1
            a = static_acc0(x, sys, p, wf, lift, N)
            wF, wg = worst_force(x, sys, p, wf, lift, N)
            a < best && (best=a; best_it=it)
            @printf(
                "  it %7d  KE %11.3e  acc0 %9.3f m/s2 (%7.3f g)  worstF %8.3f N node %3d  damps %4d  t %6.1f s\n",
                it,
                ke,
                a,
                a / 9.81,
                wF,
                wg,
                ndamp,
                time() - t0
            )
            flush(stdout)
        end
    end
    t_dr = time() - t0
    @printf(
        "\n  DR loop: %.1f s for %d iters (%.2f ms/iter)  => +%.1f %% on the settle\n",
        t_dr,
        MAX_ITERS,
        1000 * t_dr / MAX_ITERS,
        100 * t_dr / t_settle
    )

    aF = static_acc0(x, sys, p, wf, lift, N)
    Ff, gf = worst_force(x, sys, p, wf, lift, N)
    @printf(
        "  FINAL: static acc0 = %.3f m/s^2 (%.3f g)  worst |F| = %.2f N on node %d\n",
        aF,
        aF / 9.81,
        Ff,
        gf
    )
    @printf(
        "  best acc0 = %.3f m/s^2 (%.3f g) first reached at it %d\n",
        best,
        best / 9.81,
        best_it
    )
    @printf("  target 98.10 m/s^2 (10 g) -> %s\n", aF < 10.0 * 9.81 ? "MET" : "NOT MET")

    # omega / alpha untouched?
    @assert x[(6N + Nr + 1):(6N + 2Nr)] == u[(6N + Nr + 1):(6N + 2Nr)] "DR touched omega"
    @assert x[(6N + 1):(6N + Nr)] == u[(6N + 1):(6N + Nr)] "DR touched alpha"
    disp = maximum(
        norm(@views(x[(3 * (g - 1) + 1):(3 * g)] .- u[(3 * (g - 1) + 1):(3 * g)])) for
        g in 1:N
    )
    @printf("  max node displacement during DR: %.4f m\n", disp)

    du = zeros(length(x))
    KiteTurbineDynamics.multibody_ode!(du, x, (sys, p, wf, lift), 0.0)
    for (nm, gid) in (
        ("hub", sys.rotor.node_id), ("bearing", sys.bearing_id), ("sky", sys.sky_anchor_id)
    )
        m = sys.nodes[gid].mass
        f = norm(@views m .* du[(3N + 3 * (gid - 1) + 1):(3N + 3 * gid)])
        @printf("  residual %-8s |F| = %.3f N\n", nm, f)
    end
    return println("=== done ===")
end

main()
