using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
const SEED_LR20 = [2.4, 0.5751086854, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
const OMEGA_SEED = 12.983466
function main()
    sys, u0, pc, lift, wf = build_case(nothing, nothing; genome=SEED_LR20)
    τ = sys.k_mppt_ref[]*OMEGA_SEED^2
    # un-enforced design
    F = design_axial_preload(
        sys, pc, lift, u0; omega_eq=OMEGA_SEED, realisability_margin=1.0
    )
    pl = KTD.trpt_matched_place(sys, pc, F, τ, OMEGA_SEED, wf; raise_on_unrealisable=false)
    @printf(
        "LR20 bare : F_top=%.2f demand=%.4f cross=%.4f\n",
        F[end],
        maximum(pl.demand),
        KTD.max_segment_cross_ratio(pl, sys)
    )
    # enforced (huge margin so the loop doesn't raise; read what it reaches)
    F2 = design_axial_preload(
        sys, pc, lift, u0; omega_eq=OMEGA_SEED, wind_fn=wf, realisability_margin=1e9
    )
    pl2 = KTD.trpt_matched_place(
        sys, pc, F2, τ, OMEGA_SEED, wf; raise_on_unrealisable=false
    )
    @printf(
        "LR20 enforced: F_top=%.2f ratio=%.4f demand=%.4f cross=%.4f\n",
        F2[end],
        F2[end]/F[end],
        maximum(pl2.demand),
        KTD.max_segment_cross_ratio(pl2, sys)
    )
    @printf(
        "  max allowed = %.2f x F_bare = %.2f\n",
        KTD.TRPT_REALISABILITY_MAX_PRELOAD_FACTOR,
        KTD.TRPT_REALISABILITY_MAX_PRELOAD_FACTOR*F[end]
    )
end
main()
