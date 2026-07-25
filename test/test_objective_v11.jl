# test/test_objective_v11.jl
# Acceptance tests for Gate 3 — windowed ODE objective with k in the genome.
#
# PURE UNIT TESTS: v11_fitness(P, FoS) monotonicity and correctness.
# ODE integration tests moved to test_objective_v11_slow.jl (multi-minute runtime).

using Test
using KiteTurbineDynamics

const FD = KiteTurbineDynamics.FOS_DESIGN  # 1.5

# ══════════════════════════════════════════════════════════════════════════════
# Module exports & bounds
# ══════════════════════════════════════════════════════════════════════════════

@testset "objective_v11 — module exports" begin
    @test TRPT_V11_DIM == 15
    lo, hi = search_bounds_v11(params_v5_50kw(), PROFILE_ELLIPTICAL)
    @test length(lo) == 15
    @test length(hi) == 15
    @test lo[15] == -2.0
    @test hi[15] == 3.0
end

# ══════════════════════════════════════════════════════════════════════════════
# v11_fitness — pure unit tests (no ODE, milliseconds)
# ══════════════════════════════════════════════════════════════════════════════

@testset "v11_fitness — FoS ≥ FOS_DESIGN: no penalty" begin
    @test v11_fitness(100.0, Inf) == -100.0
    @test v11_fitness(100.0, FD)  == -100.0
    @test v11_fitness(100.0, FD * 2.0) == -100.0
end

@testset "v11_fitness — FoS penalty is divisive (sign-bug guard)" begin
    f_good = v11_fitness(100.0, FD)          # FoS=1.5 → -100
    f_ok   = v11_fitness(100.0, FD * 0.5)    # FoS=0.75 → -50
    f_bad  = v11_fitness(100.0, FD * 0.1)    # FoS=0.15 → -10
    f_vbad = v11_fitness(100.0, 0.03)        # FoS=0.03 → -2

    @test f_good <= 0.0
    @test f_ok   <= 0.0
    @test f_bad  <= 0.0
    @test f_vbad <= 0.0

    # Monotonicity: better FoS → more negative fitness
    @test f_good < f_ok
    @test f_ok < f_bad
    @test f_bad < f_vbad

    # Numeric values
    @test v11_fitness(100.0, 0.03) ≈ -100.0 / 50.0
    @test v11_fitness(100.0, 0.75) ≈ -100.0 / 2.0
end

@testset "v11_fitness — more power is always better" begin
    @test v11_fitness(200.0, FD) < v11_fitness(100.0, FD)
    @test v11_fitness(200.0, 0.03) < v11_fitness(100.0, 0.03)
end

@testset "v11_fitness — FoS penalty dominates power at small FoS" begin
    f_A = v11_fitness(50.0, FD)         # -50
    f_B = v11_fitness(200.0, 0.15)      # -20 (penalty=10)
    @test f_A < f_B

    # But enough power can compensate
    f_C = v11_fitness(500.0, 0.15)      # -50 (ties A)
    f_D = v11_fitness(600.0, 0.15)      # -60 (beats A)
    @test f_C ≈ f_A
    @test f_D < f_A
end

@testset "v11_fitness — edge cases" begin
    @test v11_fitness(0.0, FD) == 0.0
    @test v11_fitness(0.0, 0.03) == 0.0
end

# ══════════════════════════════════════════════════════════════════════════════
# Snapshot backward compat
# ══════════════════════════════════════════════════════════════════════════════

@testset "objective_v11 — snapshot backward compat" begin
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

# ══════════════════════════════════════════════════════════════════════════════
# objective_feasibility — three-tier ordering and monotonicity
# ══════════════════════════════════════════════════════════════════════════════

@testset "objective_feasibility — tier ordering" begin
    # Stalled > feasibility > feasible.  P_floor default is 25.0 kW.
    f_stalled  = objective_feasibility(10.0, 10.0)  # P=10 < P_floor=25
    f_feas     = objective_feasibility(30.0, 0.5)    # FoS=0.5 < 1.5
    f_good     = objective_feasibility(30.0, 2.0)    # passes both
    f_reject   = objective_feasibility(30.0, Inf)     # null FoS → rejection

    @test f_reject > f_stalled  # rejection above all stalls
    @test f_stalled > f_feas
    @test f_feas > f_good
    @test f_good < 0.0  # feasible tier is negative
    @test f_stalled >= 10.0  # stalled starts at 10
    @test f_reject >= 12.0   # rejection band
end

@testset "objective_feasibility — monotonicity within tiers" begin
    # Stalled: worse (lower P) → higher fitness
    @test objective_feasibility(0.1, 1.0) > objective_feasibility(24.0, 1.0)

    # Feasibility: worse (lower FoS) → higher fitness
    @test objective_feasibility(30.0, 0.2) > objective_feasibility(30.0, 1.4)

    # Feasible: more power → lower (better) fitness, capped at P_cap
    @test objective_feasibility(30.0, 2.0) > objective_feasibility(45.0, 2.0)
    @test objective_feasibility(50.0, 2.0) == objective_feasibility(100.0, 2.0)  # capped

    # FoS=1.5 exactly at threshold: passes to feasible tier (>= FoS_design)
    f_at_bound = objective_feasibility(30.0, 1.5)
    @test f_at_bound < 0.0  # feasible, negative
end

@testset "objective_feasibility — edge cases" begin
    # Zero power, infinite FoS → stalled
    f = objective_feasibility(0.0, Inf)
    @test f > 10.0

    # Tiny power, good FoS → stalled (P < P_floor)
    f = objective_feasibility(0.01, 5.0)
    @test f > 10.0

    # Good power, barely passing FoS → feasibility (just under 1.5)
    # P must exceed P_floor (default 25 kW)
    f = objective_feasibility(30.0, 1.499)
    @test f > 0.0 && f < 1.5

    # Exactly P_floor passes stalled check
    f = objective_feasibility(25.0, 0.1)
    @test f > 0.0  # goes to feasibility tier, not stalled
end
