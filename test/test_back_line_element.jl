# test/test_back_line_element.jl
#
# 2026-09-16.  STATIC unit test for the bi-linear, tension-only back line.
#
# The ruling (Rod, 2026-09-15) is that at the design point the back line is TAUT
# and carries residual tension, with 8 sections of 4 mm bungee sewn in series
# with the 3 mm Dyneema giving 80 cm of soft travel.  `back_line_tension` is the
# single authority for that law; `ring_forces.jl` calls it for the ODE force and
# `design_axial_preload` will call it for the load split.
#
# The design point sits ON THE HARD STOP: trimmed so the bungee is fully extended
# and the Dyneema is taut at the design length.
#
# No ODE, no genome, no simulation: this is a kernel test and belongs in the fast
# suite (AGENTS.md).  It asserts the five properties the element must have:
#   (1) tension-only  — zero for the whole relaxed travel
#   (2) soft branch   — linear in d, reaching T_design at the trimmed length
#   (3) hard stop     — continuous at the trimmed length, then far stiffer
#   (4) monotone      — tension never falls as the line extends
#   (5) the design point carries T_design, not ~0
# plus the trim behaviour, which is the field's launch control.

using Test
using KiteTurbineDynamics
const KTD = KiteTurbineDynamics

@testset "back line — bi-linear tension-only element" begin
    trimmed = 14.2127            # m, the L/r 1.5 candidate's grounded design length
    payout = 0.0
    EA = 707_000.0               # N, 3 mm Dyneema, the declared 5 kW value

    travel = KTD.BACK_LINE_SOFT_TRAVEL_M
    T_design = KTD.BACK_LINE_E_SUM_N / (1.0 + travel / trimmed)
    k_soft = T_design / travel

    @test travel == 0.8
    @test T_design > 0.0
    @test k_soft > 0.0
    # The soft travel is 8 bungee sections of 10 cm each.
    @test KTD.BACK_LINE_E_SUM_N ≈ 8 * 0.30

    # (1) tension-only across the relaxed travel, and at its far end
    @test KTD.back_line_tension(trimmed - travel, trimmed, payout, EA) == 0.0
    @test KTD.back_line_tension(trimmed - travel - 1e-9, trimmed, payout, EA) == 0.0
    @test KTD.back_line_tension(0.0, trimmed, payout, EA) == 0.0

    # (5) THE DESIGN POINT CARRIES T_design.  This is the assertion that catches
    # a mis-derived k_soft: a wrong stiffness shows up as ~0 tension at design,
    # which would silently make the ruled "taut at the design point" false.
    @test KTD.back_line_tension(trimmed, trimmed, payout, EA) ≈ T_design rtol = 1e-12
    @test KTD.back_line_tension(trimmed, trimmed, payout, EA) > 1.0   # not ~0

    # (2) soft branch is linear over the travel, at both ends and the middle
    for frac in (0.25, 0.5, 0.75)
        d = trimmed - travel + frac * travel
        @test KTD.back_line_tension(d, trimmed, payout, EA) ≈ k_soft * frac * travel rtol = 1e-12
    end

    # (3) continuity at the trimmed length: both branches reach T_design there.
    # The tolerance must scale with the HARD branch slope (EA/trimmed ≈ 5e4 N/m),
    # so a 1e-9 m step legitimately moves the tension by ~5e-5 N.
    slope_hard = EA / trimmed
    tol = 10 * slope_hard * 1e-9
    below = KTD.back_line_tension(trimmed - 1e-9, trimmed, payout, EA)
    above = KTD.back_line_tension(trimmed + 1e-9, trimmed, payout, EA)
    @test abs(KTD.back_line_tension(trimmed, trimmed, payout, EA) - T_design) < 1e-9
    @test abs(below - T_design) < tol
    @test abs(above - T_design) < tol
    @test above >= below
    # The step across 2e-9 m is the Dyneema slope, not a jump.
    @test abs(above - below) < 2 * tol

    # Beyond the stop the Dyneema holds: one more 80 cm would be enormous.
    T_far = KTD.back_line_tension(trimmed + travel, trimmed, payout, EA)
    @test T_far > 1000 * T_design
    @test isfinite(T_far)

    # (4) monotone non-decreasing over a wide sweep
    ds = range(0.0, trimmed + 3.0; length=4000)
    Ts = [KTD.back_line_tension(d, trimmed, payout, EA) for d in ds]
    @test all(Ts[i + 1] >= Ts[i] - 1e-9 for i in 1:(length(Ts) - 1))
    @test all(isfinite, Ts)

    # EA sets the hard branch only; the soft branch is bungee geometry
    mid = trimmed - 0.5 * travel
    @test KTD.back_line_tension(mid, trimmed, payout, EA) ≈
        KTD.back_line_tension(mid, trimmed, payout, 2 * EA) rtol = 1e-12
    @test KTD.back_line_tension(trimmed + 0.01, trimmed, payout, 2 * EA) >
        KTD.back_line_tension(trimmed + 0.01, trimmed, payout, EA)

    # Payout is the winch TRIM (Rod, 2026-09-16): the field pays line out at
    # launch to set the sky anchor's height.  Tension is a function of the
    # geometric distance `d` alone, so paying out lowers the tension at a fixed
    # anchor distance and raises the anchor's reach.
    p_out = 0.1
    d_fixed = trimmed + 0.2
    @test KTD.back_line_tension(d_fixed, trimmed, p_out, EA) ≈
        KTD.back_line_tension(d_fixed, trimmed, 0.0, EA) rtol = 1e-12

    # Bad geometry is loud, not silently zero.
    @test_throws ErrorException KTD.back_line_tension(10.0, 0.0, 0.0, EA)
    @test_throws ErrorException KTD.back_line_tension(10.0, trimmed, -0.1, EA)
    @test_throws ErrorException KTD.back_line_tension(10.0, trimmed, 0.0, 0.0)
end
