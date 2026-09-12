@testset "expansion stack — configuration generator" begin

    # === Test 1: Alternating placement ===
    @testset "alternating placement" begin
        cfg = ExpansionStackConfig(;
            placement=:alternating,
            n_rings=10,
            n_expansion=3,
            n_blades=5,
            blade_tip_radius=3.7,
            blade_hub_radius=0.93,
            blade_chord=0.418,
            CL_blade=1.0,
            CD0_blade=0.02,
            k_induced=0.05,
            bank_angle_deg=15.0,
            mass_per_rotor=0.4,
            shaft_coupling=1.0,
        )
        stack = build_expansion_stack(cfg)

        @test length(stack) == 3
        @test stack[1].ring_idx == 2
        @test stack[2].ring_idx == 4
        @test stack[3].ring_idx == 6
        @test all(er -> er.n_blades == 5, stack)
        @test all(er -> er.blade_tip_radius ≈ 3.7, stack)
    end

    # === Test 2: Clustered placement ===
    @testset "clustered placement (hub-ward)" begin
        cfg = ExpansionStackConfig(;
            placement=:clustered,
            n_rings=10,
            n_expansion=4,
            n_blades=5,
            blade_tip_radius=3.7,
            blade_hub_radius=0.93,
            blade_chord=0.418,
            CL_blade=1.2,
            CD0_blade=0.015,
            k_induced=0.04,
            bank_angle_deg=20.0,
            mass_per_rotor=0.5,
            shaft_coupling=1.0,
        )
        stack = build_expansion_stack(cfg)

        @test length(stack) == 4
        @test stack[1].ring_idx == 9   # closest to hub
        @test stack[end].ring_idx == 6 # furthest from hub
    end

    # === Test 3: Custom placement ===
    @testset "custom placement" begin
        cfg = ExpansionStackConfig(;
            placement=:custom,
            custom_rings=[3, 5, 8],
            n_rings=10,
            n_expansion=3,
            n_blades=3,
            blade_tip_radius=5.0,
            blade_hub_radius=1.25,
            blade_chord=0.565,
            CL_blade=0.9,
            CD0_blade=0.025,
            k_induced=0.06,
            bank_angle_deg=12.0,
            mass_per_rotor=0.3,
            shaft_coupling=1.0,
        )
        stack = build_expansion_stack(cfg)

        @test length(stack) == 3
        @test stack[1].ring_idx == 3
        @test stack[2].ring_idx == 5
        @test stack[3].ring_idx == 8
    end

    # === Test 4: Zero expansion rotors ===
    @testset "zero expansion rotors" begin
        cfg = ExpansionStackConfig(;
            placement=:alternating,
            n_rings=10,
            n_expansion=0,
            n_blades=5,
            blade_tip_radius=3.7,
            blade_hub_radius=0.93,
            blade_chord=0.418,
            CL_blade=1.0,
            CD0_blade=0.02,
            k_induced=0.05,
            bank_angle_deg=15.0,
            mass_per_rotor=0.4,
            shaft_coupling=1.0,
        )
        stack = build_expansion_stack(cfg)
        @test isempty(stack)
    end

    # === Test 5: n_expansion > available rings → clamped ===
    @testset "clamped to available rings" begin
        cfg = ExpansionStackConfig(;
            placement=:alternating,
            n_rings=5,
            n_expansion=10,
            n_blades=3,
            blade_tip_radius=5.0,
            blade_hub_radius=1.25,
            blade_chord=0.565,
            CL_blade=1.0,
            CD0_blade=0.02,
            k_induced=0.05,
            bank_angle_deg=10.0,
            mass_per_rotor=0.3,
            shaft_coupling=1.0,
        )
        stack = build_expansion_stack(cfg)
        @test length(stack) == 2
    end

    # === Test 6: Bank angle stored correctly ===
    @testset "bank angle stored correctly" begin
        cfg = ExpansionStackConfig(;
            placement=:clustered,
            n_rings=8,
            n_expansion=2,
            n_blades=5,
            blade_tip_radius=3.7,
            blade_hub_radius=0.93,
            blade_chord=0.418,
            CL_blade=1.1,
            CD0_blade=0.018,
            k_induced=0.045,
            bank_angle_deg=25.0,
            mass_per_rotor=0.45,
            shaft_coupling=1.0,
        )
        stack = build_expansion_stack(cfg)
        @test all(er -> er.bank_angle_deg ≈ 25.0, stack)
        @test all(er -> er.mass ≈ 0.45, stack)
        @test all(er -> er.n_blades == 5, stack)
    end

end
