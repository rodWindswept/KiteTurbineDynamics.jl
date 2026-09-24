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
    tr = KTD.twist_collapse_check(u, sys)
    @printf(
        "AT SETTLE : crossed=%s max_ratio=%.4f worst_seg=%d\n",
        tr.crossed,
        tr.max_ratio,
        tr.worst_seg
    )
    for ri in 1:(Nr - 1)
        r_i=(sys.nodes[sys.ring_ids[ri]]::RingNode).radius
        r_j=(sys.nodes[sys.ring_ids[ri + 1]]::RingNode).radius
        rs=max(r_i, r_j)
        L=norm(pos(u, sys.ring_ids[ri + 1]) .- pos(u, sys.ring_ids[ri]))
        ds=2*asin(min(L/sqrt(2*(L^2+2*rs^2)), 1.0))
        da=abs(u[6N + ri + 1]-u[6N + ri])
        ri_<=(ri>0) # noop
        @printf(
            "  seg %2d: L=%.4f r=%.4f dastar=%.2f deg  da=%.2f deg  ratio=%.3f\n",
            ri,
            L,
            rs,
            rad2deg(ds),
            rad2deg(da),
            da/ds
        )
    end
end
main()
