using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
function cyan_tension(u, sys)
    tot = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (
            (na==sys.sky_anchor_id && nb==sys.bearing_id) ||
            (na==sys.bearing_id && nb==sys.sky_anchor_id)
        ) || continue
        L = norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
        tot += ss.EA*max(0.0, (L-ss.length_0)/ss.length_0)
    end
    return tot
end
function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    ω = u[6N + Nr + 1]
    d = KTD.lift_chain_design(sys, p, lift, pos(u, sys.rotor.node_id); omega_eq=ω)
    @printf(
        "lift_chain_design: T_cyan=%.3f T_back=%.3f back_taut=%s T_cyan_ax=%.3f T_bridle=%.3f T_top=%.3f\n",
        d.T_cyan,
        d.T_back,
        d.back_taut,
        d.T_cyan_ax,
        d.T_bridle,
        d.T_top
    )
    @printf(
        "  design sky=[%.4f %.4f %.4f]  settled sky=[%.4f %.4f %.4f]  err=%.5f m\n",
        d.sky_pos...,
        pos(u, sys.sky_anchor_id)...,
        norm(d.sky_pos .- pos(u, sys.sky_anchor_id))
    )
    @printf("  ODE measured T_cyan=%.3f N   (handover 252.50)\n", cyan_tension(u, sys))
    bx = p.tether_length*cos(p.elevation_angle)+p.back_anchor_fwd_x
    sky = pos(u, sys.sky_anchor_id)
    bd = hypot(sky[1]-bx, sky[3])
    bo = KTD.bridle_bearing_offset((sys.nodes[sys.rotor.node_id]::RingNode).radius)
    Lax = p.tether_length+bo+KTD.CYAN_L0_DESIGN
    backL0 = hypot(Lax*cos(p.elevation_angle)-bx, Lax*sin(p.elevation_angle))
    @printf(
        "  b_dist=%.5f back_L0=%.5f T_back(law)=%.3f N (was 313.51)\n",
        bd,
        backL0,
        KTD.back_line_tension(bd, backL0, p.backline_payout, p.EA_back_line)
    )
    τ_eq = sys.k_mppt_ref[]*ω^2
    g_inc=p.m_ring*9.81*sin(p.elevation_angle)
    n_seg=sys.n_ring-1
    F=zeros(n_seg)
    F[n_seg]=max(d.T_top, 20.0)
    for i in (n_seg - 1):-1:1
        F[i]=F[i + 1]+g_inc
    end
    pl=KTD.trpt_matched_place(sys, p, F, τ_eq, ω, wf; raise_on_unrealisable=false)
    @printf(
        "  demand at new T_top=%.2f -> %.4f (seg %d)\n",
        d.T_top,
        maximum(pl.demand),
        argmax(pl.demand)
    )
    Fship = KTD.design_axial_preload(sys, p, lift, u0; omega_eq=ω, wind_fn=wf)
    pls=KTD.trpt_matched_place(sys, p, Fship, τ_eq, ω, wf)
    @printf(
        "  design_axial_preload F_top=%.2f demand=%.4f\n", Fship[end], maximum(pls.demand)
    )
end
main()
