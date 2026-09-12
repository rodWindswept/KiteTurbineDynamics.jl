# scratch/diag_reds_p1_raw.jl — test_physics_path_ode P1 (RAW seed_genome, CFG
# default tether_diameter = 0.003 m).  Prints the settled twist ratios and the
# evaluator's own result fields.
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const L18 = 18.8

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = KiteTurbineDynamics.GeometrySpec(
        p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius, L,
        p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = KiteTurbineDynamics.MaterialSpec(
        p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = KiteTurbineDynamics.AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = KiteTurbineDynamics.ControlSpec(
        p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = KiteTurbineDynamics.BackLineSpec(
        p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(KiteTurbineDynamics.SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const CFG = ObjectiveConfig(;
    power_W=KW * 1000.0, p_floor_kw=KW, p_ceiling_kw=KW,
    fos_target=2.5, fos_hard=2.5, power_stat=:tail5,
    k_mppt=K_MPPT_5KW_HONEST, rotor_count_mode=true, power_split=0.6,
    cone_slope_deg=22.0, rotor_spacing_frac=0.8,
    blocking_factor=BLOCKING_WIND_FACTOR_5KW, relax_s=5.0, window_s=5.0,
)
const X = seed_genome(KW)
const P = params_at_length(L18)

lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)

@printf("P1 CFG.tether_diameter = %.6f m  (P.tether_diameter = %.6f m, params_daisy 0.002 scaled)\n",
    CFG.tether_diameter, P.tether_diameter)
@printf("X (raw seed_genome) = %s\n", join(round.(X, digits=4), ", "))

function fields(tag, r)
    @printf("  %-6s status=%-7s fitness=%s  P_mean=%.4f  P_end=%.4f  FoS_min=%s\n",
        tag, string(r.status), string(r.fitness), r.P_mean, r.P_end, string(r.FoS_min))
    @printf("         T_lift=%.1f  w_eq=%.4f  P_range=%.4f  drifted=%s stationary=%s twist_crossed=%s util_a=%.3f util_b=%.3f\n",
        r.T_lift, r.ω_eq, r.P_range, r.drifted, r.stationary, r.twist_crossed, r.util_a, r.util_b)
    flush(stdout)
    return r
end

function run_eval(cfg)
    return evaluate_windowed(X, PROFILE_ELLIPTICAL, P, cfg;
        start_mode=:cold, lift_device=lift_for,
        fitness_fn=appropriate_mass_fitness)
end

# ── settled-state probe with the P1 config's tether diameter ──────────────────
println("\n=== settle probe (P1 tether_diameter) ===")
begin
    dec = KiteTurbineDynamics.design_from_vector_v10(
        X, PROFILE_ELLIPTICAL, P;
        power_W=KW * 1000.0, v_rated=11.0, cylinder_cone=true,
        rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        beam_t_over_D=CFG.t_over_D)
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, P, CFG)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=CFG.tether_diameter, base_params=P,
        min_wall_m=CFG.min_wall_m, beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift_dev = lift_for(sys, pc)
    wf(pos, t) = [KiteTurbineDynamics.WIND_MS * (max(pos[3], 1.0) / P.h_ref)^(1 / 7), 0.0, 0.0]
    N = sys.n_total
    Nr = sys.n_ring
    dt = KiteTurbineDynamics.stable_dt_for_system(sys, pc)
    @printf("  N=%d Nr=%d n_lines=%d tether_d=%.6f EA_single=%.1f dt=%.3e\n",
        N, Nr, pc.n_lines, pc.tether_diameter,
        pc.e_modulus * π * (pc.tether_diameter / 2)^2, dt)
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0; wind_fn=wf, lift_device=lift_dev)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift_dev)
    α = u[(6 * N + 1):(6 * N + Nr)]
    tr = KiteTurbineDynamics.twist_collapse_check(u, sys)
    @printf("  w_eq(settle)=%.4f rad/s  k*w^3=%.3f kW   collapse: crossed=%s max_ratio=%.3f worst=%d\n",
        u[6 * N + Nr + 1], 1e-3 * K_MPPT_5KW_HONEST * u[6 * N + Nr + 1]^3,
        tr.crossed, tr.max_ratio, tr.worst_seg)
    println("  seg  Δα(deg)  δα*_maxR(deg)  ratio   T_line(N)  strain")
    for s in 1:(Nr - 1)
        r_i = (sys.nodes[sys.ring_ids[s]]::RingNode).radius
        r_ip1 = (sys.nodes[sys.ring_ids[s + 1]]::RingNode).radius
        L_seg = norm(u[(3 * (sys.ring_ids[s + 1] - 1) + 1):(3 * sys.ring_ids[s + 1])] .-
                     u[(3 * (sys.ring_ids[s] - 1) + 1):(3 * sys.ring_ids[s])])
        dastar = rad2deg(2 * asin(min(L_seg / sqrt(2 * (L_seg^2 + 2 * max(r_i, r_ip1)^2)), 1.0)))
        da = abs(rad2deg(α[s + 1] - α[s]))
        EA1 = pc.e_modulus * π * (pc.tether_diameter / 2)^2
        @printf("  %3d  %8.3f  %12.3f  %6.3f  %9.2f  %.3e\n",
            s, da, dastar, da / dastar, ef.segment_tension[s], ef.segment_tension[s] / EA1)
    end
    flush(stdout)

    println("\n  window (P1 cold path, 10 s):")
    for c in 1:10
        run_canonical_sim!(u, sys, pc, wf, round(Int, 1.0 / dt), dt;
            lift_device=lift_dev, lin_damp=0.05)
        tr = KiteTurbineDynamics.twist_collapse_check(u, sys)
        ef = KiteTurbineDynamics.capture_extended(u, sys, pc, float(c), wf, lift_dev)
        fos_min, _ = KiteTurbineDynamics.min_airborne_fos(ef.ring_fos)
        @printf("    t=%2ds P=%7.3f kW FoS=%7.3f max_ratio=%6.3f worst=%d crossed=%s w_gnd=%.3f\n",
            c, ef.base.P_kw, fos_min, tr.max_ratio, tr.worst_seg, tr.crossed, u[6 * N + Nr + 1])
        flush(stdout)
    end
end

println("\n=== P1 exact evaluate_windowed (raw seed, CFG default tether 0.003) ===")
fields("P1", run_eval(CFG))
println("\n=== same seed, campaign tether 0.003651, window 5 ===")
fields("camp5", run_eval(ObjectiveConfig(CFG; tether_diameter=P.tether_diameter)))
println("\n=== raw seed, campaign tether, window 20 ===")
fields("camp20", run_eval(ObjectiveConfig(CFG; tether_diameter=P.tether_diameter, window_s=20.0)))
println("\nDONE")
