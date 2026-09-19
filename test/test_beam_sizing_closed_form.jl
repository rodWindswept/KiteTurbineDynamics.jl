# test/test_beam_sizing_closed_form.jl
# Static guards for the R7 closed-form beam-sizing authority (2026-09-10).
#
# R7 removes the four free beam genes (Do_top, t_over_D, beam_aspect,
# Do_scale_exp) and derives the tube from the rotor stack instead.  These are
# STATIC tests: they pin `solve_ring_Do` and `size_beams_closed_form` only.
# The ODE/FEA verification is exercised by the acceptance suite.
#
# Guards:
#  A. `solve_ring_Do` — floor at no compression, monotone in N, FoS achieved,
#     monotone in fos_req.
#  B. `size_beams_closed_form` — sizes every ring including the HUB ring (the
#     hidden weakest ring both legacy structural paths skipped), meets the Euler
#     FoS floor, and the corrected ground-first load build accumulates line
#     tension downward (each rotor's thrust lands on its own ring; the legacy
#     `gi = ri + 1` off-by-one shifted it one ring toward the hub).
#  C. The kink + helix load model.  Guard C pins the closed form's OWN
#     structure (a flat helix term on a constant-tension cylinder gives equal N
#     per ring).  It is NOT a reproduction of the settled-ODE load structure:
#     measured 2026-09-16, the FEA's ring axial force DECAYS roughly linearly
#     along the cylinder (N·den/T_line 1.186 -> 0.866 over rings 2-8), because
#     the axial force accumulates downward.  The equality in the testset below
#     remains a true property of the model; the model is a conservative
#     ENVELOPE of the ODE.  See scratch/diag_helix_calibration.jl.

using Test, KiteTurbineDynamics

# Daisy 1.5 kW → 5 kW at 18.8 m (mirrors run_v13_5kw_masslift.jl).
function params_5kw_188()
    p2 = params_daisy()
    geo = GeometrySpec(p2.elevation_angle, p2.lifter_elevation, p2.rotor_radius,
        18.8, p2.trpt_hub_radius, p2.trpt_rL_ratio, p2.n_lines, p2.n_rings, p2.n_blades)
    mat = MaterialSpec(p2.tether_diameter, p2.e_modulus, p2.m_ring, p2.m_blade)
    aero = AeroSpec(p2.rho, p2.v_wind_ref, p2.h_ref, p2.cp)
    ctrl = ControlSpec(p2.i_pto, p2.k_mppt, p2.p_rated_w, p2.β_min, p2.β_max, p2.β_rate_max, p2.kp_elev)
    back = BackLineSpec(p2.EA_back_line, p2.c_back_line, p2.back_anchor_fwd_x, p2.backline_payout)
    return override_params(mass_scale(SystemParams(geo, mat, aero, ctrl, back), 1.5, 5.0);
                           tether_length=18.8)
end

function decode_seed(; rotor_count=3.0)
    x = [0.08, 0.055, 1.0, 1.0,        # beam genes (inert on this path)
        2.4, 0.5751, 2.0, 6.0, 0.0,    # r_hub, r_bottom, target_Lr, n_lines, density
        rotor_count, 0.0, 0.0, 0.7, 0.7]
    return KiteTurbineDynamics.design_from_vector_v10(
        x, PROFILE_ELLIPTICAL, params_5kw_188(); power_W=5000.0,
        cylinder_cone=true, rotor_count_mode=true,
        power_split=0.6, cone_slope_deg=22.0,
        rotor_spacing_frac=0.8, blocking_factor=0.75^(1 / 3))
end

function cfg_5kw(; min_wall_m=2e-3, fos_hard=2.5)
    return ObjectiveConfig(; power_W=5000.0, v_rated=11.0, p_floor_kw=5.0,
                           fos_target=2.5, fos_hard=fos_hard, min_wall_m=min_wall_m,
                           t_over_D=0.055)
end

@testset "helix load factor is the re-measured envelope (corrected 2026-09-16)" begin
    # R7 replaced the legacy `OPT_DESIGN_LOAD_FACTOR` envelope (1.2) with a
    # "measured" 0.32.  That calibration was STALE: it was taken on the
    # pre-re-seed machine (L/r 2.0, 8 rings) and, per the sizing-margin probe
    # header, without the full matched twist.  On the current re-seeded machine
    # (L/r 1.5, 13 rings, matched twist) the FEA reads N_comp / T_line = 1.186 at
    # the bottom of the transmission cylinder, so 0.32 under-sized every
    # cylinder ring by up to 3.7x.  The envelope is restored.
    # See scratch/diag_helix_calibration.jl.
    @test HELIX_LOAD_FACTOR ≈ OPT_DESIGN_LOAD_FACTOR atol=1e-12
    @test HELIX_LOAD_FACTOR > 0.32        # the stale value is retracted
end

