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
        "BARE: F_top=%.2f demand=%.4f cross=%.4f\n",
        F[end],
        maximum(r.demand),
        KTD.max_segment_cross_ratio(r, sys)
    )
    threw = false
    try
        design_axial_preload(sys, pc, lift, u0; omega_eq=OMEGA_SEED, wind_fn=wf)
    catch e
        threw = true
        println("ENFORCED THREW: ", sprint(showerror, e)[1:min(end, 150)])
    end
    @printf("enforced threw = %s\n", threw)
end
main()
