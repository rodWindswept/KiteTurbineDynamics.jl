# scratch/diag_reds_a3_p1.jl — diagnosis for test_settle_lowk_honest A3 and
# test_physics_path_ode P1 after the 2026-09-11 settle fix.
#
# Prints (1) the settled start state of the campaign seed and (2) the full
# ObjectiveResult fields for the exact A3 / P1 configs.
using KiteTurbineDynamics, Printf, LinearAlgebra
include(joinpath(@__DIR__, "..", "scripts", "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const LENGTH = 18.8

lift_for(sys, p) = KiteTurbineDynamics.sized_lifter_for(
    sys, p; margin=1.5, v_ref=V_RATED, const_tension=true)

function params_at_length(L::Float64)
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

const P_BASE = params_at_length(LENGTH)

function seed_genome_x()
    seed_v = seed_genome(KW)
    lo, hi = tight_bounds(seed_v, KW)
    xr = clamp.(copy(seed_v), lo, hi)
    xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
    xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))
    return xr
end

const X_SEED = seed_genome_x()

function base_cfg(; relax_s, window_s)
    return ObjectiveConfig(;
        power_W=PW, v_rated=V_RATED, p_floor_kw=5.0, p_ceiling_kw=5.0,
        relax_s=relax_s, window_s=window_s, fos_target=2.5, fos_hard=2.5,
        power_stat=:tail5, penalize_ceiling=false, kickstart_s=0.0,
        k_mppt=K_MPPT_5KW_HONEST, tether_diameter=P_BASE.tether_diameter,
        rotor_count_mode=true, power_split=0.6,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
    )
end

function run_at(k; relax_s=5.0, window_s=20.0, p=P_BASE, x=X_SEED)
    cfg = base_cfg(; relax_s=relax_s, window_s=window_s)
    cfg = ObjectiveConfig(cfg; k_mppt=k)
    return KiteTurbineDynamics.evaluate_windowed(
        x, PROFILE_ELLIPTICAL, p, cfg;
        start_mode=:cold,
        lift_device=lift_for,
        fitness_fn=(P, F, c, m) -> KiteTurbineDynamics.appropriate_mass_fitness(P, F, c, m),
    )
end

function fields(tag, r)
    @printf("  %-6s status=%-7s fitness=%s  P_mean=%.4f kW  P_end=%.4f kW  FoS_min=%s\n",
        tag, string(r.status), string(r.fitness), r.P_mean, r.P_end, string(r.FoS_min))
    @printf("         T_lift=%.1f N  w_eq=%.4f  P_range=%.4f  drifted=%s stationary=%s  twist_crossed=%s\n",
        r.T_lift, r.ω_eq, r.P_range, r.drifted, r.stationary, r.twist_crossed)
    @printf("         util_a=%.3f util_b=%.3f\n", r.util_a, r.util_b)
    flush(stdout)
    return r
end

# ── 1. Settled start state of the seed (evaluator's own build recipe) ──────────
println("=== Settled start state (evaluator build recipe, k=$(K_MPPT_5KW_HONEST)) ===")
begin
    cfg0 = base_cfg(; relax_s=5.0, window_s=5.0)
    dec = KiteTurbineDynamics.design_from_vector_v10(
        X_SEED, PROFILE_ELLIPTICAL, P_BASE;
        power_W=PW, v_rated=V_RATED, cylinder_cone=true,
        rotor_count_mode=true, power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        beam_t_over_D=cfg0.t_over_D,
    )
    sizing = KiteTurbineDynamics.size_beams_closed_form(dec, P_BASE, cfg0)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec, 1.0, K_MPPT_5KW_HONEST;
        tether_diameter=cfg0.tether_diameter, base_params=P_BASE,
        min_wall_m=cfg0.min_wall_m, beam_sizing=sizing)
    sys.k_mppt_ref[] = K_MPPT_5KW_HONEST
    lift_dev = lift_for(sys, pc)
    wf(pos, t) = [KiteTurbineDynamics.WIND_MS * (max(pos[3], 1.0) / P_BASE.h_ref)^(1 / 7), 0.0, 0.0]
    N = sys.n_total
    Nr = sys.n_ring
    @printf("  N=%d Nr=%d n_lines=%d dt=%.3e tether_d=%.6f EA_single=%.1f N\n",
        N, Nr, pc.n_lines, KiteTurbineDynamics.stable_dt_for_system(sys, pc),
        pc.tether_diameter,
        pc.e_modulus * π * (pc.tether_diameter / 2)^2)
    u = settle_to_operational_state(sys, copy(u0), pc, 60.0;
        wind_fn=wf, lift_device=lift_dev)
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift_dev)
    α = u[(6 * N + 1):(6 * N + Nr)]
    @printf("  w_eq(settle)=%.4f rad/s   k*w^3=%.3f kW\n", u[6 * N + Nr + 1],
        1e-3 * K_MPPT_5KW_HONEST * u[6 * N + Nr + 1]^3)
    tr = KiteTurbineDynamics.twist_collapse_check(u, sys)
    @printf("  twist_collapse_check(settle): crossed=%s max_ratio=%.4f worst_seg=%d\n",
        tr.crossed, tr.max_ratio, tr.worst_seg)
    println("  seg  Δα(deg)  δα*_maxR(deg)  ratio   T_line(N)  strain")
    for s in 1:(Nr - 1)
        r_i = (sys.nodes[sys.ring_ids[s]]::RingNode).radius
        r_ip1 = (sys.nodes[sys.ring_ids[s + 1]]::RingNode).radius
        r_seg = max(r_i, r_ip1)
        p_i = u[(3 * (sys.ring_ids[s] - 1) + 1):(3 * sys.ring_ids[s])]
        p_ip1 = u[(3 * (sys.ring_ids[s + 1] - 1) + 1):(3 * sys.ring_ids[s + 1])]
        L_seg = norm(p_ip1 - p_i)
        dastar = rad2deg(2 * asin(min(L_seg / sqrt(2 * (L_seg^2 + 2 * r_seg^2)), 1.0)))
        da = abs(rad2deg(α[s + 1] - α[s]))
        Ts = ef.segment_tension[s]
        EA1 = pc.e_modulus * π * (pc.tether_diameter / 2)^2
        @printf("  %3d  %8.3f  %12.3f  %6.3f  %9.2f  %.3e\n",
            s, da, dastar, da / dastar, Ts, Ts / EA1)
    end
    flush(stdout)
end

# ── 2. Exact A3 and P1 configs ────────────────────────────────────────────────
println("\n=== A3 exact: relax_s=5, window_s=20, k=$(K_MPPT_5KW_HONEST) ===")
fields("A3", run_at(K_MPPT_5KW_HONEST; relax_s=5.0, window_s=20.0))

println("\n=== P1 exact: relax_s=5, window_s=5, k=$(K_MPPT_5KW_HONEST) ===")
fields("P1", run_at(K_MPPT_5KW_HONEST; relax_s=5.0, window_s=5.0))

println("\n=== gate-like: relax_s=10, window_s=30, k=$(K_MPPT_5KW_HONEST) ===")
fields("GATE", run_at(K_MPPT_5KW_HONEST; relax_s=10.0, window_s=30.0))

println("\nDONE")
