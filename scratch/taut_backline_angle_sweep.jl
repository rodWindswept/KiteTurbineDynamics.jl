# scratch/taut_backline_angle_sweep.jl
#
# Re-derive the design-chain load split with a RIGID TAUT back line (Rod
# 2026-09-15), then sweep the lift-line elevation to find the band where the back
# line stays just taut AND the cyan line clears the torsional floor.
#
# This replaces the 2026-09-13 assumption (back line SLACK at the design point,
# `scratch/design_chain_preload.jl`).  Same seed, same omega, same closed form —
# only the back-line model changes, so the numbers are directly comparable to the
# 1150 N / 1274.47 N pair on the record.
#
# Off-design: the back line is 8 bungee sections sewn IN SERIES (Rod 2026-09-15);
# each rests at 30 cm and is at 40 cm at full tension, so the line has 80 cm of
# soft travel and hardens at the design length.  `k_soft = T_back_design / 0.8`
# N/m follows from that spec with no extra field data.
#
#   scripts/ktd-julia scratch/taut_backline_angle_sweep.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const BRIDLE_EA = 500_000.0
const BEARING_MASS = 0.3
const SKY_MASS = 0.3
const CYAN_L0 = 5.0
const OMEGA_EQ = 12.983466                 # seed equilibrium, as the 09-13 probe
const MARGIN = KiteTurbineDynamics.TRPT_REALISABILITY_TENSION_MARGIN
const BUNGEE_TRAVEL_M = 0.80               # 8 sections x 10 cm

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius, 18.8,
        p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades,
    )
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev
    )
    back = BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout
    )
    return override_params(
        mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
        tether_length=18.8,
    )
end

function build_case()
    p = params_5kw_188()
    x = seed_genome(5.0)
    x[4] = Float64(round(Int, clamp(x[4], 3, 16)))
    x[6] = Float64(round(Int, clamp(x[6], 1, 3)))
    dec = KiteTurbineDynamics.design_from_vector_v10(
        x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
    cfg = ObjectiveConfig(;
        power_W=5000.0, v_rated=11.0, p_floor_kw=5.0, p_ceiling_kw=5.0,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW, k_mppt=K_MPPT_5KW_HONEST,
    )
    sizing = size_beams_closed_form(dec, p, cfg)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p.tether_diameter, base_params=p, min_wall_m=2e-3,
        beam_sizing=sizing,
    )
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    wf = (r, t) -> [11.0 * (max(r[3], 1.0) / p.h_ref)^(1 / 7), 0.0, 0.0]
    return sys, u0, pc, wf
end

pos(u, gid) = u[(3 * (gid - 1) + 1):(3 * gid)]

"""
Taut sky-anchor balance.  Returns the 2x2 solution for `[T_back, T_cyan]` and the
Section A/B chain.  `T_back < 0` means the back line cannot be taut at this angle.
"""
function chain_taut(hub_pos, sh, perp1, perp2, p, R_hub, T_lift, el_deg, T_thrust, W_rotor)
    β = p.elevation_angle
    n = p.n_lines
    bo = KiteTurbineDynamics.bridle_bearing_offset(R_hub)
    bearing_pos = hub_pos .+ bo .* sh
    sky_pos = bearing_pos .+ CYAN_L0 .* sh
    back_ax = p.tether_length * cos(β) + p.back_anchor_fwd_x
    back_dir = normalize([back_ax, 0.0, 0.0] .- sky_pos)
    cyan_dir = normalize(bearing_pos .- sky_pos)

    el = deg2rad(el_deg)
    A = [back_dir[1] cyan_dir[1]; back_dir[3] cyan_dir[3]]
    rhs = [-T_lift * cos(el); -T_lift * sin(el) + SKY_MASS * 9.81]
    sol = A \ rhs
    T_back, T_cyan = sol[1], sol[2]

    T_cyan_ax = -T_cyan * dot(cyan_dir, sh)
    pa = attachment_point(hub_pos, R_hub, 0.0, 1, n, perp1, perp2)
    gap = norm(bearing_pos .- pa)
    cosθ = bo / gap
    T_bridle = (T_cyan_ax - BEARING_MASS * 9.81 * sin(β)) / (n * cosθ)
    T_top = T_thrust + n * T_bridle * cosθ - W_rotor * sin(β)
    return (; T_back, T_cyan, T_bridle, T_top, cosθ, gap)
