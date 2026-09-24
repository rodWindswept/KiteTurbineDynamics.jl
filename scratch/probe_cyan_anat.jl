using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    sky, bea = sys.sky_anchor_id, sys.bearing_id
    @printf(
        "sky=%d bearing=%d  dist=%.6f  CYAN_L0_DESIGN=%.3f\n",
        sky,
        bea,
        norm(pos(u, bea) .- pos(u, sky)),
        KTD.CYAN_L0_DESIGN
    )
    tot = 0.0
    for (i, ss) in enumerate(sys.sub_segs)
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        iscyan = ((na==sky && nb==bea) || (na==bea && nb==sky))
        touches = (na==sky || nb==sky)
        touches || continue
        L = norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
        st = (L-ss.length_0)/ss.length_0
        T = ss.EA*max(0.0, st)
        iscyan && (tot += T)
        @printf(
            "  ss#%-4d a=%-4d b=%-4d L0=%.6f L=%.6f strain=%+.6f EA=%.0f T=%.3f  %s\n",
            i,
            na,
            nb,
            ss.length_0,
            L,
            st,
            ss.EA,
            T,
            iscyan ? "CYAN" : "SKY-other"
        )
    end
    @printf("cyan total (probe metric) = %.4f N\n", tot)
end
main()
