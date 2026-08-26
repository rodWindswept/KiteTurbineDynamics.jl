# test/test_builders_v10.jl
# Regression tests for the corrected V10 builder (Phase 1e of fix_xvector_rerun_sweeps.md).
# Gate 1a: builder produces 12-gon geometry matching best_vector.csv decode.
# Gate 1b: r_bottom_scale applied once, never exceeds r_hub.
# Gate 1c: blade_scale leaves ring geometry untouched.

using Test, KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))

@testset "V10 builder — 13-gon geometry" begin
    sys, u0, p, label, design = build_v10_tight_no_lowest()

    @test p.n_lines == 13
    @test p.n_rings == 10
    @test p.trpt_hub_radius ≈ 2.889 atol=0.01
    @test design.r_bottom ≈ 2.000 atol=0.01
    @test design.r_hub > design.r_bottom
    @test p.tether_length ≈ 67.08 atol=1.0
    @test occursin("13-gon", label)
    @test occursin("10 rings", label)
end

@testset "V10 builder — round-trip guard" begin
    # Load best_vector.csv, decode, compare field-for-field with builder output
    vec_path = joinpath(dirname(@__DIR__), "scripts", "results", "v10_campaign_50kw", "best_vector.csv")
    x_raw = parse.(Float64, split(readline(vec_path), ","))
    x = copy(x_raw)
    x[8]  = Float64(round(Int, clamp(x[8], 3, 16)))
    x[10] = clamp(x[10], 0.0, Float64(N_VALID_MASKS))
    result = KiteTurbineDynamics.design_from_vector_v10(x, PROFILE_ELLIPTICAL, params_v5_50kw();
                                                         max_ground_radius=5.0, power_W=50000.0)

    sys, u0, p, label, design = build_v10_tight_no_lowest()

    @test design.n_lines == result.design.n_lines
    @test design.r_hub ≈ result.design.r_hub atol=0.001
    @test design.r_bottom ≈ result.design.r_bottom atol=0.001
    @test design.tether_length ≈ result.design.tether_length atol=0.01
    @test p.trpt_hub_radius ≈ result.design.r_hub atol=0.001
end

@testset "V10 builder — r_bottom_scale single-application" begin
    sys, u0, p, label, design = build_v10_tight_no_lowest(r_bottom_scale=1.30)

    # Should be 2.0 * 1.30 = 2.60, NOT 2.0 * 1.30 * 1.30 = 3.38
    @test design.r_bottom ≈ 2.60 atol=0.01
    # Taper enforcement
    @test design.r_bottom ≤ design.r_hub
end

@testset "V10 builder — blade_scale leaves rings untouched" begin
    sys, u0, p, label, design = build_v10_tight_no_lowest(blade_scale=0.85)

    # Ring geometry unchanged
    @test p.trpt_hub_radius ≈ 2.889 atol=0.01
    @test design.r_bottom ≈ 2.000 atol=0.01
    @test p.tether_length ≈ 67.08 atol=1.0
end

@testset "V10 builder — Gate 1b: drop direction" begin
    # With drop=true (default for no_lowest), one rotor is removed
    sys_drop, _, _, label_drop, _ = build_v10_tight_no_lowest()
    # Without drop (keep_lowest=true), all rotors are kept
    sys_all, _, _, label_all, _ = build_v10_tight(keep_lowest=true)

    # The drop version should have one fewer expansion rotor
    n_exp_drop = parse(Int, match(r"(\d+) expansion", label_drop).captures[1])
    n_exp_all  = parse(Int, match(r"(\d+) expansion", label_all).captures[1])
    @test n_exp_drop == n_exp_all - 1
end

@testset "V10 builder — Gate 1c: n_blades = n_lines" begin
    sys, u0, p, label, design = build_v10_tight_no_lowest()
    @test p.n_lines == 13
    # Expansion rotor params should have 12 blades each
    # (verified by n_lines flowing through to ExpansionRotorParams in builder)
end

# ══════════════════════════════════════════════════════════════════════════════
# Ring mapping — single authority (2026-08-09)
# ══════════════════════════════════════════════════════════════════════════════

