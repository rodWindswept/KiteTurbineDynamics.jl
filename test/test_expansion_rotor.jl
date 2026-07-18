@testset "expansion rotor — analytical mechanics" begin

    # LEGACY PHYSICS PIN (2026-07-18): these analytical tests document the
    # fixed-CL legacy model (e.g. zero-wind spreading assumes CL=1.0 at φ=0;
    # the α model correctly gives negative lift there). The induction model
    # has its own acceptance suite in test_expansion_induction.jl.
    _prev_induction = expansion_induction()
    set_expansion_induction!(false)

    # === Test 1: Zero-wind spreading via ω² ===
    # When v_wind=0, blades generate lift from rotational apparent wind,
    # producing radial force that spreads the ring.
    @testset "zero-wind spreading via ω²" begin
        # blade_span=1.0, chord=0.1, n_blades=3, CL=1.0, bank=15°
        er = ExpansionRotorParams(3, 1.0, 0.5, 0.1, 1.0, 0.02, 0.05, 15.0, 0.5, 3, 1.0)
        rho     = 1.225
        v_wind  = 0.0
        omega   = 30.0
        elev    = 20.0
        r_nom   = 1.0
        T_tether = 500.0
        n_lines = 5

        F_radial, F_axial, tau_net, r_eff, omega_rotor =
            expansion_rotor_forces(er, rho, v_wind, omega, elev, r_nom, T_tether, n_lines)

        # r_mean = r_nom + span*cos(15°)/2 = 1.0 + 1.0*0.966/2 = 1.483
        # v_app = 30 * 1.483 = 44.5 m/s
        # expect non-zero forces
        @test F_radial > 0.0
        @test F_axial  > 0.0
        # v_wind=0 → φ=0 → no tangential lift component; τ_net = -τ_drag < 0
        @test tau_net < 0.0
        @test r_eff > r_nom
        @test omega_rotor == omega
    end

    # === Test 2: Zero bank angle → no radial force ===
    @testset "zero bank angle → no radial force" begin
        er = ExpansionRotorParams(3, 1.0, 0.5, 0.1, 1.0, 0.02, 0.05,
                                   0.0,  # bank at 0° — pure axial (thrust only)
                                   0.5, 3, 1.0)
        F_radial, F_axial, _, _, _ =
            expansion_rotor_forces(er, 1.225, 10.0, 30.0, 20.0, 1.0, 500.0, 5)

        @test F_radial ≈ 0.0 atol=1e-12
        @test F_axial > 0.0   # pure thrust, no radial component
    end

    # === Test 3: Force scales with v_app² ===
    @testset "force scales with v_app²" begin
        er = ExpansionRotorParams(3, 1.0, 0.5, 0.1, 1.0, 0.02, 0.05, 20.0, 0.5, 3, 1.0)

        # Double wind speed → 4× lift (q ∝ v²), all else equal
        F1, _, _, _, _ = expansion_rotor_forces(er, 1.225, 5.0, 10.0, 20.0, 1.0, 500.0, 5)
        F2, _, _, _, _ = expansion_rotor_forces(er, 1.225, 10.0, 10.0, 20.0, 1.0, 500.0, 5)

        # Not exactly 4× because v_app = sqrt(v_wind² + (ωr)²)
        # With large r_mean, rotational component dominates — ratio close to 1
        # Use smaller r_nom to make wind component dominant
        ratio = F2 / F1
        @test ratio > 1.1
        @test ratio < 2.0
    end

    # === Test 4: Steeper bank → more radial force ===
    @testset "steeper bank → more radial force" begin
        er15 = ExpansionRotorParams(3, 1.0, 0.5, 0.1, 1.0, 0.02, 0.05, 15.0, 0.5, 3, 1.0)
        er30 = ExpansionRotorParams(3, 1.0, 0.5, 0.1, 1.0, 0.02, 0.05, 30.0, 0.5, 3, 1.0)

        F15, _, _, _, _ = expansion_rotor_forces(er15, 1.225, 10.0, 10.0, 20.0, 1.0, 500.0, 5)
        F30, _, _, _, _ = expansion_rotor_forces(er30, 1.225, 10.0, 10.0, 20.0, 1.0, 500.0, 5)

        # sin(30°)/sin(15°) ≈ 2, but cos(bank) reduces r_mean slightly
        # so F_radial ratio should be approximately 1.8-2.0
        ratio = F30 / F15
        @test ratio > 1.6
        @test ratio < 2.2
    end

    # === Test 5: Larger ring → larger mean radius → more force ===
    @testset "force scales with ring radius" begin
        er = ExpansionRotorParams(3, 1.0, 0.5, 0.1, 1.0, 0.02, 0.05, 20.0, 0.5, 3, 1.0)

        F_small, _, _, _, _ = expansion_rotor_forces(er, 1.225, 10.0, 10.0, 20.0, 0.5, 500.0, 5)
        F_large, _, _, _, _ = expansion_rotor_forces(er, 1.225, 10.0, 10.0, 20.0, 2.0, 500.0, 5)

        @test F_large > F_small
    end

    # === Test 6: No expansion rotors = identity ===
    @testset "empty stack returns nominal radii" begin
        p = params_10kw()
        design = design_from_vector_v5(
            search_bounds_v5(p, PROFILE_CIRCULAR)[1], PROFILE_CIRCULAR, p
        )
        r_eff, F_radial, _, _ = estimate_effective_radii(
            design, ExpansionRotorParams[], p; v_wind=11.0, omega=9.5, elev_deg=20.0
        )
        @test length(r_eff) > 3
        @test all(F_radial .== 0.0)
    end

    set_expansion_induction!(_prev_induction)
end
