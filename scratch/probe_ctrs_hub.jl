using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    ω = 12.983466
    τ = sys.k_mppt_ref[]*ω^2
    dup = KTD.apply_design_bridle_preload!(sys, u0, p, lift; omega_eq=ω)
    F1 = design_axial_preload(sys, p, lift, u0; omega_eq=ω, wind_fn=wf)
    pl1 = KTD.trpt_matched_place(sys, p, F1, τ, ω, wf)
    hub_pl = pl1.ctrs[Nr]
    d0 = KTD.lift_chain_design(sys, p, lift, pos(u0, sys.rotor.node_id); omega_eq=ω)
    d1 = KTD.lift_chain_design(sys, p, lift, hub_pl; omega_eq=ω)
    @printf(
        "u0 hub        =[%.4f %.4f] |%.4f|\n",
        pos(u0, sys.rotor.node_id)[1],
        pos(u0, sys.rotor.node_id)[3],
        norm(pos(u0, sys.rotor.node_id))
    )
    @printf("ctrs[Nr] hub  =[%.4f %.4f] |%.4f|\n", hub_pl[1], hub_pl[3], norm(hub_pl))
    @printf(
        "split at u0 hub   : T_cyan=%.3f T_back=%.3f T_top=%.3f\n",
        d0.T_cyan,
        d0.T_back,
        d0.T_top
    )
    @printf(
        "split at ctrs[Nr] : T_cyan=%.3f T_back=%.3f T_top=%.3f  (handover 245.5/320.2/1270)\n",
        d1.T_cyan,
        d1.T_back,
        d1.T_top
    )
end
main()
