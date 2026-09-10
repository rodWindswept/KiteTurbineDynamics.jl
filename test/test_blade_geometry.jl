#!/usr/bin/env julia
# test/test_blade_geometry.jl
# Assertion: expansion rotor blades use the ring-anchored 70/30 split
# (2026-08-20, Rod): blade_tip = +0.7·span (outboard offset, positive),
# blade_hub = −0.3·span (inboard offset, NEGATIVE), matching
# objective_v10.jl and expansion_rotor.jl (expansion_annulus_area).
#
# Run: julia --project=. test/test_blade_geometry.jl

using Test
using KiteTurbineDynamics

@testset "Blade geometry — ring-anchored 70/30 split" begin

    # ═══ Test 1: builders_util.jl — V10 Tight (blade_scale=1.0) ═══
    @testset "V10 Tight λ=1.0" begin
        include(joinpath(@__DIR__, "..", "scripts", "builders_util.jl"))
        sys, u0, p, label, _ = Base.invokelatest(
            build_v10_tight_no_lowest; blade_scale=1.0)

        @test !isempty(sys.expansion_rotors)
        for (i, er) in enumerate(sys.expansion_rotors)
            @test er.blade_tip_radius > 0        # outboard offset
            @test er.blade_hub_radius < 0        # inboard offset (negative)
            span = er.blade_tip_radius - er.blade_hub_radius
            @test span > 0
            @test er.blade_tip_radius ≈ (0.7 / 0.3) * (-er.blade_hub_radius) atol=1e-9
        end
    end

    # ═══ Test 2: V10 Tight λ=0.69 (blade-scaled) ═══
    @testset "V10 Tight λ=0.69" begin
        sys, u0, p, label, _ = Base.invokelatest(
            build_v10_tight_no_lowest; blade_scale=0.69)

        for (i, er) in enumerate(sys.expansion_rotors)
            @test er.blade_tip_radius > 0
            @test er.blade_hub_radius < 0
            @test er.blade_tip_radius ≈ (0.7 / 0.3) * (-er.blade_hub_radius) atol=1e-9
        end
    end

    # ═══ Test 3: V10 Reinforced ═══
    @testset "V10 Reinforced" begin
        sys, u0, p, label, _ = Base.invokelatest(
            build_v10_tight_no_lowest; r_bottom_scale=1.30, tether_diameter=0.004, blade_scale=1.0)

        for (i, er) in enumerate(sys.expansion_rotors)
            @test er.blade_tip_radius > 0
            @test er.blade_hub_radius < 0
            @test er.blade_tip_radius ≈ (0.7 / 0.3) * (-er.blade_hub_radius) atol=1e-9
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

    # ═══ Test 5: LIVE DECODE — design_from_vector_v10 (audit 2026-09-08) ═══
    # Tests 1-3 above build the DEAD `build_v10_tight*` path.  A 70/30
    # regression introduced inside the live decode would leave them green.
    # This testset pins the split on the decode the v13 evaluator and gate
    # actually call (src/objective_v10.jl:269-284), with the campaign knobs.
    @testset "live decode — design_from_vector_v10 70/30" begin
        x = [0.06, 0.01, 1.0, 1.0, 2.775, 0.575, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]
        p2 = params_daisy()
        geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
            18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
        mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
        aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
        ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max,
            p2.β_rate_max, p2.kp_elev)
        back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x,
            p2.backline_payout)
        p = override_params(
            mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
            tether_length=18.8)

        dec = design_from_vector_v10(x, PROFILE_ELLIPTICAL, p; power_W=5000.0,
            cylinder_cone=true, rotor_count_mode=true,
            power_split=0.6, cone_slope_deg=22.0,
            rotor_spacing_frac=0.8, blocking_factor=1.0)

        @test !isempty(dec.rotors)
        for er in dec.rotors
            span = er.blade_tip_radius - er.blade_hub_radius
            @test span > 0
            @test er.blade_tip_radius > 0          # outboard offset (+)
            @test er.blade_hub_radius < 0          # inboard offset (−)
            @test er.blade_tip_radius ≈ 0.7 * span atol=1e-12
            @test er.blade_hub_radius ≈ -0.3 * span atol=1e-12
            @test er.blade_tip_radius ≈ (0.7 / 0.3) * (-er.blade_hub_radius) atol=1e-12
            # Span magnitude preserved: span = 0.75·r_rotor·blade_scale.
            @test span ≈ 0.75 * er.r_rotor * er.blade_scale atol=1e-9
        end
    end

end  # @testset

println("\n✓ All blade geometry assertions passed — 70/30 split verified.")
