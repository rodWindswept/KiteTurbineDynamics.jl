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
    # per-LINE twists and tensions at the segment the detector flags (8) and seg 1
    pp1, pp2 = KTD._tilted_ring_basis(u, sys, sys.rotor.node_id, Nr)
    for s in (1, 8)
        gida, gidb = sys.ring_ids[s], sys.ring_ids[s + 1]
        na=sys.nodes[gida]::RingNode
        nb=sys.nodes[gidb]::RingNode
        ca=pos(u, gida)
        cb=pos(u, gidb)
        aa=u[6N + na.ring_idx]
        ab=u[6N + nb.ring_idx]
        da = abs(ab-aa)
        Ts = Float64[]
        for j in 1:p.n_lines
            pa=KTD.attachment_point(ca, na.radius, aa, j, p.n_lines, pp1, pp2)
            pb=KTD.attachment_point(cb, nb.radius, ab, j, p.n_lines, pp1, pp2)
            push!(Ts, KTD.get_segment_tension(u, sys, p, s, j))
        end
        L=norm(cb-ca)
        r=max(na.radius, nb.radius)
        ds=2*asin(min(L/sqrt(2*(L^2+2*r^2)), 1.0))
        Tbar=sum(Ts)/length(Ts)
        # what twist does the geometric/realisability relation need for this T?
        Da_geom = asin(min(τ / max(p.n_lines*Tbar*na.radius*nb.radius, 1e-9) * L, 1.0))
        @printf(
            "seg %2d: Δα=%.2f° δα*=%.2f° ratio=%.3f | T/line min=%.1f max=%.1f mean=%.1f | τ_need=%.1f\n",
            s,
            rad2deg(da),
            rad2deg(ds),
            da/ds,
            minimum(Ts),
            maximum(Ts),
            Tbar,
            τ
        )
        @printf(
            "        Δα needed for τ at Tbar = %.2f° (demand=%.3f)\n",
            rad2deg(asin(min(τ*L/(p.n_lines*Tbar*na.radius*nb.radius), 1.0))),
            τ*L/(p.n_lines*Tbar*na.radius*nb.radius)
        )
    end
end
main()
