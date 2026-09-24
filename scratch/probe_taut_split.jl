# scratch/probe_taut_split.jl
#
# 2026-09-19.  ACTIVE.md item 2, remaining half: the sky-anchor load split with the
# back line TAUT.  Measures, on the campaign seed at the SOLVED equilibrium:
#
#   * the sky-anchor geometry and lift vector,
#   * the current SLACK split (T_cyan the cyan line must carry alone),
#   * the TAUT 2x2 balance (T_cyan, T_back) using the actual back-line direction,
#   * the back-line distance and what `back_line_tension` returns there today,
#   * the resulting T_top and torsional demand under each split.
#
# No src changes: this is the measurement the re-derivation has to be built on.

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))

const KTD = KiteTurbineDynamics

function cyan_tension(u, sys, p)
    total = 0.0
    for ss in sys.sub_segs
        na, nb = ss.end_a.node_id, ss.end_b.node_id
        (
            (na == sys.sky_anchor_id && nb == sys.bearing_id) ||
            (na == sys.bearing_id && nb == sys.sky_anchor_id)
        ) || continue
        L = norm(
            u[(3 * (ss.end_b.node_id - 1) + 1):(3 * ss.end_b.node_id)] .-
            u[(3 * (ss.end_a.node_id - 1) + 1):(3 * ss.end_a.node_id)],
        )
        total += ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
    end
    return total
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    sys, u0, p, lift, wf = build_case(nothing, nothing)
    N, Nr = sys.n_total, sys.n_ring
    u = settle_to_operational_state(
        sys, copy(u0), p, 60.0; lift_device=lift, wind_fn=wf, n_op=300_000
    )
    ω = u[6N + Nr + 1]
    hub = pos(u, sys.rotor.node_id)
    bearing = pos(u, sys.bearing_id)
    sky = pos(u, sys.sky_anchor_id)

    β = p.elevation_angle
    sh = [cos(β), 0.0, sin(β)]
    back_ax = p.tether_length * cos(β) + p.back_anchor_fwd_x
    back_pos = [back_ax, 0.0, 0.0]
    cyan_dir = normalize(bearing .- sky)
    back_dir = normalize(back_pos .- sky)

    _, T_lift, el_deg = lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    el = deg2rad(el_deg)
    lift_dir = [cos(el), 0.0, sin(el)]
    m_sky = KTD.SKY_ANCHOR_MASS_KG
    W_sky = [0.0, 0.0, -m_sky * 9.81]

    # ── current code: back line SLACK ────────────────────────────────────────
    T_cyan_slack = max(-dot(T_lift .* lift_dir .+ W_sky, cyan_dir), 0.0)

    # ── taut 2x2 balance ─────────────────────────────────────────────────────
    A = [cyan_dir[1] back_dir[1]; cyan_dir[3] back_dir[3]]
    rhs = [-T_lift * lift_dir[1]; -T_lift * lift_dir[3] - W_sky[3]]
    sol = A \ rhs
    T_cyan_taut, T_back_taut = sol[1], sol[2]

    # ── back-line geometry / current constitutive law ────────────────────────
    b_dx = sqrt((sky[1] - back_ax)^2 + sky[2]^2)
    b_dz = sky[3]
    b_dist = sqrt(b_dx^2 + b_dz^2)
    L_axis_design =
        p.tether_length +
        KTD.bridle_bearing_offset((sys.nodes[sys.rotor.node_id]::RingNode).radius) +
        KTD.CYAN_L0_DESIGN
    dsa_x = L_axis_design * cos(β)
    dsa_z = L_axis_design * sin(β)
    back_L0_design = sqrt((dsa_x - back_ax)^2 + dsa_z^2)
    T_back_law = KTD.back_line_tension(
        b_dist, back_L0_design, p.backline_payout, p.EA_back_line
    )
    travel = KTD.BACK_LINE_SOFT_TRAVEL_M
    T_design_code = KTD.BACK_LINE_E_SUM_N / (1.0 + travel / back_L0_design)

    @printf("=== campaign seed, solved equilibrium (ω=%.4f) ===\n", ω)
    @printf("  hub      = [%8.3f %8.3f %8.3f]\n", hub...)
    @printf("  bearing  = [%8.3f %8.3f %8.3f]\n", bearing...)
    @printf("  sky      = [%8.3f %8.3f %8.3f]\n", sky...)
    @printf("  back_ax  = %.4f m   |sky-anchor| = %.4f m\n", back_ax, norm(sky))
    @printf("  T_lift   = %.2f N at el = %.2f deg\n", T_lift, el_deg)
    @printf(
        "  cyan_dir = [%7.4f %7.4f %7.4f]   back_dir = [%7.4f %7.4f %7.4f]\n",
        cyan_dir...,
        back_dir...
    )

    @printf("\n  -- sky-anchor balance --\n")
    @printf("  SLACK (current code): T_cyan = %8.2f N   T_back =    0.00 N\n", T_cyan_slack)
    @printf(
        "  TAUT  (2x2 solve):    T_cyan = %8.2f N   T_back = %8.2f N\n",
        T_cyan_taut,
        T_back_taut
    )
    @printf(
        "  measured cyan-line tension in the solved state = %.2f N\n",
        cyan_tension(u, sys, p)
    )

    @printf("\n  -- back-line geometry --\n")
    @printf(
        "  b_dist = %.4f m   back_L0_design = %.4f m   (d - L0) = %+.4f m\n",
        b_dist,
        back_L0_design,
        b_dist - back_L0_design
    )
    @printf(
        "  soft travel = %.2f m;  in-travel span = [%.4f, %.4f] m\n",
        travel,
        back_L0_design - travel,
        back_L0_design
    )
    @printf(
        "  back_line_tension(b_dist)  = %.4f N   (T_design_code = %.4f N)\n",
        T_back_law,
        T_design_code
    )
    @printf(
        "  => the line is %s the hard stop\n",
        b_dist >= back_L0_design ? "BEYOND" : "SHORT OF"
    )

    # ── effect on T_top ──────────────────────────────────────────────────────
    R_hub = (sys.nodes[sys.rotor.node_id]::RingNode).radius
    bearing_offset = KTD.bridle_bearing_offset(R_hub)
    perp1, perp2 = KTD.shaft_perp_basis(sh)
    pa = KTD.attachment_point(hub, R_hub, 0.0, 1, p.n_lines, perp1, perp2)
    gap = norm((hub .+ bearing_offset .* sh) .- pa)
    cosθ = bearing_offset / gap
    v_hub = p.v_wind_ref * sys.rotor.wind_factor
    λ = abs(ω) * sys.rotor.radius / max(v_hub, 1e-6)
    T_thrust =
        0.5 * p.rho * v_hub^2 * KTD.main_rotor_swept_area(sys) * KTD.ct_at_tsr(λ) * cos(β)^2
    W_rotor = p.n_blades * p.m_blade * 9.81
    function t_top(T_cyan)
        T_cyan_ax = -T_cyan * dot(cyan_dir, sh)
        T_bridle = max(
            (T_cyan_ax - KTD.BEARING_MASS_KG * 9.81 * sin(β)) / (p.n_lines * cosθ), 0.0
        )
        return T_thrust + p.n_lines * T_bridle * cosθ - W_rotor * sin(β)
    end
    @printf("\n  -- T_top --\n")
    @printf(
        "  thrust   = %.2f N   W_rotor*sinβ = %.2f N   cosθ = %.4f\n",
        T_thrust,
        W_rotor * sin(β),
        cosθ
    )
    @printf("  T_top (slack cyan) = %.2f N\n", t_top(T_cyan_slack))
    @printf(
        "  T_top (taut  cyan) = %.2f N   (%+.2f N vs slack)\n",
        t_top(T_cyan_taut),
        t_top(T_cyan_taut) - t_top(T_cyan_slack)
    )

    # demand at the verified equilibrium tension (the metric the guard uses)
    τ_eq = sys.k_mppt_ref[] * ω^2
    ef = KTD.capture_extended(u, sys, p, 0.0, wf, lift)
    T_meas = ef.segment_tension .* p.n_lines
    place = KTD.trpt_matched_place(sys, p, T_meas, τ_eq, ω, wf; raise_on_unrealisable=false)
    @printf(
        "  demand at the equilibrium tension = %.4f   (target %.4f)\n",
        maximum(place.demand),
        1.0 / KTD.TRPT_REALISABILITY_TENSION_MARGIN
    )
    return println("=== done ===")
end

main()
