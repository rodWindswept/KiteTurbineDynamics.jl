# scratch/prototype_static_solver.jl
#
# 2026-09-16.  Dynamic relaxation (Barnes kinetic damping) static solver,
# prototype.  ACTIVE.md item 3.
#
# PROBLEM.  `settle_to_operational_state` places the machine and relaxes it
# briefly; it does not solve for equilibrium.  Measured
# (scratch/diag_acc0_velocity.jl), the settled state leaves
#
#     RingNode 11   0.836 kg   |a| = 284.5 m/s^2 (29 g)   ->  238 N unbalanced
#
# while hub, bearing and sky balance along the shaft to under 50 N.  So the
# residual is transverse / local, and it does not decay with more settle steps.
# Target: bring the static residual under 10 g (98.1 m/s^2), i.e. under 82 N.
#
# METHOD (ACTIVE.md item 3's discipline, followed literally):
#   * The force path is called with node TRANSLATIONAL velocities zeroed, so the
#     rope material damper and the aero drag vanish and the force field is
#     conservative.  `omega` is retained, so rotor thrust and torque stay in the
#     load case.  `multibody_ode!` is NOT reused wholesale as an integrator.
#   * The fictitious mass is scaled PER NODE from the local axial stiffness
#     (sum of EA/L over the connected sub-segments).  Real masses span
#     2.25e-3 kg (rope node) to ~4 kg; a uniform fictitious mass makes the stiff
#     rope DoF the stability limit while the heavy rings crawl.
#   * Kinetic damping: track KE = 1/2 sum m_fict v^2 and zero ALL velocities
#     whenever KE passes a local maximum.  That is the Barnes scheme, and it is
#     the specific reason to expect a different outcome from the 2026-09-13
#     probe that ran 2 M VISCOUS steps.
#   * FIXED nodes carry mass 1e30 kg.  Their fictitious mass is left at 1e30, so
#     their velocity update is ~0 and they behave as the constraints they are.
#
# This prototype relaxes POSITIONS only (3N) and holds the twist block fixed.
# The twist is the candidate second stage if positions alone do not close it.
#
# NOTE: every loop lives in a FUNCTION.  A bare top-level loop soft-scopes its
# assignments (the Julia trap already documented in test_physics_path_ode.jl and
# test/acceptance_runtests.jl).

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const DT_DR = 2e-4
const MAX_ITERS = 20_000
const REPORT_EVERY = 2_000

"Net force on every node, from the CONSERVATIVE force path (velocities zeroed)."
function net_force!(F, us, sys, p, wf, lift, N)
    us[(3N + 1):(6N)] .= 0.0                    # damper + drag vanish
    du = zeros(length(us))
    KiteTurbineDynamics.multibody_ode!(du, us, (sys, p, wf, lift), 0.0)
    for g in 1:N
        m = sys.nodes[g].mass
        F[(3 * (g - 1) + 1):(3 * g)] .= m .* du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]
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
        sys.nodes[g].mass > 1e29 && continue        # skip fixed nodes
        v = norm(F[(3 * (g - 1) + 1):(3 * g)])
        if v > best
            best = v
            bg = g
        end
    end
    return best, bg
end

