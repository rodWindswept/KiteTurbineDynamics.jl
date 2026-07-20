# test/test_objective_v11.jl
# Acceptance tests for Gate 3 — windowed ODE objective with k in the genome.
# Reference: PRD 0007 Gate 3 (docs/prd/0007-gate3-spec.md)

using Test
using KiteTurbineDynamics

const SP = KiteTurbineDynamics.SpokeParams(enabled=false)

@testset "objective_v11 — module exports" begin
    @test TRPT_V11_DIM == 15
    lo, hi = search_bounds_v11(params_v5_50kw(), PROFILE_ELLIPTICAL)
    @test length(lo) == 15
    @test length(hi) == 15
    @test lo[15] == -2.0
    @test hi[15] == 3.0
end

@testset "objective_v11 — k bounds don't crash" begin
    # Acceptance test 4: extreme k values must return finite fitness

    p = params_v5_50kw()

    x = zeros(15)
    x[1]  = 0.075;  x[2]  = 0.01;   x[3]  = 1.0
    x[4]  = 0.5;    x[5]  = 3.7;    x[6]  = 2.0
    x[7]  = 2.5;    x[8]  = 12.0;   x[9]  = 0.0
    x[10] = 8.0;    x[11] = 15.0;   x[12] = 5.0
    x[13] = 0.5;    x[14] = 0.3

    # k_min: log10(k) = -2 → k = 0.01
    x[15] = -2.0
    f_min = objective_v11(x, PROFILE_ELLIPTICAL, p; spoke=SP)
    @test isfinite(f_min)

    # k_max: log10(k) = 3 → k = 1000
    x[15] = 3.0
    f_max = objective_v11(x, PROFILE_ELLIPTICAL, p; spoke=SP)
    @test isfinite(f_max)

    @test f_min isa Float64
    @test f_max isa Float64
end

@testset "objective_v11 — determinism" begin
    # Acceptance test 3: same genome, same fitness (within FP tolerance)

    x = zeros(15)
    x[1]  = 0.075;  x[2]  = 0.01;   x[3]  = 1.0
    x[4]  = 0.5;    x[5]  = 3.7;    x[6]  = 2.0
    x[7]  = 2.5;    x[8]  = 12.0;   x[9]  = 0.0
    x[10] = 8.0;    x[11] = 15.0;   x[12] = 5.0
    x[13] = 0.5;    x[14] = 0.3;    x[15] = 1.0

    f1 = objective_v11(x, PROFILE_ELLIPTICAL, params_v5_50kw(); spoke=SP)
    f2 = objective_v11(x, PROFILE_ELLIPTICAL, params_v5_50kw(); spoke=SP)

    @test f1 == f2
end

@testset "objective_v11 — snapshot backward compat" begin
    # Acceptance test 6: snapshot mode matches v10 on feasible design

    x = zeros(15)
    x[1]  = 0.075;  x[2]  = 0.01;   x[3]  = 1.0
    x[4]  = 0.5;    x[5]  = 3.7;    x[6]  = 2.0
    x[7]  = 2.5;    x[8]  = 12.0;   x[9]  = 0.0
    x[10] = 8.0;    x[11] = 15.0;   x[12] = 5.0
    x[13] = 0.5;    x[14] = 0.3

    f_v11 = objective_v11_snapshot(x, PROFILE_ELLIPTICAL, params_v5_50kw())
    f_v10 = objective_v10(x[1:14], PROFILE_ELLIPTICAL, params_v5_50kw())

    @test f_v11 == f_v10
end

@testset "objective_v11 — feasible genome returns negative fitness" begin
    # Valid 1-rotor design: rotor_mask=0 maps to VALID_ROTOR_MASKS[1] (hub rotor)
    x = zeros(15)
    x[1]  = 0.075;  x[2]  = 0.01;   x[3]  = 1.0
    x[4]  = 0.5;    x[5]  = 3.7;    x[6]  = 2.0
    x[7]  = 2.5;    x[8]  = 12.0;   x[9]  = 0.0
    x[10] = 0.0;    x[11] = 15.0;   x[12] = 5.0
    x[13] = 0.5;    x[14] = 0.3;    x[15] = 1.0

    f = objective_v11(x, PROFILE_ELLIPTICAL, params_v5_50kw(); spoke=SP)
    @test isfinite(f)
    @test f <= 0.0  # negative fitness = positive power
end

@testset "objective_v11 — fitness sign convention" begin
    # DE minimises → more power = more negative fitness

    x_high_k = zeros(15)
    x_high_k[1]  = 0.075;  x_high_k[2] = 0.01;   x_high_k[3] = 1.0
    x_high_k[4]  = 0.5;    x_high_k[5] = 3.7;    x_high_k[6] = 2.0
    x_high_k[7]  = 2.5;    x_high_k[8] = 12.0;   x_high_k[9] = 0.0
    x_high_k[10] = 8.0;    x_high_k[11]= 15.0;   x_high_k[12]= 5.0
    x_high_k[13] = 0.5;    x_high_k[14]= 0.3;    x_high_k[15]= 1.0   # k=10

    x_low_k = copy(x_high_k)
    x_low_k[15] = -1.0    # k=0.1 — should produce less power

    f_high_k = objective_v11(x_high_k, PROFILE_ELLIPTICAL, params_v5_50kw(); spoke=SP)
    f_low_k  = objective_v11(x_low_k, PROFILE_ELLIPTICAL, params_v5_50kw(); spoke=SP)

    @test isfinite(f_high_k)
    @test isfinite(f_low_k)
    @test f_high_k <= 0.0
end
