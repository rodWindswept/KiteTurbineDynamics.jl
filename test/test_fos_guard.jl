# test/test_fos_guard.jl — RED acceptance for the non-finite-FoS guard
# (convention-fixes proposal item 0, 2026-08-22).
#
# STATUS: RED BY DESIGN — NOT WIRED into test/runtests.jl yet (the fast
# suite must stay green while the 5 kW campaign runs on the current HEAD).
# Land the guard in src/objective_v12.jl, then wire this file into
# runtests.jl and go green in the SAME commit.
#
# The exploit (instrument-trust-log 2026-08-22, fault row): mass_min_fitness
# and v12_fitness test `FoS_min < cfg.fos_hard` WITHOUT an isfinite guard, so
# `FoS_min = Inf` (null structural measurement — every window sample's ring
# FoS non-finite) makes `Inf < 2.5` FALSE, the floor passes, and the machine
# scores its mass.  Exploit-register row 1 ("Inf FoS -> feasible") was fixed
# in objective_feasibility (5d02d45) but never landed in the mass-min
# objective (2026-08-20) or v12_fitness.
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

    # The legitimate boundaries stay intact.
    @test mass_min_fitness(6.0, 1.9, cfg, 10.0) == Inf    # below FoS floor
    @test mass_min_fitness(4.0, 3.0, cfg, 10.0) == Inf    # below P floor
    @test mass_min_fitness(6.0, 3.0, cfg, 10.0) == 10.0   # feasible -> mass
end

println("\n✓ fos-guard acceptance tests complete (expect RED until the guard lands)")
