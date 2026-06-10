@testset "expansion stack — configuration generator" begin

    # === Test 1: Alternating placement ===
    @testset "alternating placement" begin
        cfg = ExpansionStackConfig(
            placement       = :alternating,
            n_rings         = 10,
            n_expansion     = 3,
            blade_radius    = 0.8,
            hub_radius      = 0.15,
            blade_chord     = 0.06,
            CL_blade        = 1.0,
            CD0_blade       = 0.02,
            k_induced       = 0.05,
            bridle_angle_deg = 15.0,
            mass_per_rotor  = 0.4,
            shaft_coupling  = 1.0,
        )
        stack = build_expansion_stack(cfg)

        @test length(stack) == 3
        # Alternating on 10 rings with 3 expansion rotors:
        # Should be at rings 2, 4, 6 (every other, skipping ground ring 1 and hub ring 10)
        @test stack[1].ring_idx == 2
        @test stack[2].ring_idx == 4
        @test stack[3].ring_idx == 6
        @test all(er -> er.n_blades == 3, stack)
        @test all(er -> er.blade_radius ≈ 0.8, stack)
    end

    # === Test 2: Clustered placement ===
    @testset "clustered placement (hub-ward)" begin
        cfg = ExpansionStackConfig(
            placement       = :clustered,
            n_rings         = 10,
            n_expansion     = 4,
            blade_radius    = 1.0,
            hub_radius      = 0.2,
            blade_chord     = 0.08,
            CL_blade        = 1.2,
            CD0_blade       = 0.015,
            k_induced       = 0.04,
            bridle_angle_deg = 20.0,
            mass_per_rotor  = 0.5,
            shaft_coupling  = 1.0,
        )
        stack = build_expansion_stack(cfg)

        @test length(stack) == 4
        # Clustered on 10 rings: should be at rings 7, 8, 9, 10 (hub-ward)
        # Skip ring 10 (hub — already has main rotor)
        @test stack[1].ring_idx == 9   # closest to hub
        @test stack[end].ring_idx == 6 # furthest from hub
    end

    # === Test 3: Custom placement ===
    @testset "custom placement" begin
        cfg = ExpansionStackConfig(
            placement       = :custom,
            custom_rings    = [3, 5, 8],
            n_rings         = 10,
            n_expansion     = 3,
            blade_radius    = 0.6,
            hub_radius      = 0.1,
            blade_chord     = 0.04,
            CL_blade        = 0.9,
            CD0_blade       = 0.025,
            k_induced       = 0.06,
            bridle_angle_deg = 12.0,
            mass_per_rotor  = 0.3,
            shaft_coupling  = 1.0,
        )
        stack = build_expansion_stack(cfg)

        @test length(stack) == 3
        @test stack[1].ring_idx == 3
        @test stack[2].ring_idx == 5
        @test stack[3].ring_idx == 8
    end

    # === Test 4: Zero expansion rotors ===
    @testset "zero expansion rotors" begin
        cfg = ExpansionStackConfig(
            placement       = :alternating,
            n_rings         = 10,
            n_expansion     = 0,
            blade_radius    = 0.8,
            hub_radius      = 0.15,
            blade_chord     = 0.06,
            CL_blade        = 1.0,
            CD0_blade       = 0.02,
            k_induced       = 0.05,
            bridle_angle_deg = 15.0,
            mass_per_rotor  = 0.4,
            shaft_coupling  = 1.0,
        )
        stack = build_expansion_stack(cfg)
        @test isempty(stack)
    end

    # === Test 5: n_expansion > available rings → clamped ===
    @testset "clamped to available rings" begin
        cfg = ExpansionStackConfig(
            placement       = :alternating,
            n_rings         = 5,
            n_expansion     = 10,   # more than available
            blade_radius    = 0.5,
            hub_radius      = 0.1,
            blade_chord     = 0.04,
            CL_blade        = 1.0,
            CD0_blade       = 0.02,
            k_induced       = 0.05,
            bridle_angle_deg = 10.0,
            mass_per_rotor  = 0.3,
            shaft_coupling  = 1.0,
        )
        stack = build_expansion_stack(cfg)
        # Available: rings 2..(n_rings-1) = 2,3,4 (skip ground=1, skip hub=5)
        # Alternating from 2 gives [2,4] = 2 rotors max
        @test length(stack) == 2
    end

    # === Test 6: Bridle angle affects radial/axial split ===
    @testset "bridle angle stored correctly" begin
        cfg = ExpansionStackConfig(
            placement       = :clustered,
            n_rings         = 8,
            n_expansion     = 2,
            blade_radius    = 0.7,
            hub_radius      = 0.12,
            blade_chord     = 0.05,
            CL_blade        = 1.1,
            CD0_blade       = 0.018,
            k_induced       = 0.045,
            bridle_angle_deg = 25.0,
            mass_per_rotor  = 0.45,
            shaft_coupling  = 1.0,
        )
        stack = build_expansion_stack(cfg)
        @test all(er -> er.bridle_angle_deg ≈ 25.0, stack)
        @test all(er -> er.mass ≈ 0.45, stack)
        @test all(er -> er.n_blades == 3, stack)
    end

end
