using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
"Worst per-segment Δα/δα* over a `trpt_matched_place` result."
function worst_cross(place, sys)
    worst = 0.0
    seg = 0
    for ri in 1:(sys.n_ring - 1)
        ra=(sys.nodes[sys.ring_ids[ri]]::RingNode).radius
        rb=(sys.nodes[sys.ring_ids[ri + 1]]::RingNode).radius
        rs=max(ra, rb)
        L=norm(place.ctrs[ri + 1] .- place.ctrs[ri])
        ds=2*asin(min(L/sqrt(2*(L^2+2*rs^2)), 1.0))
        da=abs(place.α[ri + 1]-place.α[ri])
        r=da/ds
        r>worst && (worst=r; seg=ri)
    end
    return worst, seg
end
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    ω=u[6N + Nr + 1]
    τ=sys.k_mppt_ref[]*ω^2
    hub=pos(u, sys.rotor.node_id)
    for margin in (1.0, 1.05)
        F = design_axial_preload(
            sys,
            p,
            lift,
            u0;
            omega_eq=ω,
            wind_fn=wf,
            hub_pos=hub,
            realisability_margin=margin,
        )
        pl = KTD.trpt_matched_place(sys, p, F, τ, ω, wf; raise_on_unrealisable=false)
        w, s = worst_cross(pl, sys)
        @printf(
            "margin=%.2f  F_top=%.1f  demand=%.4f  worst Δα/δα*=%.4f (seg %d)  {%.2f deg vs %.2f}\n",
            margin,
            F[end],
            maximum(pl.demand),
            w,
            s,
            rad2deg(abs(pl.α[s + 1]-pl.α[s])),
            rad2deg(
                2*asin(
                    min(
                        norm(pl.ctrs[s + 1]-pl.ctrs[s])/sqrt(
                            2*(
                                norm(pl.ctrs[s + 1]-pl.ctrs[s])^2+2*max(
                                    (sys.nodes[sys.ring_ids[s]]::RingNode).radius,
                                    (sys.nodes[sys.ring_ids[s + 1]]::RingNode).radius,
                                )^2
                            ),
                        ),
                        1.0,
                    ),
                ),
            )
        )
    end
end
main()
