using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
const SEED_LR20 = [2.4, 0.5751086854, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
const OMEGA_SEED = 12.983466
function main()
    sys, u0, pc, lift, wf = build_case(nothing, nothing; genome=SEED_LR20)
    τ = sys.k_mppt_ref[]*OMEGA_SEED^2
    Fun = design_axial_preload(
        sys, pc, lift, u0; omega_eq=OMEGA_SEED, realisability_margin=1.0
    )
    @printf("SEED_LR20 unmargined F_top=%.2f\n", Fun[end])
    du = KTD.trpt_matched_place(
        sys, pc, Fun, τ, OMEGA_SEED, wf; raise_on_unrealisable=false
    )
    @printf(
        "  demand max=%.4f (seg %d)  T_s=%.2f\n",
        maximum(du.demand),
        argmax(du.demand),
        du.T_s[argmax(du.demand)]
    )
    Fsh = design_axial_preload(sys, pc, lift, u0; omega_eq=OMEGA_SEED, wind_fn=wf)
    @printf("SEED_LR20 enforced   F_top=%.2f\n", Fsh[end])
    ds = KTD.trpt_matched_place(sys, pc, Fsh, τ, OMEGA_SEED, wf)
    @printf("  demand max=%.4f (seg %d)\n", maximum(ds.demand), argmax(ds.demand))
    @printf("  raise applied? F_top ratio=%.4f\n", Fsh[end]/Fun[end])
end
main()
