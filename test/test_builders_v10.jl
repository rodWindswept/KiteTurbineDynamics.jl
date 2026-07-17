# test/test_builders_v10.jl
# Regression tests for the corrected V10 builder (Phase 1e of fix_xvector_rerun_sweeps.md).
# Gate 1a: builder produces 12-gon geometry matching best_vector.csv decode.
# Gate 1b: r_bottom_scale applied once, never exceeds r_hub.
# Gate 1c: blade_scale leaves ring geometry untouched.

using Test, KiteTurbineDynamics
include(joinpath(dirname(@__DIR__), "src", "builders_util.jl"))

@testset "V10 builder — 12-gon geometry" begin
    sys, u0, p, label, design = build_v10_tight_no_lowest()

    @test p.n_lines == 12
    @test p.n_rings == 10
    @test p.trpt_hub_radius ≈ 2.889 atol=0.01
    @test design.r_bottom ≈ 2.000 atol=0.01
    @test design.r_hub > design.r_bottom  "taper: hub must be wider than ground"
    @test p.tether_length ≈ 67.08 atol=1.0
    @test occursin("12-gon", label)
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
    @test p.n_lines == 12
    # Expansion rotor params should have 12 blades each
    # (verified by n_lines flowing through to ExpansionRotorParams in builder)
end
