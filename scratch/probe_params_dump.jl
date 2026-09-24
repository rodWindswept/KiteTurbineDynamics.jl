using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
const KTD = KiteTurbineDynamics
sys, u0, p, lift, wf = build_case(nothing, nothing)
@printf("tether_length      = %.5f\n", p.tether_length)
@printf("back_anchor_fwd_x  = %.5f\n", p.back_anchor_fwd_x)
@printf(
    "elevation_angle    = %.5f rad = %.3f deg\n",
    p.elevation_angle,
    rad2deg(p.elevation_angle)
)
@printf("tether*cos(beta)   = %.5f\n", p.tether_length*cos(p.elevation_angle))
@printf(
    "back_ax(state)     = %.5f\n",
    p.tether_length*cos(p.elevation_angle)+p.back_anchor_fwd_x
)
@printf(
    "n_ring = %d  n_lines = %d  EA_back = %.1f\n", sys.n_ring, p.n_lines, p.EA_back_line
)
@printf("backline_payout    = %.5f\n", p.backline_payout)
hubr = (sys.nodes[sys.rotor.node_id]::RingNode).radius
@printf(
    "R_hub (resting)    = %.5f -> bridle_offset = %.5f\n",
    hubr,
    KTD.bridle_bearing_offset(hubr)
)
