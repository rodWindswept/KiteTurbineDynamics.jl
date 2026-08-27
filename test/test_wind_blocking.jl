# test/test_wind_blocking.jl
# Static unit tests for co-axial-rotor wake blocking + ground-clearance authority.
#
# 2026-08-26 (Rod's viewer review): co-axial stacked rotors wake-block each
# other.  Wind flows UP the shaft (hub is downwind), so the UPPER rotors are
# downstream and must see a de-rated inflow; the LOWEST rotor sees freestream.
# 0.75× power → wind factor 0.75^(1/3).  Separately, the lowest-rotor ground
# clearance must use the ABSOLUTE tip radius (ring radius + blade_tip offset),
# never the 0.7·span offset alone.
#
# These are STATIC tests: they pin the decode + plumbing contract only.  The
# ODE-level de-rate behaviour is exercised by the acceptance suite.

using Test, KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))

const BF = 0.75^(1 / 3)   # ≈ 0.9086 — 0.75× power under P ∝ v³

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

function decode_seed(; rotor_count=3.0, blocking_factor=BF)
    x = [0.06, 0.01, 1.0, 1.0, 2.775, 0.575, 2.0, 6.0, 0.0,
         rotor_count, 0.0, 0.0, 0.7, 0.7]
    return KiteTurbineDynamics.design_from_vector_v10(
        x, PROFILE_ELLIPTICAL, params_5kw_188(); power_W=5000.0,
        cylinder_cone=true, rotor_count_mode=true,
        power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=blocking_factor)
end

@testset "wind blocking — decode direction (downstream = upper rotors)" begin
    # 3 rotors: hub (top) + middle are downstream (blocked); bottom is upstream.
    dec3 = decode_seed(; rotor_count=3.0)
    @test dec3.n_active == 3
    @test [r.wind_factor for r in dec3.rotors] ≈ [BF, BF, 1.0] atol=1e-12

    # 2 rotors: hub blocked, bottom freestream.
    dec2 = decode_seed(; rotor_count=2.0)
    @test dec2.n_active == 2
    @test [r.wind_factor for r in dec2.rotors] ≈ [BF, 1.0] atol=1e-12

    # 1 rotor: no wake partner — freestream.
    dec1 = decode_seed(; rotor_count=1.0)
    @test dec1.n_active == 1
    @test [r.wind_factor for r in dec1.rotors] == [1.0]
end

@testset "wind blocking — rotor ordering is top→bottom" begin
    dec3 = decode_seed(; rotor_count=3.0)
    n = dec3.n_rings
    @test [r.ring_idx for r in dec3.rotors] == [n, n - 1, n - 2]
    # The downstream (blocked) rotors sit ABOVE the upstream (freestream) rotor.
    @test dec3.rotors[1].ring_idx > dec3.rotors[3].ring_idx
end

@testset "decode returns ring radii (ground-first) for clearance" begin
    dec3 = decode_seed(; rotor_count=3.0)
    @test haskey(dec3, :radii)
    @test length(dec3.radii) == length(dec3.zs)
    @test dec3.radii[1] ≈ dec3.design.r_bottom atol=1e-6   # transmission cylinder
    @test dec3.radii[end] ≈ dec3.design.r_hub atol=1e-6    # harvest cylinder
end

@testset "lowest_rotor_clearance — absolute tip + elevation (bank=0)" begin
    dec3 = decode_seed(; rotor_count=3.0)   # bank_top = bank_bottom = 0
    # Locate the lowest rotor (min shaft z) and its true tip radius.
    zs = dec3.zs
    low = dec3.rotors[1]
    z_low = zs[clamp(low.ring_idx, 1, length(zs))]
    for r in dec3.rotors
        zr = zs[clamp(r.ring_idx, 1, length(zs))]
        if zr < z_low
            z_low = zr
            low = r
        end
    end
    r_tip_abs = dec3.radii[low.ring_idx] + low.blade_tip_radius
    # Geometrically correct: tip drop = r_tip·cos(elevation) for a 30° shaft.
    expected = 1.0 + z_low * sind(30.0) - r_tip_abs * cosd(30.0)
    @test KiteTurbineDynamics.lowest_rotor_clearance(dec3) ≈ expected atol=1e-9

    # Regression: the offset-only form (the old bug) must read HIGHER clearance.
    offset_only = 1.0 + z_low * sind(30.0) - low.blade_tip_radius
    @test KiteTurbineDynamics.lowest_rotor_clearance(dec3) < offset_only

    # Regression: the no-cos form (subtracting full r_tip) must read LOWER.
    no_cos = 1.0 + z_low * sind(30.0) - r_tip_abs
    @test KiteTurbineDynamics.lowest_rotor_clearance(dec3) > no_cos
end

@testset "lowest_rotor_clearance — bank angle swings the tip lower" begin
    # Same genome but bank_bottom = 22° (x[12]): the lowest rotor's outer tip
    # banks toward the ground, so clearance must DECREASE vs bank = 0.
    dec0 = decode_seed(; rotor_count=3.0)
    x = [0.06, 0.01, 1.0, 1.0, 2.775, 0.575, 2.0, 6.0, 0.0, 3.0, 0.0, 22.0, 0.7, 0.7]
    dec22 = KiteTurbineDynamics.design_from_vector_v10(
        x, PROFILE_ELLIPTICAL, params_5kw_188(); power_W=5000.0,
        cylinder_cone=true, rotor_count_mode=true,
        power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=BF)
    @test KiteTurbineDynamics.lowest_rotor_clearance(dec22) <
          KiteTurbineDynamics.lowest_rotor_clearance(dec0)
end

@testset "RotorSpecV10 — 8-arg legacy constructor defaults wind_factor=1.0" begin
    r = RotorSpecV10(7, 25.0, 1.0, 11.0, 1.0, 3.0, 0.5, 0.2)
    @test r.wind_factor == 1.0
end

@testset "ExpansionRotorParams — 11-arg legacy constructor defaults wind_factor=1.0" begin
    er = ExpansionRotorParams(3, 1.0, 0.5, 0.1, 1.0, 0.02, 0.05, 15.0, 0.5, 3, 1.0)
    @test er.wind_factor == 1.0
end

@testset "RotorSpec — 5-arg legacy constructor defaults wind_factor=1.0" begin
    rs = KiteTurbineDynamics.RotorSpec(1, 2.0, 0.5, 1.0, 4.0)
    @test rs.wind_factor == 1.0
end

@testset "expansion_params_from_rotors propagates wind_factor" begin
    rotors = [
        RotorSpecV10(7, 25.0, 1.0, 11.0, 1.0, 3.0, 0.5, 0.2, BF),  # hub — excluded
        RotorSpecV10(6, 20.0, 1.0, 11.0, 1.0, 3.1, 0.5, 0.2, BF),  # downstream
        RotorSpecV10(5, 15.0, 1.0, 11.0, 1.0, 3.2, 0.5, 0.2, 1.0), # upstream
    ]
    ps = expansion_params_from_rotors(rotors, 7, 12)
    @test length(ps) == 2
    @test ps[1].ring_idx == 6
    @test ps[2].ring_idx == 5
    @test ps[1].wind_factor ≈ BF atol=1e-12   # middle (downstream)
    @test ps[2].wind_factor == 1.0            # lowest (upstream)
end
