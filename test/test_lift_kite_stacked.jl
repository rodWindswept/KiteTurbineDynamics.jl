# test/test_lift_kite_stacked.jl
# Acceptance tests for the sized stacked lifter's const_tension capability
# (Rod 2026-08-18: campaign lift = 1.5× genome mass vertical, CONSTANT at all
# wind speeds — modulated-lifter assumption).
# Proposal: docs/plans/2026-08-18-5kw-mass-aware-lift-redo.md

const KTD = KiteTurbineDynamics

# Local copy of the campaign params helper (params_10kw with custom length,
# mass-scaled to 5 kW) — same construction as scripts/run_v13_5kw.jl.
function _params_at_length_5kw(L::Float64)
    p2 = KTD.params_10kw()
    geo = KTD.GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        L, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = KTD.MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = KTD.AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = KTD.ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = KTD.BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return KTD.mass_scale(KTD.SystemParams(geo, mat, aero, ctrl, back), 10.0, 5.0)
end

@testset "StackedLifter const-tension" begin
    rho = 1.225
    m = 100.0
    margin = 1.5
    elev = 70.0
    g = 9.81
    T_ref = margin * m * g / sind(elev)

    # A — default (const_tension=false) preserves v² scaling (bit-identical legacy)
    dev_v2 = KTD.StackedLifterParams(T_ref, 11.0, elev, margin, m, 5.0, 200_000.0, 25.0, false)
    _, Tv2_11, _ = lift_force_steady(dev_v2, rho, 11.0)
    _, Tv2_55, _ = lift_force_steady(dev_v2, rho, 5.5)
    _, Tv2_22, _ = lift_force_steady(dev_v2, rho, 22.0)
    @test Tv2_11 ≈ T_ref atol = 1e-9
    @test Tv2_55 ≈ T_ref / 4 atol = 1e-6
    @test Tv2_22 ≈ 4 * T_ref atol = 1e-6

    # B — const_tension=true: FLAT tension at every wind speed
    dev_c = KTD.StackedLifterParams(T_ref, 11.0, elev, margin, m, 5.0, 200_000.0, 25.0, true)
    for v in (0.0, 3.0, 11.0, 25.0)
        _, Tc, _ = lift_force_steady(dev_c, rho, v)
        @test Tc ≈ T_ref atol = 1e-9
    end

    # C — vertical component = margin × weight (the 1.5× rule)
    _, T, el = lift_force_steady(dev_c, rho, 11.0)
    @test T * sind(el) ≈ margin * m * g rtol = 1e-9

    # D — sized_lifter_for kwarg round-trip on a real 5 kW system
    p = _params_at_length_5kw(18.0)
    seed14 = [0.019, 0.01, 0.88, 1.0, 0.914, 0.632, 2.988, 13.0, -0.11, 18.56, 31.99, 35.0, 0.519, 0.1]
    dec = design_from_vector_v10(seed14, PROFILE_ELLIPTICAL, p; power_W = 5000.0, v_rated = 11.0)
    sys, u0, pc = KTD.build_system_from_v10(dec, 1.0, p.k_mppt; tether_diameter = p.tether_diameter)
    m_air = expansion_airborne_mass(sys, pc)

    dev_sized = KTD.sized_lifter_for(sys, pc; margin = 1.5, v_ref = 11.0, const_tension = true)
    @test dev_sized.const_tension === true
    @test dev_sized.T_ref ≈ 1.5 * m_air * 9.81 / sind(70.0) rtol = 1e-9

    # Flat at low wind even when the SystemParams elevation is passed in
    _, Ts3, _ = lift_force_steady(dev_sized, pc.rho, 3.0, pc)
    @test Ts3 ≈ dev_sized.T_ref atol = 1e-9

    # Default stays false — Phase A / legacy semantics unchanged
    dev_def = KTD.sized_lifter_for(sys, pc; margin = 1.5, v_ref = 11.0)
    @test dev_def.const_tension === false
end
