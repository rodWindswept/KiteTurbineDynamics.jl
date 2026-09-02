# test/test_mass_model_2026_09.jl
# T1 — mass-model fix: minimum 2 mm tube wall, per-ring mass summation, and
# ring→cable knuckles (docs/plans/2026-09-02-tickets.md).
#
# These are STATIC tests on the DE's airborne-mass model.  They pin:
#   (a) the per-ring ring-mass sum is GREATER than the old single "average ring"
#       for the island-1 winner geometry (the exploit the old law allowed);
#   (b) no tube wall is ever thinner than 2 mm (the new floor);
#   (c) the ring→cable knuckles are counted (they were previously free).

using Test, KiteTurbineDynamics

const BF = 0.75^(1 / 3)   # 0.75× power wake de-rate ≈ 0.9086
const K_MPPT = 2.24       # K_MPPT_5KW_HONEST (single source lives in scripts/compute_seeds.jl)

# Daisy 1.5 kW → 5 kW at 18.8 m (mirrors run_v13_5kw_masslift.jl).
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

# Island-1 (global best) winner genome.
const WINNER_X = [0.03, 0.0275, 0.513, 1.6, 4.314, 0.862, 2.722, 3.0,
                  -0.173, 1.0, 1.173, 0.153, 0.635, 0.14]

function winner_decode()
    x = copy(WINNER_X)
    x[8] = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = Float64(round(Int, clamp(x[10], 1, 3)))
    p = params_5kw_188()
    return KiteTurbineDynamics.design_from_vector_v10(
        x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
        cylinder_cone=true, rotor_count_mode=true,
        power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=BF), p
end

function winner_system()
    dec, p = winner_decode()
    sys, _, pc = KiteTurbineDynamics.build_system_from_v10(
        dec, 1.0, K_MPPT; tether_diameter=p.tether_diameter, base_params=p)
    return sys, pc, dec
end

@testset "mass model 2026-09 — 2 mm wall floor" begin
    @test KiteTurbineDynamics.MIN_TUBE_WALL_M == 2e-3
    # 30 mm tube at t/D 0.0275 → 0.825 mm wall, floored UP to 2 mm.
    @test KiteTurbineDynamics.tube_wall_thickness(30e-3, 0.0275) ≈ 2e-3
    # A big tube whose natural wall is already above the floor is untouched.
    @test KiteTurbineDynamics.tube_wall_thickness(0.1, 0.0275) ≈ 2.75e-3
    # A 2.3 mm tube cannot hold a 2 mm wall → it clamps to a solid rod (t = Do/2).
    @test KiteTurbineDynamics.tube_wall_thickness(2.3e-3, 0.0275) ≈ 1.15e-3
end

@testset "mass model 2026-09 — per-ring sum beats the old average" begin
    sys, _, dec = winner_system()
    d = dec.design
    # OLD single "average ring" (no wall floor), reproduced for comparison.
    r_avg = 0.5 * (d.r_hub + d.r_bottom)
    Do_avg = d.Do_top * (r_avg / d.r_hub)^d.Do_scale_exp
    t_avg = d.t_over_D * Do_avg
    L_avg = 2.0 * r_avg * sin(π / d.n_lines)
    area_avg = π / 4.0 * (Do_avg^2 - (Do_avg - 2t_avg)^2)
    old_m_ring = max(d.n_lines * 1600.0 * area_avg * L_avg, 0.05)
    old_ring_total = (sys.n_ring - 1) * old_m_ring

    @test sys.ring_mass_total[] > 0.0
    @test sys.ring_mass_total[] > old_ring_total
    # The per-ring sum must equal an independent recomputation.
    airborne = dec.radii[2:end]
    expected = sum(
        KiteTurbineDynamics.ring_beam_mass(
            d.Do_top * (r / d.r_hub)^d.Do_scale_exp, d.t_over_D, d.n_lines,
            2.0 * r * sin(π / d.n_lines)) for r in airborne)
    @test sys.ring_mass_total[] ≈ expected atol=1e-9
end

@testset "mass model 2026-09 — ring→cable knuckles counted" begin
    sys, _, dec = winner_system()
    d = dec.design
    @test sys.ring_knuckle_mass[] > 0.0
    # One knuckle per line per airborne ring, priced by the shared geometric rule.
    airborne = dec.radii[2:end]
    expected = sum(
        d.n_lines * KiteTurbineDynamics.knuckle_mass_at_ring(
            d.Do_top * (r / d.r_hub)^d.Do_scale_exp, d.t_over_D, d.n_lines)
        for r in airborne; init=0.0)
    @test sys.ring_knuckle_mass[] ≈ expected atol=1e-9
end

@testset "mass model 2026-09 — airborne mass jumps" begin
    sys, pc, _ = winner_system()
    m = KiteTurbineDynamics.expansion_airborne_mass(sys, pc; include_lifter=false)
    @test m > 6.0   # the old model reported ~4.6 kg; the fix must raise it materially
end
