# test/test_settle_blocking_2026_09.jl
#
# Regression (2026-09-02): the cold-start settle equilibrium scan must apply the
# per-rotor wake de-rate (downstream rotors at 0.75× power → wind factor
# 0.75^(1/3)) so a multi-rotor machine starts at its blocked equilibrium instead
# of overshooting and then decaying in the ODE.
#
# The scan's power expression is factored into `settle_aero_power(sys, p, w,
# v_mag)` (src/initialization.jl).  These tests pin that the helper de-rates the
# hub and the downstream (upper) expansion rotors, and leaves the lowest
# (upstream) rotor un-de-rated.

using Test, KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))

function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0); tether_length=18.8)
end

function build_system(rotor_count::Float64)
    p = params_5kw_188()
    x = seed_genome(5.0)
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = rotor_count
    dec = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, p;
        power_W=5000.0, cylinder_cone=true, rotor_count_mode=true, power_split=0.6,
        cone_slope_deg=22.0, rotor_spacing_frac=0.8, blocking_factor=BLOCKING_WIND_FACTOR_5KW)
    sys, u0, pc = KiteTurbineDynamics.build_system_from_v10(
        dec, 1.0, K_MPPT_5KW_HONEST; tether_diameter=p.tether_diameter, base_params=p)
    return sys, pc
end

# Explicit-factors reference of the settle aero power (the "spec" the helper
# must reproduce): hub uses `hub_factor`, each expansion rotor uses its own
# factor from `exp_factors` (in order).
function ref_power(sys, pc, w, v_mag; hub_factor, exp_factors)
    v_hub = v_mag * hub_factor
    lambda = w * sys.rotor.radius / v_hub
    P = 0.5 * pc.rho * v_hub^3 *
        π * (sys.rotor.radius^2 - sys.rotor.blade_hub_radius^2) *
        cp_at_tsr(lambda) * cos(pc.elevation_angle)^2.65
    for (er, f) in zip(sys.expansion_rotors, exp_factors)
        v_er = v_mag * f
        r_nom = (sys.nodes[sys.ring_ids[er.ring_idx]]::KiteTurbineDynamics.RingNode).radius
        area = expansion_annulus_area(er, r_nom)
        r_rep = r_nom + (er.blade_hub_radius + er.blade_tip_radius) / 2 * cosd(er.bank_angle_deg)
        lambda_er = clamp(w * r_rep / v_er, 0.0, 12.0)
        P += 0.5 * pc.rho * v_er^3 * area * cp_at_tsr(lambda_er)
    end
    return P
end

@testset "settle blocking — wind factors populated (3 rotors)" begin
    sys, _ = build_system(3.0)
    @test sys.rotor.wind_factor ≈ BLOCKING_WIND_FACTOR_5KW atol=1e-12  # hub (downstream)
    @test length(sys.expansion_rotors) == 2
    @test sys.expansion_rotors[1].wind_factor ≈ BLOCKING_WIND_FACTOR_5KW atol=1e-12  # middle
    @test sys.expansion_rotors[2].wind_factor == 1.0  # lowest (upstream)
end

@testset "settle blocking — helper de-rates hub + middle, leaves lowest free" begin
    sys, pc = build_system(3.0)
    w = 10.0
    v_mag = 11.0
    P = KiteTurbineDynamics.settle_aero_power(sys, pc, w, v_mag)
    expected = ref_power(sys, pc, w, v_mag;
        hub_factor=BLOCKING_WIND_FACTOR_5KW,
        exp_factors=[BLOCKING_WIND_FACTOR_5KW, 1.0])
    @test P ≈ expected rtol=1e-12
end

@testset "settle blocking — single rotor is un-de-rated" begin
    sys, pc = build_system(1.0)
    @test sys.rotor.wind_factor == 1.0
    @test isempty(sys.expansion_rotors)
    w = 10.0
    v_mag = 11.0
    P = KiteTurbineDynamics.settle_aero_power(sys, pc, w, v_mag)
    expected = ref_power(sys, pc, w, v_mag; hub_factor=1.0, exp_factors=Float64[])
    @test P ≈ expected rtol=1e-12
end
