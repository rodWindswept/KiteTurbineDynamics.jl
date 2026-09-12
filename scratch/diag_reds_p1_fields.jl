# scratch/diag_reds_p1_fields.jl — exact ObjectiveResult fields for
# test_physics_path_ode P1 (raw seed_genome, CFG) and for the same genome with
# the campaign tether and a 20 s window (the A3 config with a corrected genome).
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

function fields(tag, r)
    @printf("  %-9s status=%-7s fitness=%s  P_mean=%.4f kW  P_end=%.4f kW  FoS_min=%s\n",
        tag, string(r.status), string(r.fitness), r.P_mean, r.P_end, string(r.FoS_min))
    @printf("            T_lift=%.1f N  w_eq=%.4f  P_range=%.4f  drifted=%s stationary=%s  twist_crossed=%s  util_a=%.3f util_b=%.3f\n",
        r.T_lift, r.ω_eq, r.P_range, r.drifted, r.stationary, r.twist_crossed, r.util_a, r.util_b)
    flush(stdout)
    return r
end

function run_eval(cfg)
    return evaluate_windowed(X, PROFILE_ELLIPTICAL, P, cfg;
        start_mode=:cold, lift_device=lift_for,
        fitness_fn=KiteTurbineDynamics.appropriate_mass_fitness)
end

println("=== P1 exact: raw seed, CFG (tether default 0.003), relax 5, window 5 ===")
fields("P1 exact", run_eval(CFG))

println("\n=== A3 config with corrected genome: raw seed, campaign tether, relax 5, window 20 ===")
fields("A3-fixed", run_eval(ObjectiveConfig(CFG; tether_diameter=P.tether_diameter, window_s=20.0)))

println("\n=== same, window 5 (should match P1 up to tether) ===")
fields("w5-camp", run_eval(ObjectiveConfig(CFG; tether_diameter=P.tether_diameter)))
println("\nDONE")
