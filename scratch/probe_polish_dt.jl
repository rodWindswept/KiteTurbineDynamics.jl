using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
function handoff(u, sys, p, wf, lift)
    N = sys.n_total
    du = zeros(length(u))
    KTD.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    acc=[norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    force=[sys.nodes[g].mass*acc[g] for g in 1:N]
    sg=[
        g for
        g in 1:N if sys.nodes[g] isa RingNode || g==sys.bearing_id || g==sys.sky_anchor_id
    ]
    return maximum(acc[g] for g in sg), maximum(force)
end
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    for (dt, iters) in ((2e-4, 20_000), (5e-5, 80_000), (1e-5, 400_000))
        u = settle_to_operational_state(
            sys,
            copy(u0),
            p,
            60.0;
            lift_device=lift,
            wind_fn=wf,
            n_op=300_000,
            polish_dt=dt,
            polish_iters=iters,
        )
        a, f = handoff(u, sys, p, wf, lift)
        @printf(
            "dt=%.0e iters=%7d (t=%.2f s) -> acc_struct=%10.3f  max_force=%9.3f\n",
            dt,
            iters,
            dt*iters,
            a,
            f
        )
    end
end
main()
