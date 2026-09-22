# scratch/probe_backline_regime.jl
#
# Item 4 multi-rotor remediation, back-line work item (2026-09-22).
#
# Rod's field guidance: the back line is an ALTITUDE LIMITER that runs on its
# elastic travel during normal operation, not a rigid tension sink.  In the model
# the design point is placed where the line is already fully extended (the hard
# stop), so the sky anchor cannot float.
#
# This probe measures, for a candidate at the settled operating point:
#   - the lift / back / cyan line ELEVATIONS and the angles between them
#   - T_lift, T_back, T_cyan (design 2x2 split and ODE settled)
#   - b_dist vs the cut length, the 0.8 m bungee travel, and the hard stop
#   - which regime the line sits in, and the margin either way
#   - the ground anchor's downwind offset from the sky anchor's axial projection
#   - the `backline_payout` that would sit the design point mid-travel
#
# Usage: julia --project=. scratch/probe_backline_regime.jl [island_dir ...]

using KiteTurbineDynamics, LinearAlgebra, Statistics, Printf
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "..", "test", "settle_case_builders.jl"))
include(joinpath(@__DIR__, "..", "scripts", "ode_gate_v13.jl"))

const RESDIR = joinpath(
    @__DIR__, "..", "scripts", "results", "v13_5kw_masslift_len18.8_rotorcount_physlift"
)

pos(u, g) = u[(3 * (g - 1) + 1):(3 * g)]
elev(v) = rad2deg(atan(v[3], hypot(v[1], v[2])))

