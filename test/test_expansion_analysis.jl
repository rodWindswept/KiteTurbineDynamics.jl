@testset "expansion analysis — φ tracking and telemetry" begin

    # === Test 1: Compute airborne mass without expansion rotors ===
    @testset "airborne mass baseline (no expansion)" begin
        p = params_10kw()
        sys, _ = build_kite_turbine_system(p)

        m = expansion_airborne_mass(sys, p)
        # Should include: tether mass + ring mass + blade mass + lifter
        @test m > 0.0
        # For a 10 kW system, airborne mass should be ~15-30 kg
        @test m > 10.0
        @test m < 50.0
    end

    # === Test 2: Expansion rotors add their mass ===
    @testset "expansion rotors add mass" begin
        p = params_10kw()
        cfg = ExpansionStackConfig(
            placement=:clustered,
            n_rings=16,
            n_expansion=3,
            blade_radius=0.8,
            hub_radius=0.15,
            blade_chord=0.06,
            CL_blade=1.0,
            CD0_blade=0.02,
            k_induced=0.05,
            bridle_angle_deg=15.0,
            mass_per_rotor=0.5,
            shaft_coupling=1.0,
        )
        stack = build_expansion_stack(cfg)
        sys_exp, _ = build_kite_turbine_system(p; expansion_rotors=stack)
        sys_base, _ = build_kite_turbine_system(p)

        m_exp = expansion_airborne_mass(sys_exp, p)
        m_base = expansion_airborne_mass(sys_base, p)

        # 3 expansion rotors × 0.5 kg each = 1.5 kg extra
        @test m_exp - m_base ≈ 1.5 atol=0.1
    end

    # === Test 3: φ computation (mass/power ratio) ===
    @testset "phi (mass/power ratio)" begin
        p = params_10kw()
        sys, _ = build_kite_turbine_system(p)

        # Without simulation, use rated power as estimate
        phi_nominal = expansion_phi(sys, p, 10000.0)
        @test phi_nominal > 0.0
        # For 10 kW, φ should be ~1.0-2.0 kg/kW
        @test phi_nominal > 0.5
        @test phi_nominal < 3.0

        # Double power → roughly same mass → φ ~halves
        phi_20kw = expansion_phi(sys, p, 20000.0)
        @test phi_20kw < phi_nominal
    end

    # === Test 4: Effective radius summary ===
    @testset "effective radius summary" begin
        p = params_10kw()
        sys, _ = build_kite_turbine_system(p)

        summary = expansion_radius_summary(sys)
        @test length(summary) == sys.n_ring
        # All radii should equal nominal (no expansion rotors)
        for i in 1:sys.n_ring
            node = sys.nodes[sys.ring_ids[i]]::RingNode
            @test summary[i] ≈ node.radius
        end
    end

    # === Test 5: Telemetry record structure ===
    @testset "telemetry record" begin
        p = params_10kw()
        cfg = ExpansionStackConfig(
            placement=:clustered,
            n_rings=16,
            n_expansion=2,
            blade_radius=0.8,
            hub_radius=0.15,
            blade_chord=0.06,
            CL_blade=1.0,
            CD0_blade=0.02,
            k_induced=0.05,
            bridle_angle_deg=15.0,
            mass_per_rotor=0.5,
            shaft_coupling=1.0,
        )
        stack = build_expansion_stack(cfg)
        sys, _ = build_kite_turbine_system(p; expansion_rotors=stack)

        record = expansion_telemetry(sys, p, 9500.0, 11.0)
        @test record isa NamedTuple
        @test haskey(record, :n_expansion)
        @test haskey(record, :mass_airborne_kg)
        @test haskey(record, :phi_kg_per_kw)
        @test haskey(record, :power_w)
        @test haskey(record, :placement)
        @test haskey(record, :mean_radius_spread_m)
        @test record.n_expansion == 2
        @test record.placement == "clustered"
    end

    # === Test 6: φ improvement quantifies expansion benefit ===
    @testset "phi improvement" begin
        p = params_10kw()
        sys_base, _ = build_kite_turbine_system(p)

        cfg = ExpansionStackConfig(
            placement=:clustered,
            n_rings=16,
            n_expansion=4,
            blade_radius=0.8,
            hub_radius=0.15,
            blade_chord=0.06,
            CL_blade=1.0,
            CD0_blade=0.02,
            k_induced=0.05,
            bridle_angle_deg=15.0,
            mass_per_rotor=0.5,
            shaft_coupling=1.0,
        )
        stack = build_expansion_stack(cfg)
        sys_exp, _ = build_kite_turbine_system(p; expansion_rotors=stack)

        # Without a full sim, compare structural mass (tether mass scales with radius)
        # Nominal φ and expansion φ differ by the added expansion rotor mass
        # (actual benefit comes from reduced tether sizing, which requires
        # the full structural optimisation to quantify)
        phi_base = expansion_phi(sys_base, p, 10000.0)
        phi_exp = expansion_phi(sys_exp, p, 10000.0)

        # Expansion rotors add mass → φ temporarily worse
        # (improvement comes from the structural re-optimisation,
        # not from the raw mass addition)
        @test phi_exp > phi_base  # more mass, same power → worse φ until optimised
    end
end
