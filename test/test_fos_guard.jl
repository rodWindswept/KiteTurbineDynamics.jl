# test/test_fos_guard.jl — acceptance for the non-finite-FoS guard
# (convention-fixes proposal item 0, 2026-08-22).
#
# STATUS: GREEN — guard landed 2026-08-22 in src/objective_v11.jl and
# src/objective_v12.jl (mass_min_fitness, v12_fitness, v11_fitness).
#
# The exploit (instrument-trust-log 2026-08-22, fault row): mass_min_fitness
# and v12_fitness test `FoS_min < cfg.fos_hard` WITHOUT an isfinite guard, so
# `FoS_min = Inf` (null structural measurement — every window sample's ring
# FoS non-finite) makes `Inf < 2.5` FALSE, the floor passes, and the machine
# scores its mass.  Exploit-register row 1 ("Inf FoS -> feasible") was fixed
# in objective_feasibility (5d02d45) but never landed in the mass-min
# objective (2026-08-20), v12_fitness, or v11_fitness.
using Test
using KiteTurbineDynamics

@testset "non-finite FoS cannot pass the hard floor (2026-08-22)" begin
    cfg = ObjectiveConfig(; fos_hard=2.5, p_floor_kw=5.0)

    # The exploit: a machine transmitting 6 kW with unmeasured ring loads
    # must be a HARD REJECT, not a feasible mass score.
    @test mass_min_fitness(6.0, Inf, cfg, 10.0) == Inf
    @test mass_min_fitness(6.0, NaN, cfg, 10.0) == Inf
    @test mass_min_fitness(6.0, -Inf, cfg, 10.0) == Inf
    @test v12_fitness(6.0, Inf, cfg) == Inf
    @test v12_fitness(6.0, NaN, cfg) == Inf
    @test v11_fitness(6.0, Inf) == Inf     # same exploit in the v11 power objective
    @test v11_fitness(6.0, NaN) == Inf

    # The legitimate boundaries stay intact.
    @test mass_min_fitness(6.0, 1.9, cfg, 10.0) == Inf    # below FoS floor
    @test mass_min_fitness(4.0, 3.0, cfg, 10.0) == Inf    # below P floor
    @test mass_min_fitness(6.0, 3.0, cfg, 10.0) == 10.0   # feasible -> mass
end

# ══════════════════════════════════════════════════════════════════════════════
# 2026-09-08 audit (recommendation 1): the LIVE scoring seam had no guard.
# `appropriate_mass_fitness` is the fitness the 5 kW campaign runner scores with
# (run_v13_5kw_masslift.jl:275).  Its v11/v12 siblings are guarded above; a
# regression that dropped the isfinite check from appropriate_mass_fitness alone
# would leave every test above GREEN — the sharpest false-confidence gap in the
# suite.
# ══════════════════════════════════════════════════════════════════════════════
@testset "appropriate_mass_fitness — non-finite FoS (live campaign seam)" begin
    cfg = ObjectiveConfig(; fos_hard=2.5, p_floor_kw=5.0)

    # A null structural measurement cannot buy a feasible mass score.
    @test KiteTurbineDynamics.appropriate_mass_fitness(6.0, Inf, cfg, 10.0) == Inf
    @test KiteTurbineDynamics.appropriate_mass_fitness(6.0, NaN, cfg, 10.0) == Inf
    @test KiteTurbineDynamics.appropriate_mass_fitness(6.0, -Inf, cfg, 10.0) == Inf

    # The legitimate hard floors stay intact …
    @test KiteTurbineDynamics.appropriate_mass_fitness(6.0, 1.9, cfg, 10.0) == Inf
    @test KiteTurbineDynamics.appropriate_mass_fitness(4.0, 3.0, cfg, 10.0) == Inf

    # … and a feasible machine returns finite mass-plus-penalties (penalties only add).
    f = KiteTurbineDynamics.appropriate_mass_fitness(6.0, 3.0, cfg, 10.0)
    @test isfinite(f)
    @test f >= 10.0
end

println("\n✓ fos-guard acceptance tests complete (expect RED until the guard lands)")
