#!/usr/bin/env julia
# test/test_blade_geometry.jl
# Assertion: expansion rotor blade hub is inboard of ring (negative offset),
# tip is outboard (positive offset). 70/30 split around ring attachment.
#
# Run: julia --project=. test/test_blade_geometry.jl

using Test
using KiteTurbineDynamics

@testset "Blade geometry — 70/30 split" begin

    # ═══ Test 1: builders_util.jl — V10 Tight (blade_scale=1.0) ═══
    @testset "V10 Tight λ=1.0" begin
        include(joinpath(@__DIR__, "..", "scripts", "builders_util.jl"))
        sys, u0, p, label = Base.invokelatest(
            build_v10_tight_no_lowest; blade_scale=1.0)

        @test !isempty(sys.expansion_rotors) "V10 Tight must have expansion rotors"
        for (i, er) in enumerate(sys.expansion_rotors)
            @test er.blade_tip_radius > 0 "Rotor $i: tip must be outboard (positive)"
            @test er.blade_hub_radius < 0 "Rotor $i: hub must be inboard (negative)"
            span = er.blade_tip_radius - er.blade_hub_radius
            @test span > 0 "Rotor $i: span must be positive"
            @test er.blade_tip_radius ≈ 0.7 * span atol=1e-9 "Rotor $i: tip ≈ 70% of span"
            @test -er.blade_hub_radius ≈ 0.3 * span atol=1e-9 "Rotor $i: |hub| ≈ 30% of span"
        end
    end

    # ═══ Test 2: V10 Tight λ=0.69 (blade-scaled) ═══
    @testset "V10 Tight λ=0.69" begin
        sys, u0, p, label = Base.invokelatest(
            build_v10_tight_no_lowest; blade_scale=0.69)

        for (i, er) in enumerate(sys.expansion_rotors)
            @test er.blade_tip_radius > 0
            @test er.blade_hub_radius < 0
            span = er.blade_tip_radius - er.blade_hub_radius
            @test er.blade_tip_radius ≈ 0.7 * span atol=1e-9
            @test -er.blade_hub_radius ≈ 0.3 * span atol=1e-9
        end
    end

    # ═══ Test 3: V10 Reinforced ═══
    @testset "V10 Reinforced" begin
        sys, u0, p, label = Base.invokelatest(
            build_v10_tight_no_lowest; r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0)

        for (i, er) in enumerate(sys.expansion_rotors)
            @test er.blade_tip_radius > 0
            @test er.blade_hub_radius < 0
            span = er.blade_tip_radius - er.blade_hub_radius
            @test er.blade_tip_radius ≈ 0.7 * span atol=1e-9
            @test -er.blade_hub_radius ≈ 0.3 * span atol=1e-9
        end
    end

    # ═══ Test 4: ExpansionStackConfig default construction ═══
    @testset "ExpansionStackConfig defaults" begin
        # Build a minimal config and check the geometry
        r_rotor = 5.0  # typical BEM rotor radius
        cfg = ExpansionStackConfig(;
            placement=:clustered, n_rings=22, n_expansion=1,
            n_blades=8,
            blade_tip_radius=0.7 * r_rotor,
            blade_hub_radius=-0.3 * r_rotor,
            blade_chord=0.113 * r_rotor,
            CL_blade=1.0, CD0_blade=0.02, k_induced=0.05,
            bank_angle_deg=35.0, mass_per_rotor=0.5, shaft_coupling=1.0,
        )
        @test cfg.blade_tip_radius > 0
        @test cfg.blade_hub_radius < 0
    end

end  # @testset

println("\n✓ All blade geometry assertions passed — 70/30 split verified.")