"""
Barnes dynamic relaxation.  Returns (x, v, ndamp, trace) where `trace` is a
vector of (iter, ke, acc0, worstF, worstNode, ndamp) at each report.
"""
function run_dr(x, v, mfr, sys, p, wf, lift, N; dt_dr=DT_DR,
                max_iters=MAX_ITERS, report_every=REPORT_EVERY)
    Fbuf = zeros(3N)
    ke_prev = 0.0
    ndamp = 0
    trace = NamedTuple[]
    for it in 1:max_iters
        net_force!(Fbuf, x, sys, p, wf, lift, N)
        v .+= (Fbuf ./ mfr) .* dt_dr
        x[1:(3N)] .+= v .* dt_dr
        ke = 0.5 * sum(mfr .* v .^ 2)
        if ke < ke_prev
            v .= 0.0                                # kinetic damping (Barnes)
            ndamp += 1
        end
        ke_prev = ke
        if it % report_every == 0 || it == 1
            a = static_acc0(x, sys, p, wf, lift, N)
            wF, wg = worst_force(x, sys, p, wf, lift, N)
            push!(trace, (it=it, ke=ke, acc0=a, g=a / 9.81, wF=wF, wg=wg, ndamp=ndamp))
        end
    end
    return x, v, ndamp, trace
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    println("=== machine: n_total = ", N, "  n_ring = ", Nr, " ===")

    u = settle_to_operational_state(sys, u0, p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=300_000)

    mf = fictitious_mass(sys, N, DT_DR)
    mfr = repeat(mf, inner=3)

    moving = [g for g in 1:N if sys.nodes[g].mass < 1e29]
    println("  nodes: ", N, " total, ", length(moving), " moving, ",
            N - length(moving), " fixed (mass 1e30)")
    println("  fictitious mass over MOVING nodes: min = ",
            round(minimum(mf[moving]); sigdigits=4), " kg   max = ",
            round(maximum(mf[moving]); sigdigits=4), " kg")
    println("  real mass over MOVING nodes:       min = ",
            round(minimum(sys.nodes[g].mass for g in moving); sigdigits=4), " kg   max = ",
            round(maximum(sys.nodes[g].mass for g in moving); sigdigits=4), " kg")
    println("  dt_dr = ", DT_DR, " s   max_iters = ", MAX_ITERS)

    a0 = static_acc0(u, sys, p, wf, lift, N)
    F0, g0 = worst_force(u, sys, p, wf, lift, N)
    @printf("\n  START:  static acc0 = %.2f m/s^2 (%.2f g)   worst |F| = %.2f N on node %d\n",
        a0, a0 / 9.81, F0, g0)

    x, v, ndamp, trace = run_dr(copy(u), zeros(3N), mfr, sys, p, wf, lift, N)

    println("\n  ", lpad("iter", 7), lpad("KE", 13), lpad("acc0 m/s2", 12),
            lpad("g", 9), lpad("worstF N", 10), lpad("node", 6), lpad("damps", 7))
    for r in trace
        @printf("  %7d %13.4e %12.2f %9.2f %10.2f %6d %7d\n",
            r.it, r.ke, r.acc0, r.g, r.wF, r.wg, r.ndamp)
    end

    aF = static_acc0(x, sys, p, wf, lift, N)
    Ff, gf = worst_force(x, sys, p, wf, lift, N)
    @printf("\n  FINAL:  static acc0 = %.2f m/s^2 (%.2f g)   worst |F| = %.2f N on node %d   damps = %d\n",
        aF, aF / 9.81, Ff, gf, ndamp)
    @printf("  target: 98.10 m/s^2 (10 g)  ->  %s\n", aF < 10.0 * 9.81 ? "MET" : "NOT MET")

    # ── Validity: DR moves POSITIONS, so it can break the operating point. ──
    # The relaxation is only usable if the relaxed state is still the same
    # machine at the same operating point with the lift chain connected.
    N1 = N
    om_before = u[(6N1 + Nr + 1):(6N1 + 2Nr)]
    om_after = x[(6N1 + Nr + 1):(6N1 + 2Nr)]
    @assert om_before == om_after "DR must not touch the omega block"
    @assert x[(6N1 + 1):(6N1 + Nr)] == u[(6N1 + 1):(6N1 + Nr)] "DR must not touch alpha"

    function residuals(state)
        du = zeros(length(state))
        KiteTurbineDynamics.multibody_ode!(du, state, (sys, p, wf, lift), 0.0)
        out = Dict{String,Float64}()
        for (nm, gid) in (("hub", sys.rotor.node_id), ("bearing", sys.bearing_id),
                          ("sky", sys.sky_anchor_id))
            m = sys.nodes[gid].mass
            out[nm] = norm(m .* du[(3N1 + 3 * (gid - 1) + 1):(3N1 + 3 * gid)])
        end
        return out
    end
    rb = residuals(u)
    ra = residuals(x)
    println("\n  === validity: the relaxed state must still be the same machine ===")
    @printf("  %-9s %14s %14s\n", "node", "|F| before N", "|F| after N")
    for nm in ("hub", "bearing", "sky")
        @printf("  %-9s %14.2f %14.2f\n", nm, rb[nm], ra[nm])
    end

    # Coordinates must have moved, or nothing happened.
    disp = maximum(norm(x[(3 * (g - 1) + 1):(3 * g)] .-
                       u[(3 * (g - 1) + 1):(3 * g)]) for g in 1:N1)
    @printf("  max node displacement during DR: %.4f m\n", disp)
    @assert disp > 1e-3 "DR moved nothing"
    @assert aF < a0 "DR must reduce the static acceleration"

    println("\n  ASSERTIONS PASSED: acc0 reduced ", round(a0; digits=1), " -> ",
            round(aF; digits=1), " m/s^2; omega and alpha untouched")
    println("=== done ===")
end

main()
