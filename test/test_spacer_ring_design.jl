# test/test_spacer_ring_design.jl
using Test
using KiteTurbineDynamics

@testset "Spacer Ring Structural Design Module" begin
    # ── Test 1: Material and Preset Constructors ─────────────────────────────
    @testset "Material and presets" begin
        @test DEFAULT_CFRP.E == 70e9
        @test DEFAULT_CFRP.G == 5e9
        @test DEFAULT_CFRP.density == 1600.0
        @test DEFAULT_CFRP.σ_yield == 600e6

        # Standard shortcuts
        circ_tube = CircularTube(0.04, 0.05)
        @test circ_tube.profile.Do == 0.04
        @test circ_tube.profile.t_over_D == 0.05
        @test circ_tube.material === DEFAULT_CFRP
    end

    # ── Test 2: Circular Profile Calculations ───────────────────────────────
    @testset "Circular Strut Calculations" begin
        # 40 mm tube, t/D = 0.05 (wall = 2 mm)
        circ_tube = CircularTube(0.04, 0.05)
        L = 2.0

        # Test strut properties for Pin-Pin Ends (K = 1.0)
        props_pin = strut_properties(circ_tube, L, PinPinEnds())

        # Analytical verify
        Do = 0.04
        t = 0.05 * Do
        Di = Do - 2.0 * t
        A_calc = (π / 4.0) * (Do^2 - Di^2)
        I_calc = (π / 64.0) * (Do^4 - Di^4)
        J_calc = 2.0 * I_calc
        P_crit_calc = (π^2 * 70e9 * I_calc) / (1.0 * L)^2
        M_el_calc = (600e6 * I_calc) / (Do / 2.0)

        @test props_pin.A ≈ A_calc
        @test props_pin.I_min ≈ I_calc
        @test props_pin.J ≈ J_calc
        @test props_pin.mass ≈ A_calc * 1600.0
        @test props_pin.P_crit ≈ P_crit_calc
        @test props_pin.M_el ≈ M_el_calc

        # Test strut properties for Fixed-Fixed Ends (K = 0.5)
        props_fixed = strut_properties(circ_tube, L, FixedFixedEnds())
        @test props_fixed.P_crit ≈ P_crit_calc * 4.0  # Buckling load is 4x under K=0.5
    end

    # ── Test 3: Elliptical Profile Calculations ─────────────────────────────
    @testset "Elliptical Strut Calculations" begin
        ell_tube = EllipticalTube(0.06, 0.05, 0.5)  # Major=60mm, aspect=0.5, minor=30mm
        L = 1.5
        props = strut_properties(ell_tube, L, PinPinEnds())

        # Area calculation verify
        Do = 0.06
        t = 0.05 * Do
        a = Do / 2.0
        b = 0.5 * a
        ai = a - t
        bi = b - t
        A_calc = π * (a * b - ai * bi)

        @test props.A ≈ A_calc
        @test props.I_min > 0.0
        @test props.J > 0.0
        @test props.mass ≈ A_calc * 1600.0
    end

    # ── Test 4: Airfoil Profile Calculations ────────────────────────────────
    @testset "Airfoil Strut Calculations" begin
        air_tube = AirfoilTube(0.10, 0.02, 0.12)  # Chord=100mm, wall=2mm, thickness ratio=0.12
        L = 2.0
        props = strut_properties(air_tube, L, FixedFixedEnds())

        @test props.A > 0.0
        @test props.I_min > 0.0
        @test props.J > 0.0
        @test props.P_crit > 0.0
    end

    # ── Test 5: Stress Utilisation ──────────────────────────────────────────
    @testset "Utilisation & Buckling safety margins" begin
        tube = CircularTube(0.03, 0.05)
        L = 1.0
        props = strut_properties(tube, L, PinPinEnds())

        # Test pure tension (N < 0) - should be clamped to 0.0, utilisation based only on bending
        N_tension = -100.0
        M_ip = 5.0
        M_oop = 0.0
        util_tens = utilisation(tube, props, N_tension, M_ip, M_oop)
        util_zero_N = utilisation(tube, props, 0.0, M_ip, M_oop)
        @test util_tens == util_zero_N
        @test util_tens ≈ M_ip / props.M_el

        # Test pure compression (N > 0)
        N_comp = 200.0
        util_comp = utilisation(tube, props, N_comp, 0.0, 0.0)
        @test util_comp ≈ N_comp / props.P_crit

        # Test combined biaxial bending and compression
        util_combined = utilisation(tube, props, N_comp, 3.0, 4.0)
        M_mag = 5.0  # sqrt(3^2 + 4^2)
        @test util_combined ≈ (N_comp / props.P_crit) + (M_mag / props.M_el)
    end

    # ── Test 6: Legacy backward-compat adapter ──────────────────────────────
    @testset "Legacy adapter compatibility" begin
        # Call legacy tube_props
        tp = tube_props(2.0)
        @test tp.Do > 0.0
        @test tp.t > 0.0
        @test tp.Di ≈ tp.Do - 2.0 * tp.t
        @test tp.A > 0.0
        @test tp.I_bend > 0.0
        @test tp.J > 0.0

        # Custom properties packed in NamedTuple
        @test tp.E == 70e9
        @test tp.G == 5e9
        @test tp.σ_yield == 600e6
    end
end