function run_island(ISLAND)
    CSV = joinpath(RESDIR, ISLAND, "best_vector.csv")
    p0 = params_at_length(params_daisy(), 18.8, 5.0)
    bf = BLOCKING_WIND_FACTOR_5KW
    xv = [parse(Float64, s) for s in split(strip(read(CSV, String)), ",")]
    xv[8] = Float64(round(Int, clamp(xv[8], 3, 16)))
    xv[10] = Float64(round(Int, clamp(xv[10], 1, 3)))
    dec = design_from_vector_v10(xv, PROFILE_ELLIPTICAL, p0; power_W=5000.0,
        cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=bf)
    cfg = KiteTurbineDynamics.ObjectiveConfig(;
        power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
        fos_target=2.5, fos_hard=2.5, min_wall_m=2e-3, t_over_D=0.055,
        rotor_count_mode=true, power_split=0.6, blocking_factor=bf)
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, p0, cfg)
    sys, u0, p = KiteTurbineDynamics.build_system_from_v10(dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=p0.tether_diameter, base_params=p0, min_wall_m=2e-3,
        beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift = lift_for(sys, p)
    wf = (r, t) -> [p.v_wind_ref, 0.0, 0.0]
    u = settle_to_operational_state(sys, copy(u0), p, 60.0;
        lift_device=lift, wind_fn=wf, n_op=300_000)

    β = p.elevation_angle
    sh = [cos(β), 0.0, sin(β)]
    back_ax = p.tether_length * cos(β) + p.back_anchor_fwd_x
    hub_gid = sys.rotor.node_id
    hub_ri = (sys.nodes[hub_gid]::RingNode).ring_idx
    r_top = isempty(sys.expansion_rotors) ? (sys.nodes[hub_gid]::RingNode).radius :
            sys.effective_radii[hub_ri]
    bearing_offset = KiteTurbineDynamics.bridle_bearing_offset(r_top)
    cyan_L0 = KiteTurbineDynamics.CYAN_L0_DESIGN
    L_axis_design = p.tether_length + bearing_offset + cyan_L0

    d = KiteTurbineDynamics.lift_chain_design(sys, p, lift, pos(u, hub_gid);
        omega_eq=u[6 * sys.n_total + sys.n_ring + 1])

    sa = pos(u, sys.sky_anchor_id)
    bear = pos(u, sys.bearing_id)
    hub = pos(u, hub_gid)

    # Settled geometry
    b_dist = norm([sa[1] - back_ax, sa[2], sa[3]])
    # Design cut length (the placement geometry)
    design_sky = [L_axis_design * cos(β), 0.0, L_axis_design * sin(β)]
    back_L0 = hypot(design_sky[1] - back_ax, design_sky[3])
    travel = KiteTurbineDynamics.BACK_LINE_SOFT_TRAVEL_M
    T_hard = KiteTurbineDynamics.BACK_LINE_T_DESIGN_N
    k_soft = T_hard / travel

    # Settled line directions, for the angle audit
    cyan_dir = normalize(bear .- sa)
    back_dir = normalize([back_ax, 0.0, 0.0] .- sa)
    T_back_ode = KiteTurbineDynamics.back_line_tension(b_dist, back_L0,
        p.backline_payout, p.EA_back_line)

    @printf("\n═══════════ %s ═══════════\n", ISLAND)
    @printf("EA_back_line=%.0f N   travel=%.3f m   T_hard_stop=%.1f N   k_soft=%.1f N/m\n",
        p.EA_back_line, travel, T_hard, k_soft)
    @printf("back_anchor_fwd_x=%.3f m   back_ax=%.3f m   L_axis_design=%.3f m\n",
        p.back_anchor_fwd_x, back_ax, L_axis_design)
    @printf("bearing_offset=%.3f  cyan_L0=%.3f  tether_length=%.3f\n",
        bearing_offset, cyan_L0, p.tether_length)
    @printf("sky anchor axial-projection x = %.3f m; ground anchor is %.3f m downwind of it\n",
        design_sky[1], back_ax - design_sky[1])

    @printf("\n── settled geometry ──\n")
    @printf("hub   = (%.3f, %.3f, %.3f)  |hub|=%.3f\n", hub..., norm(hub))
    @printf("bear  = (%.3f, %.3f, %.3f)  |bear|=%.3f\n", bear..., norm(bear))
    @printf("sky   = (%.3f, %.3f, %.3f)  |sky|=%.3f\n", sa..., norm(sa))
    @printf("b_dist=%.4f  back_L0(cut)=%.4f  b_dist-back_L0=%+.4f m\n",
        b_dist, back_L0, b_dist - back_L0)
    @printf("hard-stop span: b_dist - (back_L0 - travel) = %+.4f m over the %.3f m travel\n",
        b_dist - (back_L0 - travel), travel)
    regime = b_dist > back_L0 ? "HARD (Dyneema, EA=700 kN)" :
             b_dist > back_L0 - travel ? "SOFT (bungee)" : "SLACK (0 N)"
    @printf("REGIME: %s\n", regime)
    @printf("T_back: ODE-law=%.3f N   design 2x2 split=%.3f N   T_cyan(design)=%.3f N\n",
        T_back_ode, d.T_back, d.T_cyan)

    @printf("\n── line elevations (deg from horizontal) ──\n")
    @printf("back  = %.2f   cyan = %.2f   shaft = %.2f\n",
        elev(back_dir), elev(cyan_dir), elev(sh))
    if lift !== nothing
        _, T_lift, el_deg = KiteTurbineDynamics.lift_force_steady(lift, p.rho, p.v_wind_ref, p)
        @printf("lift  = %.2f   T_lift = %.3f N\n", el_deg, T_lift)
        lift_dir = [cos(deg2rad(el_deg)), 0.0, sin(deg2rad(el_deg))]
        @printf("angle(lift,back) = %.2f deg   angle(lift,cyan) = %.2f deg\n",
            rad2deg(acos(clamp(dot(lift_dir, back_dir), -1.0, 1.0))),
            rad2deg(acos(clamp(dot(lift_dir, cyan_dir), -1.0, 1.0))))
        @printf("back share of lift = %.1f %%   cyan share = %.1f %%\n",
            100 * d.T_back / T_lift, 100 * d.T_cyan / T_lift)
    end

    @printf("\n── what payout would sit the design point where? ──\n")
    for frac in (0.0, 0.25, 0.5, 0.75)
        # payout moves the hard stop outward: effective stop = back_L0 + payout.
        # At b_dist = back_L0 (design), T = k_soft*(travel - payout).
        payout = frac * travel
        T_at_design = k_soft * (travel - payout)
        @printf("  payout=%.2f m (%3.0f%% of travel) -> T_back at design = %.1f N\n",
            payout, 100 * frac, T_at_design)
    end
    p50 = 0.50 * travel
    println("  NOTE: `backline_payout` is currently IGNORED by back_line_tension (dead knob).")
    @printf("  With payout live, %.2f m (mid-travel) gives ~%.0f N at the design point and\n",
        p50, k_soft * (travel - p50))
    @printf("  leaves %.2f m of soft travel before the Dyneema hard stop.\n", travel - p50)
    return nothing
end

islands = isempty(ARGS) ? ["island_1", "island_3"] : ARGS
for isl in islands
    run_island(isl)
end
println("\n=== done ===")
