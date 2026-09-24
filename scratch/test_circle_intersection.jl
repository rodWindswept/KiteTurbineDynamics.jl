# scratch/test_circle_intersection.jl
using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const KTD = KiteTurbineDynamics
pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )

    hub_settled = pos(u, sys.rotor.node_id)
    bearing_settled = pos(u, sys.bearing_id)
    sky_settled = pos(u, sys.sky_anchor_id)

    hub_0 = pos(u0, sys.rotor.node_id)
    R_hub = (sys.nodes[sys.rotor.node_id]::RingNode).radius
    bo = KTD.bridle_bearing_offset(R_hub)
    β = p.elevation_angle
    sh = [cos(β), 0.0, sin(β)]

    back_ax = p.tether_length * cos(β) + p.back_anchor_fwd_x
    L_axis_design = p.tether_length + bo + KTD.CYAN_L0_DESIGN
    dsa_x = L_axis_design * cos(β)
    dsa_z = L_axis_design * sin(β)
    back_L0_design = sqrt((dsa_x - back_ax)^2 + dsa_z^2)

    println("=== Circles in (x, z) ===")
    @printf(
        "Center 1 (back anchor): [%.4f, 0.0, 0.0], R1 = %.4f m\n", back_ax, back_L0_design
    )

    # Let center 2 be bearing_settled
    C1 = [back_ax, 0.0]
    C2 = [bearing_settled[1], bearing_settled[3]]
    R1 = back_L0_design
    R2 = KTD.CYAN_L0_DESIGN

    d_vec = C2 .- C1
    d = norm(d_vec)
    @printf(
        "Center 2 (bearing settled): [%.4f, %.4f], R2 = %.4f m, d = %.4f m\n",
        C2[1],
        C2[2],
        R2,
        d
    )

    a = (R1^2 - R2^2 + d^2) / (2 * d)
    h = sqrt(max(0.0, R1^2 - a^2))
    u_d = d_vec ./ d
    u_perp = [-u_d[2], u_d[1]] # perpendicular in (x, z)

    # Two intersection points
    P_plus = C1 .+ a .* u_d .+ h .* u_perp
    P_minus = C1 .+ a .* u_d .- h .* u_perp

    # The higher z point:
    P_top = P_plus[2] > P_minus[2] ? P_plus : P_minus
    @printf("Circle intersection sky pos = [%.4f, %.4f]\n", P_top[1], P_top[2])
    @printf("Actual settled sky pos      = [%.4f, %.4f]\n", sky_settled[1], sky_settled[3])
    @printf(
        "Difference: dx = %+.4f m, dz = %+.4f m (norm = %.4f m)\n",
        P_top[1] - sky_settled[1],
        P_top[2] - sky_settled[3],
        norm([P_top[1] - sky_settled[1], P_top[2] - sky_settled[3]])
    )

    # Let's check 2x2 with circle intersection unit vectors
    sky_circ = [P_top[1], 0.0, P_top[2]]
    cyan_dir = normalize(bearing_settled .- sky_circ)
    back_dir = normalize([back_ax, 0.0, 0.0] .- sky_circ)

    _, T_lift, el_deg = KTD.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    el = deg2rad(el_deg)
    lift_dir = [cos(el), 0.0, sin(el)]
    F_lift = T_lift .* lift_dir
    W_sky = [0.0, 0.0, -KTD.SKY_ANCHOR_MASS_KG * 9.81]

    sol =
        [cyan_dir[1] back_dir[1]; cyan_dir[3] back_dir[3]] \
        [-(F_lift[1] + W_sky[1]), -(F_lift[3] + W_sky[3])]
    @printf(
        "2x2 with circle-intersection dirs: T_cyan = %.2f N, T_back = %.2f N\n",
        sol[1],
        sol[2]
    )
end

main()
