# scratch/probe_dr_A_convergence.jl
#
# 2026-09-19.  Variant A (drag-included DR) is the physically correct equilibrium:
# it collapses acc0_raw 17468 -> 293 m/s2 and V2 hub 14.5 -> -2.65 N, whereas the
# drag-free variant B makes acc0_raw slightly worse.  This probe asks whether A
# converges far enough to clear the 10 g bar on the FULL-force residual, which is
# the metric a handoff actually cares about.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

function node_forces!(F, uw, du, ode_params, p, sys, N; zero_vel)
    if zero_vel
        @views uw[(3N + 1):(6N)] .= 0.0
    else
        set_orbital_velocities!(uw, sys, p)
        @views uw[(3N + 1):(3N + 3)] .= 0.0
    end
    fill!(du, 0.0)
    multibody_ode!(du, uw, ode_params, 0.0)
    for g in 1:N
        m = sys.nodes[g].mass
        @views F[(3 * (g - 1) + 1):(3 * g)] .=
            m .* du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]
    end
    return F
end

function dr!(u, sys, p, ode_params; zero_vel, dt=2e-4, iters)
    N = sys.n_total
    uw = copy(u); du = zeros(length(u)); F = zeros(3N)
    mf = repeat(KiteTurbineDynamics._static_polish_fictitious_mass(sys, N, dt), inner=3)
    v = zeros(3N); ke_prev = 0.0
    for _ in 1:iters
        node_forces!(F, uw, du, ode_params, p, sys, N; zero_vel=zero_vel)
        @views v .+= (F ./ mf) .* dt
        @views uw[1:(3N)] .+= v .* dt
        ke = 0.5 * sum(mf .* v .^ 2)
        ke < ke_prev && (v .= 0.0)
        ke_prev = ke
    end
    @views u[1:(3N)] .= uw[1:(3N)]
    return u
end

function metrics(u, sys, p, wf, lift, N)
    us = copy(u); @views us[(3N + 1):(6N)] .= 0.0
    ds = zeros(length(us)); multibody_ode!(ds, us, (sys, p, wf, lift), 0.0)
    static = maximum(norm(@views ds[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N)
    df = zeros(length(u)); multibody_ode!(df, u, (sys, p, wf, lift), 0.0)
    arg = argmax([norm(@views df[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N])
    raw = norm(@views df[(3N + 3 * (arg - 1) + 1):(3N + 3 * arg)])
    sd = normalize(@views u[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)])
    m = sys.nodes[sys.rotor.node_id].mass
    hub = dot(@views(m .* df[(3N + 3 * (sys.rotor.node_id - 1) + 1):(3N + 3 * sys.rotor.node_id)]), sd)
    return static, raw, arg, sys.nodes[arg].mass, hub
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    base = settle_to_operational_state(sys, copy(u0), p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=300_000, static_polish=false)
    ode_params = (sys, p, wf, lift)
    println("=== variant A (drag-included), convergence of the FULL residual ===")
    for iters in (10_000, 20_000, 40_000, 80_000)
        u = copy(base)
        dr!(u, sys, p, ode_params; zero_vel=false, iters=iters)
        update_kite_pos!(sys, u, lift, p, 0.0)
        s, raw, arg, m, hub = metrics(u, sys, p, wf, lift, N)
        @printf("  iters %6d  static %9.2f (%7.2f g) | FULL acc0 %8.2f (%7.3f g) on node %3d (%.5f kg) | V2 hub %7.3f N\n",
            iters, s, s / 9.81, raw, raw / 9.81, arg, m, hub)
    end
    println("=== done ===")
end

main()
