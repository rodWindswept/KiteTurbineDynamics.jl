using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
const SEED_LR20 = [2.4, 0.5751086854, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
const OMEGA_SEED = 12.983466
function main()
    sys, u0, pc, lift, wf = build_case(nothing, nothing; genome=SEED_LR20)
    τ = sys.k_mppt_ref[]*OMEGA_SEED^2
    F = design_axial_preload(
        sys, pc, lift, u0; omega_eq=OMEGA_SEED, realisability_margin=1.0
    )
    r = KTD.trpt_matched_place(sys, pc, F, τ, OMEGA_SEED, wf; raise_on_unrealisable=false)
    @printf(
        "demand[1]=%.4f demand[4]=%.4f demand[7]=%.4f demand[8]=%.4f\n",
        r.demand[1],
        r.demand[4],
        r.demand[7],
        r.demand[8]
    )
    @printf(
        "tau_carry[7]=%.2f tau_carry[8]=%.2f  F_top=%.2f\n",
        r.τ_carry[7],
        r.τ_carry[8],
        F[end]
    )
    Fs = design_axial_preload(sys, pc, lift, u0; omega_eq=OMEGA_SEED, wind_fn=wf)
    rs = KTD.trpt_matched_place(sys, pc, Fs, τ, OMEGA_SEED, wf)
    @printf(
        "enforced F_top=%.2f demand_max=%.4f ratio=%.4f\n",
        Fs[end],
        maximum(rs.demand),
        Fs[end]/F[end]
    )
end
main()
