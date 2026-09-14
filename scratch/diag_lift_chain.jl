# scratch/diag_lift_chain.jl
#
# SELF-CHECKING force audit of the LIFT CHAIN on the 5 kW / 18.8 m seed, at the
# operational settle.  Question (Rod 2026-09-13): what is breaking in the lift
# chain — why does the lift not reach the rotor?
#
# It reports, for the sky anchor and the lift bearing:
#   - position vs its design position (the design axis is the STRAIGHT design;
#     no pre-bow is assumed anywhere);
#   - every link's rest length, current length and tension
#     (lift line = gated external force; cyan = spring; bridles = springs;
#     backline = tension-only catenary);
#   - the net force from m*du, and the sum of the identified contributors, so a
#     mismatch is visible instead of assumed.
#
# Refuses to report if the residual does not respond to a perturbation.
#
#   scripts/ktd-julia scratch/diag_lift_chain.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
using KiteTurbineDynamics: RopeSubSegment

include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const OMEGA_EQ = 12.983466

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
                           tether_length=18.8)
end

function build_case()
    p = params_5kw_188()
    x = seed_genome(5.0)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    cfg = ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        k_mppt=K_MPPT_5KW_HONEST)
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3, beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = sized_lifter_for(sys, pc; margin=1.5, v_ref=11.0, const_tension=true)
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, lift, wf
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

