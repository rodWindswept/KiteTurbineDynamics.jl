# test/test_objective_v12.jl
# First dedicated coverage for the V12 power-window objective (2026-08-09).
#
# PURE UNIT TESTS on v12_fitness (power window, FoS target, hard gate) plus
# one short-horizon warmstart smoke.  The shared windowed protocol behind
# objective_v12_warmstart is exercised by test_objective_v11.jl (A1/A2) —
# V12's delta is the fitness function, which is pure and tested here.

using Test
using KiteTurbineDynamics

@testset "v12_fitness — power window [25, 50] kW" begin
    cfg = ObjectiveConfig()  # defaults: p_floor=25, p_ceiling=50, FoS target 3.0

    # Inside the window, FoS at target → score = -P_mean (more power, better)
    @test v12_fitness(30.0, 3.0, cfg) ≈ -30.0
    @test v12_fitness(40.0, 3.0, cfg) < v12_fitness(30.0, 3.0, cfg)

    # Below floor: quadratic penalty pushes the score up (worse)
    @test v12_fitness(20.0, 3.0, cfg) > v12_fitness(30.0, 3.0, cfg)
    @test v12_fitness(10.0, 3.0, cfg) > v12_fitness(20.0, 3.0, cfg)

    # Above ceiling: the window is a SOFT preference — the penalty makes an
    # above-ceiling design worse than the same power UNPENALIZED, and the
    # quadratic term eventually dominates raw power (80 kW scores worse than
    # 60 kW).  Verified against the formula 2026-08-09:
    #   f(60) = -60/1.08 = -55.6 ;  f(80) = -80/1.72 = -46.5
    @test v12_fitness(60.0, 3.0, cfg) > -60.0     # penalty applied vs unpenalized
    @test v12_fitness(80.0, 3.0, cfg) > v12_fitness(60.0, 3.0, cfg)
end

@testset "v12_fitness — FoS target 3.0" begin
    cfg = ObjectiveConfig()

    # Below target: steep quadratic penalty
    @test v12_fitness(30.0, 2.0, cfg) > v12_fitness(30.0, 3.0, cfg)
    # Above target: gentle linear penalty (wasteful, not dangerous)
    @test v12_fitness(30.0, 4.0, cfg) > v12_fitness(30.0, 3.0, cfg)
    # The linear-above slope is gentle: 1.0 FoS above target costs little
    @test v12_fitness(30.0, 4.0, cfg) < v12_fitness(30.0, 2.0, cfg)
end

@testset "v12_fitness — hard gate is Inf, not a score" begin
    cfg = ObjectiveConfig()  # fos_hard = 1.5

    # FoS below the hard floor → Inf (the evaluator maps it to status=:reject)
    @test v12_fitness(30.0, 1.4, cfg) == Inf
    @test v12_fitness(30.0, 0.5, cfg) == Inf
    # Exactly at the hard edge: allowed (finite)
    @test isfinite(v12_fitness(30.0, 1.5, cfg))
    # A stalled-but-valid eval is a finite score, never Inf
    @test isfinite(v12_fitness(0.0, 3.0, cfg))
end

@testset "v12_fitness — tuning knobs ride in ObjectiveConfig" begin
    # The same P/FoS pair scores differently under a different config —
    # proves the knobs are config fields, not hidden globals (were V12_* Refs).
    strict = ObjectiveConfig(; p_floor_kw=30.0, p_ceiling_kw=40.0)
    loose  = ObjectiveConfig(; p_floor_kw=10.0, p_ceiling_kw=60.0)
    @test v12_fitness(20.0, 3.0, strict) > v12_fitness(20.0, 3.0, loose)
end

@testset "objective_v12_warmstart — smoke (short horizon)" begin
    # One short-horizon eval proves the V12 adapter's cfg/kwarg plumbing
    # end-to-end.  CI-cost guard: 4 s horizon, same as the A1/A2 tests.
    # (The cold objective_v12 is export-only with no script callers, and its
    # fixed 60 s settle + 60 s window is not CI-viable — the warmstart smoke
    # covers the shared dims/contract checks it inherits.)
    p = params_v5_50kw()
    x = [0.15, 0.05, 1.5, 0.5, 3.0, 3.0, 2.0, 8.0, 0.0,
         30.0, 15.0, 15.0, 1.0, 1.0]
    cfg = ObjectiveConfig(; relax_s=1.0, window_s=3.0)
    r = objective_v12_warmstart(x, PROFILE_ELLIPTICAL, p; cfg=cfg)
    @test r isa ObjectiveResult
    @test r.status in (:ok, :reject)
    if r.status === :ok
        @test isfinite(r.fitness)
    end
@testset "v12_fitness — FoS cap hard rejection at 16" begin
    cfg = ObjectiveConfig()
    # FoS=16 is at cap edge: allowed (finite score)
    @test isfinite(v12_fitness(30.0, 16.0, cfg))
    # FoS=17 (and any above 16) is rejected: Inf
    @test v12_fitness(30.0, 17.0, cfg) == Inf
    @test v12_fitness(30.0, 287.0, cfg) == Inf
    # FoS closer to target (3.0) is better (more negative) within [target, cap]
    @test v12_fitness(30.0, 4.0, cfg) < v12_fitness(30.0, 8.0, cfg)
    @test v12_fitness(30.0, 8.0, cfg) < v12_fitness(30.0, 16.0, cfg)
    # Custom cap at 10: FoS=10 allowed, FoS=11 rejected
    cfg10 = ObjectiveConfig(; fos_cap=10.0)
    @test isfinite(v12_fitness(30.0, 10.0, cfg10))
    @test v12_fitness(30.0, 11.0, cfg10) == Inf
    @test v12_fitness(30.0, 4.0, cfg10) < v12_fitness(30.0, 10.0, cfg10)
end
end
