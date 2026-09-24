# scratch/probe_taut_trpt_realisability.jl
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const KTD = KiteTurbineDynamics

const OMEGA_SEED = 12.983466
const SEED_LR20 = [2.4, 0.5751086854, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]

function test_taut_lr20()
    sys, u0, pc, lift, wf = build_case(nothing, nothing; genome=SEED_LR20)
    hub_pos = u0[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)]
    β = pc.elevation_angle
    sh = [cos(β), 0.0, sin(β)]
    R_hub = (sys.nodes[sys.rotor.node_id]::RingNode).radius
    bo = KTD.bridle_bearing_offset(R_hub)
    bearing_pos = hub_pos .+ bo .* sh
    sky_pos = bearing_pos .+ KTD.CYAN_L0_DESIGN .* sh
    cyan_dir = normalize(bearing_pos .- sky_pos)
    back_ax = pc.tether_length * cos(β) + pc.back_anchor_fwd_x
    back_pos = [back_ax, 0.0, 0.0]
    back_dir = normalize(back_pos .- sky_pos)

    _, T_lift, el_deg = KTD.lift_force_steady(lift, pc.rho, pc.v_wind_ref, pc)
    el = deg2rad(el_deg)
    lift_dir = [cos(el), 0.0, sin(el)]
    W_sky = [0.0, 0.0, -KTD.SKY_ANCHOR_MASS_KG * 9.81]

    # Slack solve
    T_cyan_slack = max(-dot(T_lift .* lift_dir .+ W_sky, cyan_dir), 0.0)

    # 2x2 Taut solve
    sol =
        [cyan_dir[1] back_dir[1]; cyan_dir[3] back_dir[3]] \
        [-(T_lift * lift_dir[1] + W_sky[1]), -(T_lift * lift_dir[3] + W_sky[3])]
    T_cyan_taut, T_back_taut = sol[1], sol[2]

    println("=== SEED_LR20 Sky Anchor Balance ===")
    @printf("  T_lift = %.2f N (el=%.1f°)\n", T_lift, el_deg)
    @printf(
        "  cyan_dir = [%.4f, %.4f, %.4f], back_dir = [%.4f, %.4f, %.4f]\n",
        cyan_dir...,
        back_dir...
    )
    @printf("  SLACK: T_cyan = %.2f N, T_back = 0.0 N\n", T_cyan_slack)
    @printf("  TAUT:  T_cyan = %.2f N, T_back = %.2f N\n", T_cyan_taut, T_back_taut)

    # Effect on T_top
    d_slack = KTD.lift_chain_design(sys, pc, lift, hub_pos; omega_eq=OMEGA_SEED)
    @printf("  Current d.T_top (slack) = %.2f N\n", d_slack.T_top)

    # If T_cyan is replaced by T_cyan_taut:
    # T_bridle = max((T_cyan_ax - W_bearing*sinβ)/(n_lines*cosθ), 0.0)
    T_cyan_ax_taut = -T_cyan_taut * dot(cyan_dir, sh)
    T_bridle_taut = max(
        (T_cyan_ax_taut - KTD.BEARING_MASS_KG * 9.81 * sin(β)) /
        (pc.n_lines * d_slack.cosθ),
        0.0,
    )
    T_top_taut =
        d_slack.T_thrust + pc.n_lines * T_bridle_taut * d_slack.cosθ -
        d_slack.W_rotor * sin(β)
    @printf(
        "  Candidate d.T_top (taut) = %.2f N  (diff = %+.2f N)\n",
        T_top_taut,
        T_top_taut - d_slack.T_top
    )

    # Check demand on SEED_LR20 with T_top_taut at realisability_margin=1.0:
    n_seg = sys.n_ring - 1
    g_inc = pc.m_ring * 9.81 * sin(β)
    F_ax_taut = zeros(n_seg)
    F_ax_taut[n_seg] = T_top_taut
    for i in (n_seg - 1):-1:1
        F_ax_taut[i] = F_ax_taut[i + 1] + g_inc
    end
    τ_eq = sys.k_mppt_ref[] * OMEGA_SEED^2
    r_taut = KTD.trpt_matched_place(
        sys, pc, F_ax_taut, τ_eq, OMEGA_SEED, wf; raise_on_unrealisable=false
    )
    @printf(
        "  Demand on SEED_LR20 with TAUT T_top: max demand = %.4f (binding seg %d)\n",
        maximum(r_taut.demand),
        argmax(r_taut.demand)
    )

    # Also check campaign seed (L/r 1.5)
    sys_seed, u0_seed, pc_seed, lift_seed, wf_seed = build_case(nothing, nothing)
    hub_seed = u0_seed[(3 * (sys_seed.rotor.node_id - 1) + 1):(3 * sys_seed.rotor.node_id)]
    d_seed_slack = KTD.lift_chain_design(
        sys_seed, pc_seed, lift_seed, hub_seed; omega_eq=OMEGA_SEED
    )
    println("\n=== Campaign Seed (L/r 1.5) ===")
    @printf("  Current d.T_top (slack) = %.2f N\n", d_seed_slack.T_top)
end

test_taut_lr20()
