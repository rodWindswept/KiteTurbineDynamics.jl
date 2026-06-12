@testset "expansion rotor — analytical mechanics" begin

    # === Test 1: Zero-wind spreading via ω² ===
    # When v_wind=0, blades still generate lift from rotational apparent wind,
    # producing radial force that spreads the ring.
    @testset "zero-wind spreading via ω²" begin
        er = ExpansionRotorParams(3, 0.5, 0.1, 0.05, 1.0, 0.02, 0.05, 15.0, 0.5, 3, 1.0)
        rho = 1.225
        v_wind = 0.0
        omega = 30.0            # rad/s — spinning at ~286 rpm
        elev = 20.0
        r_nom = 1.0
        T_tether = 500.0          # N — tether tension
        n_lines = 5

        F_radial, F_axial, tau_drag, r_eff, omega_rotor = expansion_rotor_forces(
            er, rho, v_wind, omega, elev, r_nom, T_tether, n_lines
        )

        # With zero wind, v_app comes entirely from ω·r_mean:
        # r_mean = (0.5+0.1)/2 = 0.3 m, v_app = 30*0.3 = 9 m/s
        # q = 0.5*1.225*9² ≈ 49.6
        # L_blade = 49.6 * 0.05 * 0.4 * 1.0 ≈ 0.99 N per blade
        # F_radial = 3 * 0.99 * sin(15°) ≈ 3 * 0.99 * 0.259 ≈ 0.77 N
        # Δr ≈ 0.77 * 2.0 / (500 * 2*tan(36°)) ≈ 0.77*2/(500*1.453) ≈ 0.0021 m
        @test F_radial > 0.0
        @test F_axial > 0.0
        @test tau_drag > 0.0
        @test r_eff > r_nom
        @test omega_rotor == omega
    end

    # === Test 2: Zero bridle angle → no radial force ===
    @testset "zero bridle angle → no radial force" begin
        er = ExpansionRotorParams(
            3,
            0.5,
            0.1,
            0.05,
            1.0,
            0.02,
            0.05,
            0.0,  # bridle at 0° — pure axial
            0.5,
            3,
            1.0,
        )
        F_radial, F_axial, _, _, _ = expansion_rotor_forces(
            er, 1.225, 10.0, 30.0, 20.0, 1.0, 500.0, 5
        )

        @test F_radial ≈ 0.0 atol=1e-12
        @test F_axial > 0.0
    end

    # === Test 3: Force scales with v_app² ===
    @testset "force scales with v_app²" begin
        er = ExpansionRotorParams(3, 0.5, 0.1, 0.05, 1.0, 0.02, 0.05, 10.0, 0.5, 3, 1.0)

        # Double wind speed → v_app roughly doubles → forces ~4×
        F1, _, _, _, _ = expansion_rotor_forces(er, 1.225, 5.0, 30.0, 20.0, 1.0, 500.0, 5)
        F2, _, _, _, _ = expansion_rotor_forces(er, 1.225, 20.0, 30.0, 20.0, 1.0, 500.0, 5)

        # v_app(5 m/s, 30 rad/s, r=0.3) ≈ sqrt(5² + 9²) = 10.3
        # v_app(20 m/s, 30 rad/s, r=0.3) ≈ sqrt(20² + 9²) = 21.9
        # ratio v_app² ≈ (21.9/10.3)² ≈ 4.5
        @test F2 > F1 * 3.0    # expect at least 3× (conservative bound)
        @test F2 < F1 * 6.0    # not more than 6×
    end

    # === Test 4: Steeper bridle → more radial force fraction ===
    @testset "steeper bridle → more radial force" begin
        er_flat = ExpansionRotorParams(3, 0.5, 0.1, 0.05, 1.0, 0.02, 0.05, 5.0, 0.5, 3, 1.0)
        er_steep = ExpansionRotorParams(
            3, 0.5, 0.1, 0.05, 1.0, 0.02, 0.05, 40.0, 0.5, 3, 1.0
        )

        Fr_flat, Fa_flat, _, _, _ = expansion_rotor_forces(
            er_flat, 1.225, 10.0, 30.0, 20.0, 1.0, 500.0, 5
        )
        Fr_steep, Fa_steep, _, _, _ = expansion_rotor_forces(
            er_steep, 1.225, 10.0, 30.0, 20.0, 1.0, 500.0, 5
        )

        # Same lift, but steeper bridle → more radial, less axial
        @test Fr_steep > Fr_flat
        @test Fa_steep < Fa_flat
    end

    # === Test 5: Effective radius computation ===
    @testset "effective radius" begin
        # With known F_radial and T_tether, radius should increase predictably
        n_lines = 5
        geometry_factor = 2.0 * tan(π / n_lines)
        # For r_nom=1.0, approximate L_seg ≈ 2*r_nom = 2.0
        L_seg_est = 2.0    # m
        F_radial = 100.0   # N
        T_tether = 1000.0  # N

        r_eff = effective_radius(1.0, F_radial, T_tether, L_seg_est, geometry_factor)
        expected_Δr = F_radial * L_seg_est / (T_tether * geometry_factor)
        @test r_eff ≈ 1.0 + expected_Δr

        # Double the radial force → double the spread
        r_eff2 = effective_radius(1.0, 2*F_radial, T_tether, L_seg_est, geometry_factor)
        @test r_eff2 - 1.0 ≈ 2 * (r_eff - 1.0) atol=1e-10
    end

    # === Test 6: No force → no spread ===
    @testset "no force → no spread" begin
        n_lines = 5
        gf = 2.0 * tan(π / n_lines)

        # Zero radial force
        @test effective_radius(1.0, 0.0, 500.0, 2.0, gf) == 1.0
        # Negative radial force (shouldn't happen, but guard)
        @test effective_radius(1.0, -100.0, 500.0, 2.0, gf) == 1.0
        # Zero tether tension
        @test effective_radius(1.0, 100.0, 0.0, 2.0, gf) == 1.0
    end
end
