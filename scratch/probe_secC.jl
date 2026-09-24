using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
const SEED_LR20 = [2.4, 0.5751086854, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
function main()
    sys3, u03, pc3, lift3, wf3 = build_case(4, 3.0; genome=SEED_LR20)
    try
        u3 = settle_to_operational_state(
            sys3, copy(u03), pc3, 60.0; lift_device=lift3, wind_fn=wf3, n_op=2_000
        )
        N3, Nr3 = sys3.n_total, sys3.n_ring
        ω3 = u3[6N3 + Nr3 + 1]
        F3 = design_axial_preload(sys3, pc3, lift3, u03; omega_eq=ω3, wind_fn=wf3)
        p3 = KTD.trpt_matched_place(sys3, pc3, F3, sys3.k_mppt_ref[]*ω3^2, ω3, wf3)
        @printf(
            "SecC OK: demand=%.4f cross=%.4f\n",
            maximum(p3.demand),
            KTD.max_segment_cross_ratio(p3, sys3)
        )
    catch e
        println("SecC RAISED: ", sprint(showerror, e)[1:min(end, 200)])
    end
end
main()
