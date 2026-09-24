using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function cyanT(u, sys)
    tot=0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (
            (na==sys.sky_anchor_id && nb==sys.bearing_id)||(
                na==sys.bearing_id && nb==sys.sky_anchor_id
            )
        )||continue
        L=norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
        tot += ss.EA*max(0.0, (L-ss.length_0)/ss.length_0)
    end
    return tot
end
function handoff(u, sys, p, wf, lift)
    N=sys.n_total
    du=zeros(length(u))
    KTD.multibody_ode!(du, u, (sys, p, wf, lift), 0.0)
    acc=[norm(du[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 1:N]
    force=[sys.nodes[g].mass*acc[g] for g in 1:N]
    sg=[
        g for
        g in 1:N if sys.nodes[g] isa RingNode || g==sys.bearing_id || g==sys.sky_anchor_id
    ]
    return maximum(acc[g] for g in sg), maximum(force)
end
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    for (dt, iters) in ((5e-5, 80_000), (2.5e-5, 160_000), (1e-5, 400_000))
        u = settle_to_operational_state(
            sys,
            copy(u0),
            p,
            60.0;
            lift_device=lift,
            wind_fn=wf,
            n_op=300_000,
            polish_dt=dt,
            polish_iters=iters,
        )
        a, f = handoff(u, sys, p, wf, lift)
        bx = p.tether_length*cos(p.elevation_angle)+p.back_anchor_fwd_x
        sky=pos(u, sys.sky_anchor_id)
        bd=hypot(sky[1]-bx, sky[3])
        Tback = KTD.back_line_tension(bd, 13.92547, p.backline_payout, p.EA_back_line)
        @printf(
            "dt=%.1e n=%6d -> acc_struct=%8.3f max_force=%8.3f | sky=[%8.4f %8.4f] b_dist=%9.5f T_back=%7.3f T_cyan=%7.3f\n",
            dt,
            iters,
            a,
            f,
            sky[1],
            sky[3],
            bd,
            Tback,
            cyanT(u, sys)
        )
    end
end
main()
