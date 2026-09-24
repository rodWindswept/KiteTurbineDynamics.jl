# scratch/probe_campaign_seed_taut.jl
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const KTD = KiteTurbineDynamics

function run_probe()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    hub_gid = sys.rotor.node_id
    hub_pos = u0[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
    R_hub = (sys.nodes[hub_gid]::RingNode).radius
    bo = KTD.bridle_bearing_offset(R_hub)
    β = p.elevation_angle
    sh = [cos(β), 0.0, sin(β)]

    bearing_design = hub_pos .+ bo .* sh
    sky_design = bearing_design .+ KTD.CYAN_L0_DESIGN .* sh
    cyan_dir = normalize(bearing_design .- sky_design)
    back_ax = p.tether_length * cos(β) + p.back_anchor_fwd_x
    back_design = [back_ax, 0.0, 0.0]
    back_dir = normalize(back_design .- sky_design)

    _, T_lift, el_deg = KTD.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    el = deg2rad(el_deg)
    lift_dir = [cos(el), 0.0, sin(el)]
    W_sky = [0.0, 0.0, -KTD.SKY_ANCHOR_MASS_KG * 9.81]

    # Current slack solve
    T_cyan_slack = max(-dot(T_lift .* lift_dir .+ W_sky, cyan_dir), 0.0)

    # 2x2 Taut solve
    A = [cyan_dir[1] back_dir[1]; cyan_dir[3] back_dir[3]]
    rhs = [-(T_lift * lift_dir[1] + W_sky[1]), -(T_lift * lift_dir[3] + W_sky[3])]
    sol = A \ rhs
    T_cyan_2x2, T_back_2x2 = sol[1], sol[2]

    println("=== Campaign Seed (L/r 1.5) ===")
    @printf("  hub_pos     = [%.4f, %.4f, %.4f]\n", hub_pos...)
    @printf("  bearing_pos = [%.4f, %.4f, %.4f]\n", bearing_design...)
    @printf("  sky_pos     = [%.4f, %.4f, %.4f]\n", sky_design...)
    @printf("  cyan_dir    = [%.4f, %.4f, %.4f]\n", cyan_dir...)
    @printf("  back_dir    = [%.4f, %.4f, %.4f]\n", back_dir...)
    @printf("  SLACK: T_cyan = %.2f N\n", T_cyan_slack)
    @printf("  TAUT:  T_cyan = %.2f N, T_back = %.2f N\n", T_cyan_2x2, T_back_2x2)

    # Preload calculation
    d_slack = KTD.lift_chain_design(sys, p, lift, hub_pos; omega_eq=13.452)
    println("\nCurrent Slack lift_chain_design:")
    @printf(
        "  T_cyan = %.2f N, T_bridle = %.2f N, T_top = %.2f N, T_thrust = %.2f N\n",
        d_slack.T_cyan,
        d_slack.T_bridle,
        d_slack.T_top,
        d_slack.T_thrust
    )

    # If T_cyan is T_cyan_2x2:
    T_cyan_ax_taut = -T_cyan_2x2 * dot(cyan_dir, sh)
    T_bridle_taut = max(
        (T_cyan_ax_taut - KTD.BEARING_MASS_KG * 9.81 * sin(β)) / (p.n_lines * d_slack.cosθ),
        0.0,
    )
    T_top_taut =
        d_slack.T_thrust + p.n_lines * T_bridle_taut * d_slack.cosθ -
        d_slack.W_rotor * sin(β)
    println("\nCandidate Taut lift_chain_design:")
    @printf(
        "  T_cyan = %.2f N, T_bridle = %.2f N, T_top = %.2f N (diff: %+.2f N)\n",
        T_cyan_2x2,
        T_bridle_taut,
        T_top_taut,
        T_top_taut - d_slack.T_top
    )

    # Check demand on campaign seed with T_top_taut
    n_seg = sys.n_ring - 1
    g_inc = p.m_ring * 9.81 * sin(β)
    F_ax_taut = zeros(n_seg)
    F_ax_taut[n_seg] = T_top_taut
    for i in (n_seg - 1):-1:1
        F_ax_taut[i] = F_ax_taut[i + 1] + g_inc
    end
    τ_eq = sys.k_mppt_ref[] * 13.452^2
    r_taut = KTD.trpt_matched_place(
        sys, p, F_ax_taut, τ_eq, 13.452, wf; raise_on_unrealisable=false
    )
    @printf(
        "  Demand on Campaign Seed: max demand = %.4f (binding seg %d), target = %.4f\n",
        maximum(r_taut.demand),
        argmax(r_taut.demand),
        1.0 / KTD.TRPT_REALISABILITY_TENSION_MARGIN
    )
end

run_probe()
