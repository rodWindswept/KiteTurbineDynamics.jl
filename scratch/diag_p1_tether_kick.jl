# scratch/diag_p1_tether_kick.jl
#
# 2026-09-16.  P1 (`test_physics_path_ode.jl`) reads status=reject with the
# config's tether aligned to the rung-scaled params.  Two candidate causes are
# confounded in that file and this separates them:
#
#   (1) tether_diameter: cfg default 0.003 vs the scaled 0.003651 m.  The
#       mechanism is real (cfg.tether_diameter drives BOTH the design
#       MaterialSpec and the ODE build), so this changes the machine.
#   (2) kickstart_s: the test's CFG omits it, so it takes the ObjectiveConfig
#       DEFAULT of 2.0 s — the legacy PTO motor kick.  test_settle_lowk_honest
#       explicitly sets 0.0, and the config's own comment records that
#       "v13 uses 0.0" because the kick injects ~115x MPPT torque and can wind a
#       healthy chain past its collapse limit.
#
# Prints status / P_mean / FoS_min for the 2x2 grid, so the effect of each knob
# is read off the record instead of assumed.  The (0.003, 2.0) cell should
# reproduce the recorded P1 baseline FoS_min 2.054 if this harness is faithful.

using KiteTurbineDynamics, Printf
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
    scaled = mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, KW)
    return override_params(scaled; tether_length=L)
end

lift_for(sys, p) = sized_lifter_for(sys, p; margin=1.5, v_ref=11.0, const_tension=true)

const P = params_at_length(L18)
const X = seed_genome(KW)

function run_one(tether::Float64, kick::Float64, tag::String)
    cfg = ObjectiveConfig(;
        power_W=KW * 1000.0, p_floor_kw=KW, p_ceiling_kw=KW,
        fos_target=2.5, fos_hard=2.5, power_stat=:tail5,
        k_mppt=K_MPPT_5KW_HONEST, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8,
        blocking_factor=BLOCKING_WIND_FACTOR_5KW,
        tether_diameter=tether, kickstart_s=kick,
        relax_s=5.0, window_s=5.0)
    r = KiteTurbineDynamics.evaluate_windowed(X, PROFILE_ELLIPTICAL, P, cfg;
        start_mode=:cold, lift_device=lift_for,
        fitness_fn=KiteTurbineDynamics.appropriate_mass_fitness)
    @printf("  %-28s tether=%.6f kick=%.1f  status=%-7s P_mean=%.3f kW  FoS_min=%.4f\n",
        tag, tether, kick, r.status, r.P_mean, r.FoS_min)
    return r
end

println("=== P1 knob grid: tether_diameter x kickstart_s (5 s window, 5 s relax) ===")
println("  (scaled tether = ", P.tether_diameter, " m)")
run_one(0.003, 2.0, "recorded baseline")
run_one(0.003, 0.0, "v13 kick off, thin line")
run_one(P.tether_diameter, 2.0, "aligned tether, legacy kick")
run_one(P.tether_diameter, 0.0, "aligned tether, v13 kick off")
println("=== done ===")
