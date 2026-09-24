using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
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
    d = KTD.lift_chain_design(sys, p, lift, pos(u0, sys.rotor.node_id); omega_eq=12.983466)
    @printf(
        "T_design=%.4f  T_cyan=%.2f T_back=%.2f T_top=%.2f back_taut=%s\n",
        KTD.BACK_LINE_T_DESIGN_N,
        d.T_cyan,
        d.T_back,
        d.T_top,
        d.back_taut
    )
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    a, f = handoff(u, sys, p, wf, lift)
    @printf("settled: acc_struct=%.3f max_force=%.3f\n", a, f)
end
main()