end

"""Slack sky-anchor balance: cyan alone carries lift + sky weight."""
function chain_slack(hub_pos, sh, perp1, perp2, p, R_hub, T_lift, el_deg, T_thrust, W_rotor)
    β = p.elevation_angle
    n = p.n_lines
    bo = KiteTurbineDynamics.bridle_bearing_offset(R_hub)
    bearing_pos = hub_pos .+ bo .* sh
    sky_pos = bearing_pos .+ CYAN_L0 .* sh
    cyan_dir = normalize(bearing_pos .- sky_pos)
    el = deg2rad(el_deg)
    lift_dir = [cos(el), 0.0, sin(el)]
    T_cyan = max(-dot(T_lift .* lift_dir .+ [0.0, 0.0, -SKY_MASS * 9.81], cyan_dir), 0.0)
    T_cyan_ax = -T_cyan * dot(cyan_dir, sh)
    pa = attachment_point(hub_pos, R_hub, 0.0, 1, n, perp1, perp2)
    gap = norm(bearing_pos .- pa)
    cosθ = bo / gap
    T_bridle = (T_cyan_ax - BEARING_MASS * 9.81 * sin(β)) / (n * cosθ)
    T_top = T_thrust + n * T_bridle * cosθ - W_rotor * sin(β)
    return (; T_back=0.0, T_cyan, T_bridle, T_top, cosθ, gap)
end

function axial_profile(p, sys, F_top)
    n_seg = sys.n_ring - 1
    g_inc = p.m_ring * 9.81 * sin(p.elevation_angle)
    F = zeros(n_seg)
    F[n_seg] = F_top
    for i in (n_seg - 1):-1:1
        F[i] = F[i + 1] + g_inc
    end
    return F
end

"""Worst per-segment realisability demand `max(τ_carry/τ_max)` at this preload."""
function demand_at(sys, p, wf, F_top, τ_eq)
    place = KiteTurbineDynamics.trpt_matched_place(
        sys, p, axial_profile(p, sys, F_top), τ_eq, OMEGA_EQ, wf;
        raise_on_unrealisable=false,
    )
    return maximum(place.demand)
end

"""Tension at which the worst segment's demand equals `1/MARGIN` (geometric bisection)."""
function floor_ftop(sys, p, wf, τ_eq; lo=100.0, hi=20_000.0)
    target = 1.0 / MARGIN
    @assert demand_at(sys, p, wf, lo, τ_eq) > target "floor bracket (lo) already clears"
    @assert demand_at(sys, p, wf, hi, τ_eq) < target "floor bracket (hi) does not clear"
    for _ in 1:80
        mid = sqrt(lo * hi)
        if demand_at(sys, p, wf, mid, τ_eq) > target
            lo = mid
        else
            hi = mid
        end
    end
    return hi
end

