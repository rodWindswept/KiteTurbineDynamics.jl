# test/test_ring_spacing_v4.jl
# TDD tests for v4 ring spacing — constant L/r formulation.
#
# Physics being tested:
#   ring_spacing_v4 places polygon frames so every segment has L/r ≈ target_Lr.
#   This is equivalent to a geometric series in ring radii. With Do ∝ r^0.5,
#   Euler buckling capacity is then uniform across all rings, enabling meaningful
#   taper without structural penalty at the thin bottom segments.

using Test
using KiteTurbineDynamics

# ─── 1. Constant L/r property ────────────────────────────────────────────────
@testset "ring_spacing_v4 — constant L/r" begin
    r_top = 2.0; r_bot = 0.5; L = 30.0; c = 1.2
    zs, rs, n_int = ring_spacing_v4(r_top, r_bot, L, c)
    n_segs = length(zs) - 1
    @test n_segs >= 1

    # L/r_mid for each segment — should all equal actual_Lr (which ≈ target_Lr)
    Lr_vals = [
        (zs[i+1] - zs[i]) / ((rs[i] + rs[i+1]) / 2.0)
        for i in 1:n_segs
    ]
    actual_Lr = mean(Lr_vals)
    # All segments have the same L/r (geometric series property — tight tolerance)
    @test all(abs.(Lr_vals .- actual_Lr) / actual_Lr .< 0.001)
    # The common L/r is close to target_Lr (bounded by integer rounding of n_segs)
    @test abs(actual_Lr - c) / c < 0.02
end

# ─── 2. Monotonicity ─────────────────────────────────────────────────────────
@testset "ring_spacing_v4 — monotonicity" begin
    zs, rs, _ = ring_spacing_v4(2.0, 0.6, 30.0, 1.0)
    @test all(diff(zs) .> 0.0)   # z strictly increasing (ground → hub)
    @test all(diff(rs) .> 0.0)   # r strictly increasing (ground → hub)
end

# ─── 3. Boundary conditions ──────────────────────────────────────────────────
@testset "ring_spacing_v4 — boundary conditions" begin
    r_top = 2.0; r_bot = 0.7; L = 30.0
    zs, rs, n_int = ring_spacing_v4(r_top, r_bot, L, 0.8)
    @test zs[1]   ≈ 0.0    atol=1e-10
    @test zs[end] ≈ L      atol=1e-10
    @test rs[1]   ≈ r_bot  atol=1e-10
    @test rs[end] ≈ r_top  atol=1e-10
    # n_int is intermediate rings: total = n_int + 2
    @test length(zs) == n_int + 2
    @test length(rs) == n_int + 2
end

# ─── 4. Ground ring deployment constraint ────────────────────────────────────
@testset "TRPTDesignV4 — ground ring constraint enforced in evaluate_design" begin
    p = params_10kw()
    # r_bottom at exactly the limit → feasibility must not be blocked by constraint
    d_ok = TRPTDesignV4(PROFILE_CIRCULAR, 0.040, 0.05, 1.0, 0.5,
                         p.trpt_hub_radius, OPT_MAX_GROUND_RADIUS, 1.0,
                         p.tether_length, p.n_lines, OPT_KNUCKLE_MASS_KG)
    r_ok = evaluate_design(d_ok; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)
    # Constraint itself should not fire — only structural FoS decides feasibility
    @test r_ok.constraint_msg != "r_bottom exceeds max_ground_radius"

    # r_bottom above the limit → explicitly infeasible from deployment constraint
    d_big = TRPTDesignV4(PROFILE_CIRCULAR, 0.040, 0.05, 1.0, 0.5,
                          p.trpt_hub_radius, OPT_MAX_GROUND_RADIUS + 0.1, 1.0,
                          p.tether_length, p.n_lines, OPT_KNUCKLE_MASS_KG)
    r_big = evaluate_design(d_big; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)
    @test !r_big.feasible
    @test r_big.constraint_msg == "r_bottom exceeds max_ground_radius"
end

# ─── 5. Torsional FoS consistency ────────────────────────────────────────────
@testset "TRPTDesignV4 — torsional FoS uniformity across rings" begin
    # With constant L/r and Do ∝ r^0.5 (Do_scale_exp=0.5):
    # P_crit ∝ r² / L² = r² / (target_Lr × r_mid)² ≈ const → FoS uniform.
    p = params_10kw()
    d = TRPTDesignV4(PROFILE_CIRCULAR, 0.040, 0.05, 1.0, 0.5,
                      p.trpt_hub_radius, 0.6, 1.0,
                      p.tether_length, p.n_lines, OPT_KNUCKLE_MASS_KG)
    r = evaluate_design(d; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)
    finite_fos = filter(isfinite, r.fos_per_ring)
    @test length(finite_fos) >= 2
    fos_spread = (maximum(finite_fos) - minimum(finite_fos)) / mean(finite_fos)
    @test fos_spread < 0.10   # within 10% coefficient of variation
end

