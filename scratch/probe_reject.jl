using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    @printf("settled. simulating 5 s window...\n")
    dt = KTD.stable_dt_for_system(sys, p)
    du = zeros(length(u))
    steps = round(Int, 5.0/dt)
    Pmax=0.0
    Pmin=Inf
    tmin=Inf
    for k in 1:steps
        KTD.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
        @views u[1:(6N)] .+= du[1:(6N)] .* dt
        KTD.apply_brake_constraint!(u, sys, N, Nr)
        ωg = u[6N + Nr + 1]
        τg = sys.k_mppt_ref[]*ωg^2
        P = τg*ωg/1000
        Pmax=max(Pmax, P)
        Pmin=min(Pmin, P)
        if !isfinite(P)
            @printf("  NaN at step %d (t=%.3f)\n", k, k*dt)
            break
        end
    end
    @printf(
        "P range over 5 s = [%.3f, %.3f] kW ; final ω_gnd=%.4f\n",
        Pmin,
        Pmax,
        u[6N + Nr + 1]
    )
    # check knots / strain
    ef = KTD.capture_extended(u, sys, p, 5.0, wf, lift)
    @printf(
        "segment tension range = [%.1f, %.1f] N\n",
        minimum(ef.segment_tension),
        maximum(ef.segment_tension)
    )
    @printf(
        "twist[1]=%.2f deg max=%.2f\n",
        ef.segment_twist_deg[1],
        maximum(abs.(ef.segment_twist_deg))
    )
end
main()
