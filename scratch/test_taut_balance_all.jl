# scratch/test_taut_balance_all.jl
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const KTD = KiteTurbineDynamics

function solve_taut_sky_anchor(p, lift_device, hub_pos, R_hub, β, sh)
    bearing_offset = KTD.bridle_bearing_offset(R_hub)
    bearing_pos = hub_pos .+ bearing_offset .* sh
    sky_pos = bearing_pos .+ KTD.CYAN_L0_DESIGN .* sh
    cyan_dir = normalize(bearing_pos .- sky_pos)
    back_ax = p.tether_length * cos(β) + p.back_anchor_fwd_x
    back_pos = [back_ax, 0.0, 0.0]
    back_dir = normalize(back_pos .- sky_pos)

    _, T_lift, el_deg = KTD.lift_force_steady(lift_device, p.rho, p.v_wind_ref, p)
    el = deg2rad(el_deg)
    lift_dir = [cos(el), 0.0, sin(el)]
    F_lift = T_lift .* lift_dir
    W_sky = [0.0, 0.0, -KTD.SKY_ANCHOR_MASS_KG * 9.81]

    # Slack 1D balance
    T_cyan_slack = max(-dot(F_lift .+ W_sky, cyan_dir), 0.0)

    # 2x2 Taut balance: T_cyan * cyan_dir + T_back * back_dir = -(F_lift + W_sky)
    detA = cyan_dir[1] * back_dir[3] - cyan_dir[3] * back_dir[1]
    rhs = [-(F_lift[1] + W_sky[1]), -(F_lift[3] + W_sky[3])]
    sol = [cyan_dir[1] back_dir[1]; cyan_dir[3] back_dir[3]] \ rhs
    T_cyan_2x2, T_back_2x2 = sol[1], sol[2]

    # Tension-only logic:
    if T_back_2x2 <= 0.0
        T_cyan = T_cyan_slack
        T_back = 0.0
    elseif T_cyan_2x2 <= 0.0
        T_cyan = 0.0
        T_back = max(-dot(F_lift .+ W_sky, back_dir), 0.0)
    else
        T_cyan = T_cyan_2x2
        T_back = T_back_2x2
    end

    return (;
        T_cyan,
        T_back,
        T_cyan_slack,
        T_cyan_2x2,
        T_back_2x2,
        detA,
        cyan_dir,
        back_dir,
        T_lift,
        el_deg,
    )
end

function check_case(label, sys, u0, p, lift)
    hub_gid = sys.rotor.node_id
    R_hub = (sys.nodes[hub_gid]::RingNode).radius
    hub_pos = u0[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
    β = p.elevation_angle
    sh = [cos(β), 0.0, sin(β)]

    res = solve_taut_sky_anchor(p, lift, hub_pos, R_hub, β, sh)
    @printf(
        "Case: %-25s | el=%4.1f | T_lift=%6.1f N | Slack T_cyan=%6.1f N | Taut: T_cyan=%6.1f N, T_back=%6.1f N\n",
        label,
        res.el_deg,
        res.T_lift,
        res.T_cyan_slack,
        res.T_cyan,
        res.T_back
    )
end

function main()
    println("Checking sky-anchor taut balance across cases:")
    # 1. Campaign seed
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    check_case("Campaign seed (5 kW)", sys, u0, p, lift)

    # 2. SEED_LR20
    sys, u0, p, lift, wf = build_case(6, 1.0; genome=SEED_LR20)
    check_case("SEED_LR20 (12 rings)", sys, u0, p, lift)

    # 3. 4 lines, 3 rotors
    sys, u0, p, lift, wf = build_case(4, 3.0)
    check_case("4 lines, 3 rotors", sys, u0, p, lift)

    # 4. 6 lines, 1 rotor
    sys, u0, p, lift, wf = build_case(6, 1.0)
    return check_case("6 lines, 1 rotor", sys, u0, p, lift)
end

main()