# ─── 6. Buckling FoS consistency (same physics, explicit check) ───────────────
@testset "TRPTDesignV4 — buckling FoS uniformity: v4 < v2 spread" begin
    # v4 with constant L/r should have more uniform FoS than v2 with uniform spacing
    # (same r_hub, r_bottom, beam sizing, n_lines).
    p = params_10kw()
    r_bot = 0.6

    d_v4 = TRPTDesignV4(PROFILE_CIRCULAR, 0.040, 0.05, 1.0, 0.5,
                         p.trpt_hub_radius, r_bot, 1.0,
                         p.tether_length, p.n_lines, OPT_KNUCKLE_MASS_KG)

    # Equivalent v2 with same boundary radii and uniform spacing
    taper_ratio = r_bot / p.trpt_hub_radius
    d_v2 = TRPTDesignV2(PROFILE_CIRCULAR, 0.040, 0.05, 1.0, 0.5,
                         AXIAL_LINEAR, 1.0, 0.0,
                         p.trpt_hub_radius, taper_ratio,
                         14, p.tether_length,
                         p.n_lines, OPT_KNUCKLE_MASS_KG)

    r4 = evaluate_design(d_v4; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)
    r2 = evaluate_design(d_v2; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)

    fos4 = filter(isfinite, r4.fos_per_ring)
    fos2 = filter(isfinite, r2.fos_per_ring)

    spread4 = (maximum(fos4) - minimum(fos4)) / mean(fos4)
    spread2 = (maximum(fos2) - minimum(fos2)) / mean(fos2)

    # Constant L/r must give strictly more uniform FoS than uniform spacing
    @test spread4 < spread2
end

# ─── 7a. Degenerate: cylindrical (taper_ratio = 1.0) → uniform spacing ───────
@testset "ring_spacing_v4 — cylindrical gives uniform spacing" begin
    r = 2.0; L = 30.0; c = 1.5
    zs, rs, n_int = ring_spacing_v4(r, r, L, c)  # r_top == r_bottom

    # All radii equal
    @test all(rs .≈ r)
    # z positions uniformly spaced
    dz = diff(zs)
    @test all(abs.(dz .- dz[1]) .< 1e-9)
    # L/r ≈ target_Lr
    @test abs(dz[1] / r - c) / c < 0.02
end

# ─── 7b. Degenerate: very small max_rings → minimal ring count ────────────────
@testset "ring_spacing_v4 — max_rings=1 gives two-ring (single-segment) result" begin
    zs, rs, n_int = ring_spacing_v4(2.0, 0.5, 30.0, 1.0; max_rings=1)
    # max_rings=1 intermediate ← 2 segments → but single segment is max_rings=0.
    # With max_rings=1, n_segs ≤ 2. Verify we get ≥ 2 total rings and it doesn't crash.
    @test length(zs) >= 2
    @test zs[1]   ≈ 0.0  atol=1e-10
    @test zs[end] ≈ 30.0 atol=1e-10
    @test rs[1]   ≈ 0.5  atol=1e-10
    @test rs[end] ≈ 2.0  atol=1e-10
end

# ─── 8. Search bounds + design_from_vector round-trip ────────────────────────
@testset "TRPTDesignV4 — search bounds and design_from_vector_v4" begin
    p = params_10kw()
    lo, hi = search_bounds_v4(p, PROFILE_CIRCULAR)
    @test length(lo) == TRPT_V4_DIM
    @test length(hi) == TRPT_V4_DIM
    @test all(hi .>= lo)

    # Midpoint vector → valid design
    x = (lo .+ hi) ./ 2.0
    d = design_from_vector_v4(x, PROFILE_CIRCULAR, p)
    @test d.r_bottom >= lo[6]
    @test d.r_bottom <= hi[6]
    @test d.target_Lr >= lo[7]
    @test d.target_Lr <= hi[7]
    @test d.n_lines in 3:8

    # objective_v4 returns a finite value for the midpoint
    f = objective_v4(x, PROFILE_CIRCULAR, p;
                     rotor_radius=p.rotor_radius, elev_angle=p.elevation_angle)
    @test isfinite(f)
end

# ─── 9. Mass and knuckle accounting ──────────────────────────────────────────
@testset "TRPTDesignV4 — mass accounting" begin
    p = params_10kw()
    d = TRPTDesignV4(PROFILE_CIRCULAR, 0.040, 0.05, 1.0, 0.5,
                      p.trpt_hub_radius, 0.7, 1.0,
                      p.tether_length, p.n_lines, OPT_KNUCKLE_MASS_KG)
    r = evaluate_design(d; r_rotor=p.rotor_radius, elev_angle=p.elevation_angle)
    @test r.mass_total_kg > 0
    @test r.mass_beams_kg > 0
    zs, rs, n_int = ring_spacing_v4(d.r_hub, d.r_bottom, d.tether_length, d.target_Lr)
    n_rings_total = length(rs)
    expected_knuckles = d.knuckle_mass_kg * d.n_lines * n_rings_total
    @test r.mass_knuckles_kg ≈ expected_knuckles atol=1e-9
end
