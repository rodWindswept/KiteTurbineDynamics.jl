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
        "UNMARGINED: F_top=%.2f demand_max=%.4f seg=%d twist=%.2f deg T_s=%.2f tau_carry=%.2f\n",
        F[end],
        maximum(r.demand),
        argmax(r.demand),
        rad2deg(asin(min(maximum(r.demand), 1.0))),
        r.T_s[argmax(r.demand)],
        r.τ_carry[argmax(r.demand)]
    )
    @printf(
        "  demand[1]=%.4f demand[4]=%.4f  tau_carry[7]=%.2f tau_carry[8]=%.2f\n",
        r.demand[1],
        r.demand[4],
        r.τ_carry[7],
        r.τ_carry[8]
    )
    Fs = design_axial_preload(sys, pc, lift, u0; omega_eq=OMEGA_SEED, wind_fn=wf)
    rs = KTD.trpt_matched_place(sys, pc, Fs, τ, OMEGA_SEED, wf)
    @printf(
        "ENFORCED:   F_top=%.2f demand_max=%.4f seg=%d ratio=%.4f\n",
        Fs[end],
        maximum(rs.demand),
        argmax(rs.demand),
        Fs[end]/F[end]
    )
    @printf("  all(Fs .>= F)=%s\n", all(Fs .>= F))
    # section B fixtures
    for (nl, rc, ω) in ((4, 3.0, 13.399535), (6, 1.0, 11.398798))
        s2, u2, p2, l2, w2 = build_case(nl, rc; genome=SEED_LR20)
        F2 = design_axial_preload(
            s2, p2, l2, u2; omega_eq=ω, wind_fn=w2, realisability_margin=1.0
        )
        d = KTD.trpt_matched_place(
            s2, p2, F2, s2.k_mppt_ref[]*ω^2, ω, w2; raise_on_unrealisable=false
        )
        @printf(
            "B nl=%d rc=%.0f: demand_max=%.4f (>1 = refused)\n", nl, rc, maximum(d.demand)
        )
    end
end
main()