function main()
    sys, u0, p, lift, wf = build_case()
    N, Nr = sys.n_total, sys.n_ring
    hub, bear, sky = sys.rotor.node_id, sys.bearing_id, sys.sky_anchor_id
    sd = [cos(p.elevation_angle), 0.0, sin(p.elevation_angle)]

    u = KiteTurbineDynamics.settle_to_operational_state(sys, copy(u0), p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=2_000)

    # ── self-check: residual must respond ───────────────────────────────────
    du0 = zeros(length(u)); KiteTurbineDynamics.multibody_ode!(du0, u, (sys, p, wf, lift), 0.0)
    up = copy(u); up[3 * (sky - 1) + 3] += 1e-3
    du1 = zeros(length(up)); KiteTurbineDynamics.multibody_ode!(du1, up, (sys, p, wf, lift), 0.0)
    resp = maximum(norm(du1[(3N + 3 * (g - 1) + 1):(3N + 3 * g)] .-
                        du0[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]) for g in 2:N)
    @printf("[self-check] perturbing the sky anchor changes the residual by %.3e -> %s\n",
        resp, resp > 1e-9 ? "PASS" : "FAIL")
    resp > 1e-9 || error("harness broken; refusing to report")

    # ── geometry along the design axis ──────────────────────────────────────
    println("\n── positions (design axis s, perpendicular r) ─────────────────────────")
    @printf("  %-14s %10s %10s %10s\n", "node", "s_axial", "r_perp", "|pos|")
    for (nm, g) in (("ground ring", sys.ring_ids[1]), ("main rotor", hub),
                    ("lift bearing", bear), ("sky anchor", sky))
        c = pos(u, g)
        @printf("  %-14s %10.4f %10.4f %10.4f\n", nm,
            dot(c, sd), norm(c .- dot(c, sd) .* sd), norm(c))
    end
    kite = sys.kite_pos
    @printf("  %-14s %10.4f %10.4f %10.4f\n", "kite", dot(kite, sd),
        norm(kite .- dot(kite, sd) .* sd), norm(kite))

    # ── link inventory ──────────────────────────────────────────────────────
    println("\n── links ──────────────────────────────────────────────────────────────")
    for (tag, islink) in (("cyan (sky<->bearing)", ss -> (ss.end_a.node_id == bear && ss.end_b.node_id == sky) ||
                                                        (ss.end_a.node_id == sky && ss.end_b.node_id == bear)),
                          ("bridle (bearing<->rotor)", ss -> (ss.end_a.node_id == bear && ss.end_b.node_id == hub) ||
                                                             (ss.end_a.node_id == hub && ss.end_b.node_id == bear)))
        for ss in sys.sub_segs
            islink(ss) || continue
            a = ss.end_a.is_ring ?
                attachment_point(pos(u, ss.end_a.node_id),
                    (sys.nodes[ss.end_a.node_id]::RingNode).radius, u[6N + (sys.nodes[ss.end_a.node_id]::RingNode).ring_idx],
                    ss.end_a.line_idx, p.n_lines,
                    KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)...) :
                pos(u, ss.end_a.node_id)
            b = ss.end_b.is_ring ?
                attachment_point(pos(u, ss.end_b.node_id),
                    (sys.nodes[ss.end_b.node_id]::RingNode).radius, u[6N + (sys.nodes[ss.end_b.node_id]::RingNode).ring_idx],
                    ss.end_b.line_idx, p.n_lines,
                    KiteTurbineDynamics._tilted_ring_basis(u, sys, hub, Nr)...) :
                pos(u, ss.end_b.node_id)
            L = norm(b .- a)
            T = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
            @printf("  %-26s L0=%9.5f  L=%9.5f  %s T=%9.4f N\n",
                tag, ss.length_0, L, L < ss.length_0 ? "SLACK" : "taut ", T)
        end
    end

    # ── lift line gate ──────────────────────────────────────────────────────
    v_lift = wf(pos(u, sky), 0.0)
    v_hmag = hypot(v_lift[1], v_lift[2])
    _, T_lift, elev = lift_force_steady(lift, p.rho, v_hmag, p)
    line_dist = norm(kite .- pos(u, sky))
    @printf("  %-26s L0=%9.5f  L=%9.5f  T_ref=%8.2f N  gate(>=0.99*L0)=%s\n",
        "lift line (kite<->sky)", lift.line_length, line_dist, T_lift,
        line_dist >= 0.99 * lift.line_length ? "OPEN (force applied)" : "CLOSED (force ZERO)")
    @printf("  %-26s v_hub=%.3f m/s  elevation=%.1f deg\n", "lift device", v_hmag, elev)

    # ── backline ────────────────────────────────────────────────────────────
    back_ax = p.tether_length * cos(p.elevation_angle) + p.back_anchor_fwd_x
    L_axis_design = p.tether_length + 6.0 + 5.0
    back_L0 = hypot(L_axis_design * cos(p.elevation_angle) - back_ax,
                    L_axis_design * sin(p.elevation_angle)) + p.backline_payout
    b_dist = hypot(pos(u, sky)[1] - back_ax, pos(u, sky)[2], pos(u, sky)[3])
    @printf("  %-26s L0=%9.5f  L=%9.5f  %s\n", "backline (sky<->anchor)", back_L0, b_dist,
        b_dist > back_L0 + 1e-6 ? "TAUT " : "SLACK")

    # ── force audit on sky anchor and bearing ───────────────────────────────
    println("\n── force audit (N): gravity + identified link forces vs m*du ──────────")
    for (nm, g) in (("sky anchor", sky), ("lift bearing", bear))
        node = sys.nodes[g]
        m = node.mass
        net = m .* du0[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]
        grav = [0.0, 0.0, -m * 9.81]
        links = zeros(3)
        for ss in sys.sub_segs
            (ss.end_a.node_id == g || ss.end_b.node_id == g) || continue
            # skip the TRPT lines here — they are the transmission, not the chain
            a, b = ss.end_a.node_id, ss.end_b.node_id
            ischain = (a in (bear, sky, hub) && b in (bear, sky, hub))
            ischain || continue
            pa = pos(u, a); pb = pos(u, b)
            L = norm(pb .- pa)
            T = ss.EA * max(0.0, (L - ss.length_0) / ss.length_0)
            dir = L > 1e-12 ? (pb .- pa) ./ L : zeros(3)
            links .+= (a == g ? T .* dir : -T .* dir)
        end
        lift_force = zeros(3)
        if g == sky && T_lift > 0.0 && line_dist >= 0.99 * lift.line_length
            lift_force = T_lift .* ((kite .- pos(u, sky)) ./ line_dist)
        end
        @printf("  %-13s m=%8.4f kg  gravity=(%8.3f,%8.3f,%8.3f)  chain_links=(%8.3f,%8.3f,%8.3f)  lift=(%8.3f,%8.3f,%8.3f)\n",
            nm, m, grav..., links..., lift_force...)
        @printf("  %-13s m*du=(%8.3f,%8.3f,%8.3f)   identified=(%8.3f,%8.3f,%8.3f)   |a|=%8.3f m/s2\n",
            "", net..., (grav .+ links .+ lift_force)..., norm(du0[(3N + 3 * (g - 1) + 1):(3N + 3 * g)]))
    end

    # ── bridle cone geometry vs the design intent ───────────────────────────
    d_hb = pos(u, bear) .- pos(u, hub)
    s_hb = dot(d_hb, sd)
    r_hb = norm(d_hb .- s_hb .* sd)
    R_hub = (sys.nodes[hub]::RingNode).radius
    @printf("\n── bridle cone ────────────────────────────────────────────────────────\n")
    @printf("  bearing-to-rotor: axial=%.4f m  perpendicular=%.4f m  3D=%.4f m\n",
        s_hb, r_hb, norm(d_hb))
    @printf("  rotor ring radius R=%.4f m  -> apex half-angle from axis = %.2f deg  angle at ring plane = %.2f deg\n",
        R_hub, rad2deg(atan(R_hub, abs(s_hb))), rad2deg(atan(abs(s_hb), R_hub)))
    @printf("  all bridles same rest length?  %s\n",
        length(unique(round.([ss.length_0 for ss in sys.sub_segs
            if (ss.end_a.node_id == bear && ss.end_b.node_id == hub) ||
               (ss.end_a.node_id == hub && ss.end_b.node_id == bear)], digits=9))) == 1 ? "YES" : "NO")
    return nothing
end

main()
