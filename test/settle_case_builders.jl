# test/settle_case_builders.jl
#
# Shared case builders for the settle guards.  Extracted 2026-09-13 so there is
# exactly ONE definition of the 5 kW / 18.8 m campaign-seed cases: the handover's
# standing caution is that a duplicated harness drifts, and a typo in a throwaway
# copy then masquerades as physics (it cost the 2026-09-12/13 sessions twice).
#
# Consumers:
#   test_settle_preload_consistency.jl   (tension == intended preload)
#   test_trpt_realisability.jl           (the torsional cliff)
#
# Requires `using KiteTurbineDynamics` and scripts/compute_seeds.jl to have been
# included first (both callers do this).

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    # EA_back_line is PINNED here, after the scaling (Rod, 2026-09-16).  The 5 kW
    # back line is 3 mm Dyneema: EA = 100 GPa × π(0.003)²/4 ≈ 707 kN.  It must be
    # pinned AFTER `mass_scale`, because that multiplies the field by
    # geom_scale = 1.826 and would otherwise carry the 1.5 kW 2 mm figure up to
    # 1.29 MN, about 1.8x the spec.  Back-line tension is linear in EA, so the
    # bungee stiffness would inherit that error.
    return override_params(
        mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
        tether_length=18.8, EA_back_line=707_000.0)
end

# `nothing` for a gene keeps the seed's own value (the campaign seed).
function build_case(n_lines, rotor_count)
    p = params_5kw_188()
    x = seed_genome(5.0)
    n_lines === nothing || (x[4] = Float64(n_lines))
    rotor_count === nothing || (x[6] = rotor_count)
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
