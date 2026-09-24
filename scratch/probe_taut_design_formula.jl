# scratch/probe_taut_design_formula.jl
#
# 2026-09-20.  Validate the candidate `lift_chain_design` replacement BEFORE
# touching src/: solve the sky-anchor 2x2 in the form the design function can
# actually compute it (back anchor at
# `tether_length*cos(β) + back_anchor_fwd_x`, sky anchor on the shaft from the
# passed-in hub position) and compare against the settled-equilibrium direction
# the 2026-09-19 probe measured (`scratch/probe_taut_split.jl`).
#
# Also reports what each candidate `T_design` does to the settled back-line
# distance, since the ODE hard-stop position is an output of the force balance.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const KTD = KiteTurbineDynamics
pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function cyan_tension(u, sys, p)
    total = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (
            (na == sys.sky_anchor_id && nb == sys.bearing_id) ||
            (na == sys.bearing_id && nb == sys.sky_anchor_id)
        ) || continue
        L = norm(pos(u, ss.end_b.node_id) .- pos(u, ss.end_a.node_id))
        total += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return total
end

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    ω = u[6N + Nr + 1]

    # ── the DESIGN-FORMULA geometry: hub as placed, sky/bearing on the shaft ──
    hub = pos(u, sys.rotor.node_id)
    R_hub = (sys.nodes[sys.rotor.node_id]::RingNode).radius
    bo = KTD.bridle_bearing_offset(R_hub)
    β = p.elevation_angle
    sh = [cos(β), 0.0, sin(β)]
    bearing_design = hub .+ bo .* sh
    sky_design = bearing_design .+ KTD.CYAN_L0_DESIGN .* sh
    cyan_dir = normalize(bearing_design .- sky_design)
    back_ax = p.tether_length * cos(β) + p.back_anchor_fwd_x
    back_design = [back_ax, 0.0, 0.0]
    back_dir = normalize(back_design .- sky_design)

    _, T_lift, el_deg = KTD.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    el = deg2rad(el_deg)
    lift_dir = [cos(el), 0.0, sin(el)]
    W_sky = [0.0, 0.0, -KTD.SKY_ANCHOR_MASS_KG * 9.81]

    T_cyan_slack = max(-dot(T_lift .* lift_dir .+ W_sky, cyan_dir), 0.0)
    A = [back_dir[1] cyan_dir[1]; back_dir[3] cyan_dir[3]]
    rhs = [-T_lift * lift_dir[1]; -T_lift * lift_dir[3] + KTD.SKY_ANCHOR_MASS_KG * 9.81]
    sol = A \ rhs
    T_back_taut, T_cyan_taut = sol[1], sol[2]

    # ── the SETTLED geometry, for the comparison ─────────────────────────────
    sky_settled = pos(u, sys.sky_anchor_id)
    back_dir_settled = normalize(back_design .- sky_settled)
    A2 = [back_dir_settled[1] cyan_dir[1]; back_dir_settled[3] cyan_dir[3]]
    sol2 = A2 \ rhs

    @printf("=== design-formula vs settled-direction 2x2 ===\n")
    @printf("  hub        = [%8.4f %8.4f %8.4f]\n", hub...)
    @printf("  sky(design)= [%8.4f %8.4f %8.4f]\n", sky_design...)
    @printf("  sky(settled)=[%8.4f %8.4f %8.4f]\n", sky_settled...)
    @printf("  back_dir(design)  = [%8.5f %8.5f %8.5f]\n", back_dir...)
    @printf("  back_dir(settled) = [%8.5f %8.5f %8.5f]\n", back_dir_settled...)
    @printf("  T_lift = %.3f N at el = %.3f deg\n", T_lift, el_deg)
    @printf("  SLACK      : T_cyan = %8.3f N  T_back = 0\n", T_cyan_slack)
    @printf("  TAUT design: T_cyan = %8.3f N  T_back = %8.3f N\n", T_cyan_taut, T_back_taut)
    @printf("  TAUT settle: T_cyan = %8.3f N  T_back = %8.3f N\n", sol2[2], sol2[1])
    @printf("  measured in the settled state: T_cyan = %.3f N\n", cyan_tension(u, sys, p))

    # ── back-line branch at the settled state, for several T_design ──────────
    L_axis = p.tether_length + bo + KTD.CYAN_L0_DESIGN
    dsa_x = L_axis * cos(β)
    dsa_z = L_axis * sin(β)
    back_L0 = sqrt((dsa_x - back_ax)^2 + dsa_z^2)
    b_dx = sqrt((sky_settled[1] - back_ax)^2 + sky_settled[2]^2)
    b_dist = sqrt(b_dx^2 + sky_settled[3]^2)
    @printf(
        "\n  back_L0_design = %.5f m   b_dist(settled) = %.5f m   (d-L0) = %+.5f m\n",
        back_L0,
        b_dist,
        b_dist - back_L0
    )
    travel = KTD.BACK_LINE_SOFT_TRAVEL_M
    @printf(
        "  travel = %.2f m; in-travel span = [%.4f, %.4f]\n",
        travel,
        back_L0 - travel,
        back_L0
    )
    for Td in (KTD.BACK_LINE_E_SUM_N / (1 + travel / back_L0), 320.0, 351.0)
        k_soft = Td / travel
        EA = p.EA_back_line
        Tnow = if b_dist >= back_L0
            Td + EA * (b_dist - back_L0) / back_L0
        elseif b_dist > back_L0 - travel
            k_soft * (b_dist - back_L0 + travel)
        else
            0.0
        end
        @printf(
            "  T_design = %8.3f N -> k_soft = %8.2f N/m, T at settled d = %8.3f N\n",
            Td,
            k_soft,
            Tnow
        )
    end
    return println("=== done ===")
end

main()
