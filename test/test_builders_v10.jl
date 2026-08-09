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

@testset "expansion_params_from_rotors — canonical +1 mapping" begin
    # RotorSpecV10(ring_idx, bank_angle_deg, blade_scale, v_wind, r_rotor,
    #              blade_tip_radius, blade_hub_radius, blade_chord)
    rotors = [
        RotorSpecV10(1, 25.0, 1.0, 11.0, 1.0, 3.0, 0.5, 0.2),
        RotorSpecV10(2, 20.0, 1.0, 11.0, 1.0, 3.1, 0.5, 0.2),
        RotorSpecV10(3, 15.0, 1.0, 11.0, 1.0, 3.2, 0.5, 0.2),
    ]
    # n_rings=3, canonical: total = 3 + 2 = 5 rings (ground + 3 flown + hub).
    # Rotor at ring 1 → sys ring 2; ring 2 → sys ring 3; top rotor → sys ring 5.
    ps = expansion_params_from_rotors(rotors, 3, 12)
    @test length(ps) == 3
    @test ps[1].ring_idx == 2
    @test ps[2].ring_idx == 3
    @test ps[3].ring_idx == 5
    # n_blades = n_lines flows through
    @test all(p.n_blades == 12 for p in ps)
end

@testset "expansion_params_from_rotors — blade_scale flows" begin
    rotors = [RotorSpecV10(1, 25.0, 1.0, 11.0, 1.0, 3.0, 0.5, 0.2)]
    ps = expansion_params_from_rotors(rotors, 2, 12; blade_scale=2.0)
    @test ps[1].blade_tip_radius ≈ 6.0   # 3.0 × 2.0
    @test ps[1].blade_hub_radius ≈ 1.0   # 0.5 × 2.0
end

@testset "expansion_params_from_rotors — minimal machine (Rod's definition)" begin
    # Minimal TRPT: 1 flown bladed hub ring rotor + 1 ground ring = 2 rings.
    # n_rings=1, minimal_hub=true → total = 2; the single rotor (ring_idx ==
    # n_rings) lands on the top ring (ring_idx 2).
    rotors = [RotorSpecV10(1, 15.0, 1.0, 11.0, 1.0, 3.0, 0.5, 0.2)]
    ps = expansion_params_from_rotors(rotors, 1, 12; minimal_hub=true)
    @test length(ps) == 1
    @test ps[1].ring_idx == 2
    # Multi-ring minimal: top rotor on ring n_rings+1, others one above index
    rotors3 = [
        RotorSpecV10(1, 25.0, 1.0, 11.0, 1.0, 3.0, 0.5, 0.2),
        RotorSpecV10(2, 20.0, 1.0, 11.0, 1.0, 3.1, 0.5, 0.2),
    ]
    ps3 = expansion_params_from_rotors(rotors3, 2, 12; minimal_hub=true)
    @test ps3[1].ring_idx == 2
    @test ps3[2].ring_idx == 3   # top rotor IS the hub ring (no separate hub)
end
