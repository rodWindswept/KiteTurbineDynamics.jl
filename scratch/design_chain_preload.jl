# scratch/design_chain_preload.jl
#
# Design-chain preload, closed form, from the SECTION balances (Rod 2026-09-13):
#
#   Section A — lift bearing alone:
#       6·T_b·cosθ = T_cyan_ax − W_bearing·sinβ
#   Section B — cut the TRPT below the main rotor:
#       T_top = T_thrust + 6·T_b·cosθ − W_rotor·sinβ
#
# Orientation (verified, not assumed):
#   ŝ = ground→hub = [cosβ,0,sinβ];  thrust is +ŝ (up-shaft, downwind);
#   bridles pull the rotor UP-shaft and the bearing DOWN-shaft;
#   gravity axial component = −W·sinβ.
#
# Compares the design point bearing_offset = 3.99 m (the measured equilibrium,
# Rod's choice (a)) with the current placeholder 6.0 m, and reports the bridle
# rest length the preload implies.
#
#   scripts/ktd-julia scratch/design_chain_preload.jl

using KiteTurbineDynamics, LinearAlgebra, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const BRIDLE_EA = 500_000.0     # initialization.jl:163
const BEARING_MASS = 0.3        # initialization.jl:162
const CYAN_L0 = 5.0

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
    hub = sys.rotor.node_id
    β = p.elevation_angle
    sh = [cos(β), 0.0, sin(β)]
    perp1, perp2 = shaft_perp_basis(sh)
    R_hub = (sys.nodes[hub]::RingNode).radius
    hub_pos = pos(u0, hub)                      # design hub position
    n = p.n_lines

    # ODE-consistent axial thrust (ring_forces.jl:202-215) at the operating speed
    v_hub = p.v_wind_ref * sys.rotor.wind_factor
    λ = 12.983466 * sys.rotor.radius / v_hub
    CT = ct_at_tsr(λ)
    A_sw = KiteTurbineDynamics.main_rotor_swept_area(sys)
    T_thrust = 0.5 * p.rho * v_hub^2 * A_sw * CT * cos(β)^2

    W_rotor = p.n_blades * p.m_blade * 9.81
    W_bearing = BEARING_MASS * 9.81
    m_sky = 0.3

    @printf("design hub |r|=%.4f m  R_hub=%.4f  n_lines=%d  β=%.1f deg\n",
        norm(hub_pos), R_hub, n, rad2deg(β))
    @printf("ODE thrust: v_hub=%.3f  λ=%.3f  CT=%.4f  A_swept=%.3f m2  T_thrust=%.2f N\n",
        v_hub, λ, CT, A_sw, T_thrust)
    @printf("W_rotor=%.2f N  W_bearing=%.2f N  W_sky=%.2f N   axial grav factor sinβ=%.3f\n\n",
        W_rotor, W_bearing, m_sky * 9.81, sin(β))

    @printf("  %-6s %10s %10s %10s %10s %10s %12s %10s\n",
        "offset", "T_cyan", "θ_axis", "T_bridle", "6Tbcosθ", "T_top", "bridleL0", "strain%")
    for bo in (6.0, 3.99)
        T_cyan = design_preload_from_sky_anchor(p, lift; bearing_offset=bo, cyan_L0=CYAN_L0)
        bearing_pos = hub_pos .+ bo .* sh
        sky_pos = bearing_pos .+ CYAN_L0 .* sh
        cyan_dir = normalize(bearing_pos .- sky_pos)          # sky -> bearing (down-shaft)
        T_cyan_ax = -T_cyan * dot(cyan_dir, sh)               # force on bearing, up-shaft
        # bridle angle from the axis, and the design 3D gap
        pa = attachment_point(hub_pos, R_hub, 0.0, 1, n, perp1, perp2)
        gap = norm(bearing_pos .- pa)
        cosθ = bo / gap
        # Section A: bearing
        T_bridle = (T_cyan_ax - W_bearing * sin(β)) / (n * cosθ)
        # Section B: rotor
        T_top = T_thrust + n * T_bridle * cosθ - W_rotor * sin(β)
        L0 = gap / (1 + T_bridle / BRIDLE_EA)
        @printf("  %-6.2f %10.3f %10.4f %10.4f %10.4f %10.3f %12.6f %10.5f\n",
            bo, T_cyan, rad2deg(acos(cosθ)), T_bridle, n * T_bridle * cosθ, T_top, L0,
            100 * T_bridle / BRIDLE_EA)
    end

    # ── The backline's DESIGN ROLE: slack/light at the operating point ────────
    # Rod 2026-09-12: the backline is an ALTITUDE LIMITER, not a load path —
    # dyneema with sewn-in elastic, light tension over ~2 m, hard only at the
    # dyneema stop.  So at the design point T_back = 0 and the lift goes down the
    # cyan line.  design_preload_from_sky_anchor instead solves as if the
    # backline were taut at design, which starves the cyan/bridle chain.
    bo = 3.99
    _, T_lift, el_deg = lift_force_steady(lift, p.rho, p.v_wind_ref, p)
    el = deg2rad(el_deg)
    lift_dir = [cos(el), 0.0, sin(el)]
    bearing_pos = hub_pos .+ bo .* sh
    sky_pos = bearing_pos .+ CYAN_L0 .* sh
    cyan_dir = normalize(bearing_pos .- sky_pos)
    T_cyan_slack = -dot(T_lift .* lift_dir .+ [0.0, 0.0, -m_sky * 9.81], cyan_dir)
    pa = attachment_point(hub_pos, R_hub, 0.0, 1, n, perp1, perp2)
    gap = norm(bearing_pos .- pa)
    cosθ = bo / gap
    T_b_slack = (T_cyan_slack - W_bearing * sin(β)) / (n * cosθ)
    T_top_slack = T_thrust + n * T_b_slack * cosθ - W_rotor * sin(β)
    L0_slack = gap / (1 + T_b_slack / BRIDLE_EA)
    @printf("  %-6.2f %10.3f %10.4f %10.4f %10.4f %10.3f %12.6f %10.5f   <- backline SLACK\n",
        bo, T_cyan_slack, rad2deg(acos(cosθ)), T_b_slack, n * T_b_slack * cosθ, T_top_slack,
        L0_slack, 100 * T_b_slack / BRIDLE_EA)
    @printf("  lift T=%.1f N at %.0f deg -> axial projection onto ŝ = %.2f N\n",
        T_lift, el_deg, T_lift * dot(lift_dir, sh))
    @printf("  realisability floor (plan §2.4.1) = 1274.47 N  -> slack-backline T_top margin = %+.1f N\n",
        T_top_slack - 1274.47)

    # what the current code builds, and what the current formula prescribes
    F_ax_now = KiteTurbineDynamics.design_axial_preload(sys, p, lift)
    @printf("\ncurrent design_axial_preload: T_top=%9.3f N  per-line=%8.3f N  (n_seg=%d)\n",
        F_ax_now[end], F_ax_now[end] / n, length(F_ax_now))
    thr_design = 0.5 * p.rho * p.v_wind_ref^2 * π * p.rotor_radius^2 * 0.8 * cos(β)^2
    @printf("current formula internals: thrust(0.8)=%.2f N  m_rotor+m_kite=%.3f kg  W/sinβ=%.2f N  W·sinβ=%.2f N\n",
        thr_design, p.n_blades * p.m_blade + sys.kite.mass,
        (p.n_blades * p.m_blade + sys.kite.mass) * 9.81 / sin(β),
        (p.n_blades * p.m_blade + sys.kite.mass) * 9.81 * sin(β))
    return nothing
end

main()
