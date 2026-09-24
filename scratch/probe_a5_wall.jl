using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function main()
    for d in (0.003651, 0.0006, 0.0004, 0.0003, 0.00025, 0.00020, 0.00016)
        sys, u0, p, lift, wf = build_case(nothing, nothing)
        p2 = KTD.override_params(p; tether_diameter=d)
        # soften the structural lines too, as the gate's p_thin does
        sys2, u02, pc2 = KTD.build_system_from_v10(
            (x->x)(seed_genome(5.0)),
            1.0,
            K_MPPT_5KW_HONEST;
            tether_diameter=d,
            base_params=p2,
            min_wall_m=2e-3,
        )
        pc2.k_mppt_ref[] = K_MPPT_5KW_HONEST
        lift2 = sized_lifter_for(sys2, pc2; margin=1.5, v_ref=11.0, const_tension=true)
        wf2 = (r, t)->[11.0*(max(r[3], 1.0)/p.h_ref)^(1/7), 0.0, 0.0]
        ω = 12.983466
        F = design_axial_preload(sys2, pc2, lift2, u02; omega_eq=ω, wind_fn=wf2)
        pl = KTD.trpt_matched_place(
            sys2, pc2, F, sys2.k_mppt_ref[]*ω^2, ω, wf2; raise_on_unrealisable=false
        )
        @printf(
            "d=%.6f EA=%.0f N -> F_top=%.1f cross=%.3f demand=%.3f\n",
            d,
            pc2.e_modulus*pi*(d/2)^2,
            F[end],
            KTD.max_segment_cross_ratio(pl, sys2),
            maximum(pl.demand)
        )
    end
end
main()