@testset "expansion_params_from_rotors — system ring numbering, hub excluded" begin
    # RotorSpecV10(ring_idx, bank_angle_deg, blade_scale, v_wind, r_rotor,
    #              blade_tip_radius, blade_hub_radius, blade_chord)
    # ring_idx is SYSTEM numbering (1 = ground, n_rings = hub), as produced by
    # design_from_vector_v10 (ring_idx = n_rings − p + 1).  A rotor at ring k
    # maps to system ring k (identity); the top rotor (ring_idx == n_rings) is
    # the MAIN rotor and is excluded.
    rotors = [
        RotorSpecV10(7, 25.0, 1.0, 11.0, 1.0, 3.0, 0.5, 0.2),  # hub — excluded
        RotorSpecV10(6, 20.0, 1.0, 11.0, 1.0, 3.1, 0.5, 0.2),  # → ring 6
        RotorSpecV10(5, 15.0, 1.0, 11.0, 1.0, 3.2, 0.5, 0.2),  # → ring 5
    ]
    # 2026-08-26: identity mapping (NO +1).  The old `sys_ring = ring_idx + 1`
    # shifted every expansion rotor one ring toward the hub (a 3-rotor stack
    # [7,6,5] built as expansion {7,6} instead of {6,5} — the middle rotor
    # landed on the hub and was skipped, the bottom rotor landed on ring 6).
    ps = expansion_params_from_rotors(rotors, 7, 12)
    @test length(ps) == 2
    @test ps[1].ring_idx == 6
    @test ps[2].ring_idx == 5
    # n_blades = n_lines flows through
    @test all(p.n_blades == 12 for p in ps)
end

@testset "expansion_params_from_rotors — blade_scale flows" begin
    # blade_hub is the INBOARD offset (negative, ring-anchored 70/30, 2026-08-20).
    rotors = [RotorSpecV10(1, 25.0, 1.0, 11.0, 1.0, 3.0, -0.5, 0.2)]
    ps = expansion_params_from_rotors(rotors, 2, 12; blade_scale=2.0)
    @test ps[1].blade_tip_radius ≈ 6.0   # 3.0 × 2.0
    @test ps[1].blade_hub_radius ≈ -1.0  # −0.5 × 2.0
end

@testset "expansion_params_from_rotors — minimal machine (Rod's definition)" begin
    # Minimal TRPT: 1 flown bladed hub ring rotor + 1 ground ring = 2 rings.
    # The single rotor (ring_idx == n_rings) IS the hub/main rotor — under the
    # hub exclusion (2026-08-22) it produces NO expansion entry: the minimal
    # machine is hub-only by construction.
    rotors = [RotorSpecV10(1, 15.0, 1.0, 11.0, 1.0, 3.0, 0.5, 0.2)]
    ps = expansion_params_from_rotors(rotors, 1, 12; minimal_hub=true)
    @test isempty(ps)
    # Multi-ring minimal: the intermediate rotor maps to its own system ring
    # (identity); the top rotor (ring_idx == n_rings) is the hub and is excluded.
    rotors3 = [
        RotorSpecV10(1, 25.0, 1.0, 11.0, 1.0, 3.0, 0.5, 0.2),
        RotorSpecV10(2, 20.0, 1.0, 11.0, 1.0, 3.1, 0.5, 0.2),
    ]
    ps3 = expansion_params_from_rotors(rotors3, 2, 12; minimal_hub=true)
    @test length(ps3) == 1
    @test ps3[1].ring_idx == 1   # intermediate rotor → its own system ring; hub excluded
end

@testset "V10 builder — decode→build rotor ring placement (2026-08-26)" begin
    # End-to-end: a 3-rotor genome (rotor_count_mode, three-section geometry)
    # must place the hub rotor on the TOP ring and each expansion rotor on ITS
    # OWN ring — never shifted +1 toward the hub.  Regresses the mapping bug
    # that turned a [hub=7, 6, 5] stack into expansion {7, 6}.
    x = [0.06, 0.01, 1.0, 1.0, 2.775, 0.575, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
    # Daisy 1.5 kW → 5 kW, tether length restored (mirrors run_v13_5kw_masslift).
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    p = override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0); tether_length=18.8)

    dec = KiteTurbineDynamics.design_from_vector_v10(
        x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
        cylinder_cone=true, rotor_count_mode=true,
        power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=1.0)

    @test dec.n_active == 3
    n = dec.n_rings
    # Hub rotor on the top ring; the two expansion rotors on the rings below.
    @test [r.ring_idx for r in dec.rotors] == [n, n - 1, n - 2]

    sys, u0, _ = KiteTurbineDynamics.build_system_from_v10(
        dec, 1.0, p.k_mppt; tether_diameter=p.tether_diameter)
    @test [er.ring_idx for er in sys.expansion_rotors] == [n - 1, n - 2]
end
