#!/usr/bin/env julia --project=.
# smoke_masslift_v13.jl — pre-launch acceptance for the 5kW Daisy-anchored
# mass-min redo (2026-08-21: params_daisy base, r_bottom clamp fix, lifter
# mass excluded from tension, annulus-aligned Betz gates).
#
# For the campaign length (18.8 m), run the campaign seed genome through
# evaluate_windowed with lift_for (the exact runner path) and verify:
#   1. status == :ok (window completes, no twist/collapse/clearance reject)
#   2. in-run T_lift ≈ T_ref = 1.5 · m_airborne · g / sin(70°)  (≤5% rel)
#      where m_airborne = expansion_airborne_mass(sys, pc; include_lifter=false)
#      — the evaluator's own build chain (base_params=p_base, NOT the 50 kW
#      default; was the phantom-81-kg reference path, fixed 2026-08-21).
#
# Usage: julia --project=. scripts/smoke_masslift_v13.jl
using KiteTurbineDynamics, Printf
include(joinpath(@__DIR__, "compute_seeds.jl"))

const KW = 5.0
const PW = KW * 1000.0
const V_RATED = 11.0
const WINDOW_S = 40.0   # HONEST window (2026-08-22), matches the runner

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
    # LENGTH FIX (2026-08-22): mass_scale also scales the tether length by the
    # rung geom_scale (sqrt(5/1.5) ~ 1.826), so params_at_length(18.8) silently
    # built a 34.3 m machine while h_ref/masses described an 18.8 m machine.
    # L is the FINAL machine length — restore it after rung scaling.
    return override_params(scaled; tether_length=L)
end

function main()
    all_ok = true
    for L in (18.8,)
        p_base = params_at_length(L)
        cfg = ObjectiveConfig(;
            power_W = PW, v_rated = V_RATED,
            p_floor_kw = 5.0, p_ceiling_kw = 5.0,
            relax_s = 10.0, window_s = WINDOW_S,
            fos_target = 2.5, fos_hard = 2.5,
            power_stat = :tail5, penalize_ceiling = false,
            kickstart_s = 0.0,
            k_mppt = K_MPPT_5KW_HONEST,   # single source (compute_seeds.jl)
            tether_diameter = p_base.tether_diameter,
            rotor_count_mode = true,   # match the runner (x10 = count {1,2,3})
            blocking_factor = BLOCKING_WIND_FACTOR_5KW,   # downstream (upper) rotors
        )

        seed_v = seed_genome(KW)
        lo, hi = tight_bounds(seed_v, KW)
        xr = clamp.(copy(seed_v), lo, hi)
        xr[8] = Float64(round(Int, clamp(xr[8], 3, 16)))
        xr[10] = Float64(round(Int, clamp(xr[10], 1, 3)))   # rotor_count_mode: x10 = count {1,2,3}

        r = KiteTurbineDynamics.evaluate_windowed(
            xr, PROFILE_ELLIPTICAL, p_base, cfg;
            start_mode = :cold,
            lift_device = lift_for,
            fitness_fn = (P, F, c, m) -> KiteTurbineDynamics.mass_min_fitness(P, F, c, m),
        )

        # Expected tension via the evaluator's own build chain — with the
        # rung-scaled base (base_params=p_base), lifter excluded.  Decode with
        # the SAME knobs as the runner so m_airborne is the machine the campaign
        # actually builds (rotor_count_mode + three-section + blocking).
        dec = design_from_vector_v10(xr, PROFILE_ELLIPTICAL, p_base; power_W=PW,
            cylinder_cone=true, rotor_count_mode=true,
            power_split=0.6, cone_slope_deg=22.0,
            rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
        sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
            dec, 1.0, cfg.k_mppt; tether_diameter=cfg.tether_diameter,
            base_params=p_base)
        m_airborne = KiteTurbineDynamics.expansion_airborne_mass(sys, pc; include_lifter=false)
        T_exp = 1.5 * m_airborne * 9.81 / sind(70.0)

        status_ok = r.status === :ok
        rel = abs(r.T_lift - T_exp) / T_exp
        passed = status_ok && rel <= 0.05
        all_ok &= passed
        @printf("L=%4.1f  status=%-6s  P_mean=%6.2f kW  P_end=%6.2f kW  FoS=%6.2f  T_in=%7.1f N  T_exp=%7.1f N  rel=%5.2f%%  m_airborne=%7.2f kg  %s\n",
            L, r.status, r.P_mean, r.P_end, r.FoS_min, r.T_lift, T_exp, 100 * rel, m_airborne,
            passed ? "PASS" : "** FAIL **")
        flush(stdout)
    end

    println(all_ok ? "SMOKE: ALL PASS" : "SMOKE: FAILURES — do not launch")
    return all_ok
end

exit(main() ? 0 : 1)
