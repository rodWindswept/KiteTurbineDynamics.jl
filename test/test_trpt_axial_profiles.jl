# test/test_trpt_axial_profiles.jl
# Phase A of the Design Cartography programme: validate r(z) profile family
# and 12-DoF v2 design plumbing.

using Test
using KiteTurbineDynamics

@testset "TRPT axial profile family" begin
    r_bot, r_top, L = 0.96, 2.0, 30.0

    # Endpoint behaviour: every profile must hit (r_bot at z=0, r_top at z=L)
    for prof in (AXIAL_LINEAR, AXIAL_ELLIPTIC, AXIAL_PARABOLIC,
                 AXIAL_TRUMPET, AXIAL_STRAIGHT_TAPER)
        @test isapprox(r_of_z(prof, 1.5, 0.3, r_bot, r_top, L, 0.0),  r_bot; atol=1e-9)
        @test isapprox(r_of_z(prof, 1.5, 0.3, r_bot, r_top, L, L),    r_top; atol=1e-9)
    end

    # Linear: midpoint exactly midway
    @test isapprox(r_of_z(AXIAL_LINEAR, 1.0, 0.0, r_bot, r_top, L, L/2),
                   (r_bot + r_top)/2; atol=1e-9)

    # Elliptic (quarter-ellipse): midpoint > linear midpoint (concave-up)
    r_lin = r_of_z(AXIAL_LINEAR,   1.0, 0.0, r_bot, r_top, L, L/2)
    r_ell = r_of_z(AXIAL_ELLIPTIC, 1.0, 0.0, r_bot, r_top, L, L/2)
    @test r_ell > r_lin

    # Parabolic exp=2 (convex/up): midpoint < linear midpoint
    r_par = r_of_z(AXIAL_PARABOLIC, 2.0, 0.0, r_bot, r_top, L, L/2)
    @test r_par < r_lin

    # Trumpet exp=2: midpoint > linear midpoint (mirror of parabolic)
    r_trp = r_of_z(AXIAL_TRUMPET, 2.0, 0.0, r_bot, r_top, L, L/2)
    @test r_trp > r_lin

    # Straight-taper with straight_frac=0.5: r=r_bot for z < 15
    @test isapprox(r_of_z(AXIAL_STRAIGHT_TAPER, 1.0, 0.5, r_bot, r_top, L, 5.0),
                   r_bot; atol=1e-9)
    @test isapprox(r_of_z(AXIAL_STRAIGHT_TAPER, 1.0, 0.5, r_bot, r_top, L, 15.0),
                   r_bot; atol=1e-9)
    # half-way through the ramp portion (z = 22.5):
    @test r_of_z(AXIAL_STRAIGHT_TAPER, 1.0, 0.5, r_bot, r_top, L, 22.5) ≈
          (r_bot + r_top)/2  atol=1e-6
end

@testset "TRPT v2 design — geometry" begin
    p = params_10kw()
    d = baseline_design_v2(p)
    @test d.beam_profile == PROFILE_CIRCULAR
    @test d.axial_profile == AXIAL_LINEAR
    @test d.knuckle_mass_kg == OPT_KNUCKLE_MASS_KG

    radii = ring_radii(d)
    @test length(radii) == d.n_rings + 2
    @test radii[1]   ≈ d.r_hub * d.taper_ratio  atol=1e-9
    @test radii[end] ≈ d.r_hub                  atol=1e-9
    @test all(diff(radii) .>= -1e-9)            # monotonically non-decreasing

    zs = ring_z_positions(d)
    @test length(zs) == length(radii)
    @test zs[1]   ≈ 0.0
    @test zs[end] ≈ d.tether_length

    seg_L = segment_axial_lengths(d)
    @test length(seg_L) == d.n_rings + 1
    @test all(seg_L .≈ d.tether_length / (d.n_rings + 1))
end

@testset "TRPT v2 — evaluate_design" begin
    p = params_10kw()
    d = baseline_design_v2(p)
    r = evaluate_design(d; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)
    @test r.mass_total_kg > 0
    @test r.mass_beams_kg > 0
    @test r.mass_knuckles_kg ≈ d.knuckle_mass_kg * d.n_lines * (d.n_rings + 2)
    @test length(r.fos_per_ring) == d.n_rings + 2
end

@testset "TRPT v2 — search bounds + design_from_vector" begin
    p = params_10kw()
    lo, hi = search_bounds_v2(p, PROFILE_CIRCULAR)
    @test length(lo) == TRPT_V2_DIM
    @test length(hi) == TRPT_V2_DIM
    @test all(hi .>= lo)

    # Random vector inside bounds → valid design
    x = (lo .+ hi) ./ 2.0
    d = design_from_vector_v2(x, PROFILE_CIRCULAR, p)
    @test d.n_rings >= 3
    @test d.n_lines in 3:8
    @test d.knuckle_mass_kg >= lo[11] && d.knuckle_mass_kg <= hi[11]
    @test d.axial_profile in (AXIAL_LINEAR, AXIAL_ELLIPTIC, AXIAL_PARABOLIC,
                               AXIAL_TRUMPET, AXIAL_STRAIGHT_TAPER)

    # Objective returns finite mass for a midpoint vector
    f = objective_v2(x, PROFILE_CIRCULAR, p;
                      rotor_radius=p.rotor_radius, elev_angle=p.elevation_angle)
    @test isfinite(f)
end

@testset "TRPT v2 — n_lines decision variable affects polygon geometry" begin
    p = params_10kw()
    d_pent = TRPTDesignV2(PROFILE_CIRCULAR, 0.04, 0.05, 1.0, 0.5,
                          AXIAL_LINEAR, 1.0, 0.0,
                          1.8, 0.4, 14, 30.0, 5, 0.05)
    d_hex  = TRPTDesignV2(PROFILE_CIRCULAR, 0.04, 0.05, 1.0, 0.5,
                          AXIAL_LINEAR, 1.0, 0.0,
                          1.8, 0.4, 14, 30.0, 6, 0.05)
    r5 = evaluate_design(d_pent; r_rotor=5.0, elev_angle=π/6)
    r6 = evaluate_design(d_hex;  r_rotor=5.0, elev_angle=π/6)
    # Hexagon has shorter polygon segments → higher P_crit → higher FOS for same Do
    @test r6.min_fos > r5.min_fos
    # But more vertices → more knuckles → more mass
    @test r6.mass_knuckles_kg > r5.mass_knuckles_kg
end