function main()
    sys, u0, p, wf = build_case()
    hub = sys.rotor.node_id
    β = p.elevation_angle
    sh = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(sh)
    R_hub = (sys.nodes[hub]::RingNode).radius
    hub_pos = pos(u0, hub)
    n = p.n_lines

    v_hub = p.v_wind_ref * sys.rotor.wind_factor
    λ = OMEGA_EQ * sys.rotor.radius / v_hub
    A_sw = KiteTurbineDynamics.main_rotor_swept_area(sys)
    T_thrust = 0.5 * p.rho * v_hub^2 * A_sw * ct_at_tsr(λ) * cos(β)^2
    W_rotor = p.n_blades * p.m_blade * 9.81
    τ_eq = sys.k_mppt_ref[] * OMEGA_EQ^2
    bo = KiteTurbineDynamics.bridle_bearing_offset(R_hub)

    @printf("seed |r_hub|=%.4f m  R_hub=%.4f m  bearing_offset=%.4f m  n_lines=%d  n_seg=%d\n",
        norm(hub_pos), R_hub, bo, n, sys.n_ring - 1)
    @printf("ω_eq=%.4f rad/s  τ_eq=%.2f N·m  T_thrust=%.2f N  W_rotor=%.2f N  margin=%.2f\n\n",
        OMEGA_EQ, τ_eq, T_thrust, W_rotor, MARGIN)

    # ── Reproduce the 09-13 finding before trusting any of this ───────────────
    lift70 = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true,
                              elevation_deg=70.0)
    _, T_lift70, _ = lift_force_steady(lift70, p.rho, p.v_wind_ref, nothing)
    c70 = chain_taut(hub_pos, sh, perp1, perp2, p, R_hub, T_lift70, 70.0, T_thrust, W_rotor)
    s70 = chain_slack(hub_pos, sh, perp1, perp2, p, R_hub, T_lift70, 70.0, T_thrust, W_rotor)
    @printf("record check (09-13, el=70°): taut T_top=%.1f N (record 1150.0)  slack T_top=%.1f N (record 1344.7)\n",
        c70.T_top, s70.T_top)
    @assert c70.T_top < 1274.47 < s70.T_top (
        "must reproduce the 09-13 finding (taut below the floor, slack above): " *
        "taut=$(c70.T_top) slack=$(s70.T_top)"
    )
    @printf("✓ taut sits below the floor and slack above — the 09-13 finding reproduces\n")
    @printf("  (hub |r|=%.4f m vs tether_length=%.4f m -> conventions %s)\n",
        norm(hub_pos), p.tether_length,
        isapprox(norm(hub_pos), p.tether_length; rtol=1e-6) ? "coincide" : "differ")

    # ── Floor at the design geometry (independent of lift angle) ──────────────
    F_floor = floor_ftop(sys, p, wf, τ_eq)
    @printf("✓ torsional floor: F_top=%.2f N gives demand=%.6f (= 1/%.2f)\n\n",
        F_floor, demand_at(sys, p, wf, F_floor, τ_eq), MARGIN)

    # ── Sweep the lift-line elevation ─────────────────────────────────────────
    @printf("  %5s %8s %9s %9s %9s %9s %10s  %s\n",
        "el°", "T_lift", "T_back", "T_cyan", "T_bridle", "T_top", "need", "verdict")
    rows = NamedTuple[]
    for el_deg in 70.0:-1.0:30.0
        lift_a = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true,
                                  elevation_deg=el_deg)
        _, T_lift, _ = lift_force_steady(lift_a, p.rho, p.v_wind_ref, nothing)
        c = chain_taut(hub_pos, sh, perp1, perp2, p, R_hub, T_lift, el_deg, T_thrust, W_rotor)
        taut = c.T_back > 0.0
        verdict = !taut ? "back line slack" :
                  (c.T_top >= F_floor ? "CLEARS" : "short $(round(Int, F_floor - c.T_top))N")
        push!(rows, (; el_deg, T_lift, T_back=c.T_back, T_cyan=c.T_cyan,
                     T_bridle=c.T_bridle, T_top=c.T_top, taut))
        @printf("  %5.0f %8.1f %9.2f %9.2f %9.2f %9.1f %10.1f  %s\n",
            el_deg, T_lift, c.T_back, c.T_cyan, c.T_bridle, c.T_top, F_floor, verdict)
    end

    dem70 = demand_at(sys, p, wf, c70.T_top, τ_eq)
    @printf("\n  design point (el=70°, taut): T_top=%.1f N -> demand=%.4f  (cliff at 1.0; margin %.2f means %.4f max)\n",
        c70.T_top, dem70, MARGIN, 1 / MARGIN)

    # ── Assertions: the sweep must demonstrate these, not assume them ─────────
    t = [r for r in rows if r.taut]
    @assert !isempty(t) "no angle in the sweep leaves the back line taut"
    @assert t[end].T_cyan > t[1].T_cyan "T_cyan must RISE as the lift angle drops"
    @assert t[end].T_back < t[1].T_back "T_back must FALL as the lift angle drops"
    @assert t[1].T_back > 0.0 "the back line must be taut at the design 70°"
    @printf("✓ T_cyan rises and T_back falls monotonically as the lift angle drops\n")

    clears = [r for r in t if r.T_top >= F_floor]
    slackrows = [r for r in rows if !r.taut]
    if isempty(clears)
        r = t[end]
        @printf("✗ NO angle in the sweep clears the floor; best is el=%.0f° at %.1f N, %+.1f N short\n",
            r.el_deg, r.T_top, r.T_top - F_floor)
    else
        el_hi = maximum(r.el_deg for r in clears)
        r = [x for x in clears if x.el_deg == el_hi][1]
        @printf("✓ clears the floor at el ≤ %.0f°  (at %.0f°: T_top=%.1f N vs floor %.1f N, %+.1f N; T_back=%.1f N)\n",
            el_hi, el_hi, r.T_top, F_floor, r.T_top - F_floor, r.T_back)
    end
    if isempty(slackrows)
        @printf("✓ back line still taut at el=%.0f° (bottom of sweep)\n", t[end].el_deg)
    else
        @printf("✓ back line goes slack at el ≤ %.0f°  (T_back ≤ 0)\n",
            maximum(r.el_deg for r in slackrows))
    end
    if !isempty(clears) && !isempty(slackrows)
        el_hi = maximum(r.el_deg for r in clears)
        el_s = maximum(r.el_deg for r in slackrows)
        @assert el_hi > el_s (
            "no valid band — the back line slacks before the cyan line clears the floor"
        )
        @printf("✓ VALID BAND: taut AND clearing for el %.0f°–%.0f° (%.0f° wide)\n",
            t[end].el_deg, el_hi, el_hi - t[end].el_deg)
    end

    # ── Off-design: the bungee's 80 cm of soft travel ─────────────────────────
    el_design = 70.0
    lift_d = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true,
                              elevation_deg=el_design)
    _, T_lift_d, _ = lift_force_steady(lift_d, p.rho, p.v_wind_ref, nothing)
    cd = chain_taut(hub_pos, sh, perp1, perp2, p, R_hub, T_lift_d, el_design, T_thrust, W_rotor)
    k_soft = cd.T_back / BUNGEE_TRAVEL_M
    @printf("\n── off-design (bungee): T_back_design=%.1f N -> k_soft=%.1f N/m over %.2f m ──\n",
        cd.T_back, k_soft, BUNGEE_TRAVEL_M)
    @printf("  %6s %10s %10s %10s %10s\n", "lift%", "T_lift", "T_back_taut", "extension", "state")
    for f in (1.0, 0.9, 0.8, 0.7, 0.6, 0.4, 0.2, 0.0)
        c = chain_taut(hub_pos, sh, perp1, perp2, p, R_hub, f * T_lift_d, el_design,
                       T_thrust, W_rotor)
        if c.T_back > 0.0
            ext = min(c.T_back / k_soft, BUNGEE_TRAVEL_M)
            @printf("  %5.0f%% %10.1f %10.1f %9.3f m  %s\n", 100f, f * T_lift_d,
                c.T_back, ext,
                c.T_back >= cd.T_back ? "at hard stop" : "soft")
        else
            cs = chain_slack(hub_pos, sh, perp1, perp2, p, R_hub, f * T_lift_d, el_design,
                             T_thrust, W_rotor)
            @printf("  %5.0f%% %10.1f %10.1f %9.3f m  SLACK -> cyan alone (T_cyan=%.1f N)\n",
                100f, f * T_lift_d, 0.0, 0.0, cs.T_cyan)
        end
    end
    @printf("✓ 80 cm of soft travel is the sky anchor's altitude give before the line rides the hard stop\n")
    return nothing
end

main()