@testset "manufacturability floor on the ring tube Do" begin
    # Without this floor the solve returns ~5.5 mm for a lightly compressed
    # cylinder ring, where a 2 mm wall is t/D ≈ 0.36 — a wire.  The wall clamp,
    # not `fos_req`, then set every section, which made SIZING_FOS_MARGIN inert.
    @test MIN_RING_DO_M ≈ 0.010 atol=1e-12
    s_floor = size_beams_closed_form(decode_seed(), params_5kw_188(), cfg_5kw())
    @test all(>=(MIN_RING_DO_M - 1e-12), s_floor.Do_per_ring)
    # 10 mm on the pinned wall ratio is a real tube, not a solid wire.
    @test all(i -> tube_wall_thickness(s_floor.Do_per_ring[i], s_floor.t_over_D) /
                   s_floor.Do_per_ring[i] < 0.25, eachindex(s_floor.Do_per_ring))
end

@testset "solve_ring_Do — floor, monotonicity, FoS, fos_req" begin
    L = 1.0
    t_over_D = 0.055
    fos_req = 2.5

    # No compression → manufacturable floor (1 mm), never zero/negative.
    @test solve_ring_Do(0.0, L, t_over_D; fos_req=fos_req) == 1e-3
    @test solve_ring_Do(-5.0, L, t_over_D; fos_req=fos_req) == 1e-3

    # Monotone in N_comp.
    d1 = solve_ring_Do(10.0, L, t_over_D; fos_req=fos_req)
    d2 = solve_ring_Do(100.0, L, t_over_D; fos_req=fos_req)
    d3 = solve_ring_Do(1000.0, L, t_over_D; fos_req=fos_req)
    @test d1 < d2 < d3

    # The solved Do actually meets the FoS (single wall authority + ends).
    for N in (10.0, 100.0, 1000.0)
        Do = solve_ring_Do(N, L, t_over_D; fos_req=fos_req)
        t_eff = tube_wall_thickness(Do, t_over_D) / Do
        P_crit = strut_properties(CircularTube(Do, t_eff), L, FixedFixedEnds()).P_crit
        @test P_crit >= fos_req * N
    end

    # Monotone in fos_req.
    @test solve_ring_Do(100.0, L, t_over_D; fos_req=1.0) <
          solve_ring_Do(100.0, L, t_over_D; fos_req=5.0)

    # A thinner wall floor is weaker per unit diameter, so it needs a LARGER Do
    # to reach the same buckling capacity (the wall floor binds at this scale).
    @test solve_ring_Do(100.0, L, t_over_D; fos_req=fos_req, min_wall_m=1e-3) >=
          solve_ring_Do(100.0, L, t_over_D; fos_req=fos_req, min_wall_m=2e-3)
end

@testset "size_beams_closed_form — every ring incl. the hub is sized" begin
    dec = decode_seed()
    cfg = cfg_5kw()
    s = size_beams_closed_form(dec, params_5kw_188(), cfg)

    n = length(dec.radii)
    @test length(s.Do_per_ring) == n
    @test length(s.N_comp_per_ring) == n
    @test length(s.T_line_per_ring) == n
    @test all(isfinite, s.Do_per_ring)
    @test all(>(0.0), s.Do_per_ring)
    # No ring collapses to the unmanufacturable 1 mm Euler floor.
    @test all(>(1.5e-3), s.Do_per_ring)

    # The hub ring (last, ground-first) is a first-class load case.
    @test s.Do_per_ring[end] > 1.5e-3
    @test isfinite(s.N_comp_per_ring[end])

    # Every loaded ring meets the FoS floor at its solved Do.
    for i in eachindex(s.Do_per_ring)
        if s.N_comp_per_ring[i] > 0.0
            @test s.fos_per_ring[i] >= cfg.fos_hard
        end
    end
end

@testset "size_beams_closed_form — corrected ground-first load build" begin
    dec = decode_seed()
    cfg = cfg_5kw()
    s = size_beams_closed_form(dec, params_5kw_188(), cfg)

    # `ring_idx` is a ground-first system index (hub = length(radii)).
    @test dec.rotors[1].ring_idx == length(dec.radii)          # hub rotor
    @test [r.ring_idx for r in dec.rotors] ==
          [length(dec.radii), length(dec.radii) - 1, length(dec.radii) - 2]

    # Line tension accumulates DOWNWARD: the ground end carries the most.
    # Under the legacy `gi = ri + 1` off-by-one the accumulation was shifted.
    for i in 1:(length(s.T_line_per_ring) - 1)
        @test s.T_line_per_ring[i] >= s.T_line_per_ring[i + 1] - 1e-9
    end

    # Constant-radius transmission cylinder (rings 2-4) → equal axial load.
    @test s.N_comp_per_ring[2] ≈ s.N_comp_per_ring[3] atol=1e-6
    @test s.N_comp_per_ring[3] ≈ s.N_comp_per_ring[4] atol=1e-6
    @test s.N_comp_per_ring[2] > 0.0

    # The cone-top kink dominates the ring above it (geometry, not a flat DLF):
    # the ring at the top of the cone carries more axial load than the harvest
    # ring above it, which sees only the helix.
    @test s.N_comp_per_ring[7] > s.N_comp_per_ring[8]
end
