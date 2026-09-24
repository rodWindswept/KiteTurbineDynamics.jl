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
    ω=u[6N + Nr + 1]
    τ=sys.k_mppt_ref[]*ω^2
    hub=pos(u, sys.rotor.node_id)
    F = design_axial_preload(sys, p, lift, u0; omega_eq=ω, wind_fn=wf, hub_pos=hub)
    pl = KTD.trpt_matched_place(sys, p, F, τ, ω, wf)
    @printf(
        "enforced F_top=%.2f  demand=%.4f  cross_ratio=%.4f\n",
        F[end],
        maximum(pl.demand),
        KTD.max_segment_cross_ratio(pl, sys)
    )
    d = KTD.lift_chain_design(sys, p, lift, hub; omega_eq=ω)
    @printf("design: T_cyan=%.1f T_back=%.1f T_top=%.1f\n", d.T_cyan, d.T_back, d.T_top)
    # verify at the actual settled equilibrium
    tr = KTD.twist_collapse_check(u, sys)
    @printf("settled (this u): crossed=%s ratio=%.4f\n", tr.crossed, tr.max_ratio)
end
main()
