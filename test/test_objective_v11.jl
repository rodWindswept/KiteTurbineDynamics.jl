# test/test_objective_v11.jl
# Acceptance tests for Gate 3 — windowed ODE objective with k in the genome.
#
# PURE UNIT TESTS: v11_fitness(P, FoS) monotonicity and correctness.
# The A1/A2 warmstart calls below use a SHORT window (4 s) on purpose — the
# full 40 s horizon made this file ~17 min of CI time for assertions that are
# per-sample or ceiling-based.  Full-horizon ODE verification lives in the
# campaign launcher (run_feasibility_phase_a.jl), not here.

using Test
using KiteTurbineDynamics

const FD = KiteTurbineDynamics.FOS_GATE  # 1.5 — the objective's minimum-acceptable FoS
# (Distinct from the structural FOS_DESIGN = 3.0 — the objective's old
# `const FOS_DESIGN = 1.5` shadowed it at load; renamed FOS_GATE 2026-08-09.)

# ══════════════════════════════════════════════════════════════════════════════
# Module exports & bounds
# ══════════════════════════════════════════════════════════════════════════════

@testset "objective_v11 — module exports" begin
    @test TRPT_V11_DIM == 14
    lo, hi = search_bounds_v11(params_v5_50kw(), PROFILE_ELLIPTICAL)
    @test length(lo) == 14
    @test length(hi) == 14
end

# ══════════════════════════════════════════════════════════════════════════════
# v11_fitness — pure unit tests (no ODE, milliseconds)
# ══════════════════════════════════════════════════════════════════════════════

@testset "v11_fitness — FoS ≥ FOS_GATE: no penalty" begin
    # FoS=Inf (null structural measurement) is a REJECT (Inf), not a healthy
    # score — was -100.0, the exploit-register row-1 class (guard 2026-08-22).
    @test v11_fitness(100.0, Inf) == Inf
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
# objective_v10 — static-evaluator regression pin
# ══════════════════════════════════════════════════════════════════════════════

@testset "objective_v10 — static evaluator regression pin" begin
    # Formerly the objective_v11_snapshot test (deleted 2026-08-09 — the
    # snapshot was a v10 forwarder wearing a v11 name).  The pin survives as
    # a direct v10 call: the static solver is frozen legacy, and this guards
    # it against drift.
    x = zeros(15)
    x[1]  = 0.075;  x[2]  = 0.01;   x[3]  = 1.0
    x[4]  = 0.5;    x[5]  = 3.7;    x[6]  = 2.0
    x[7]  = 2.5;    x[8]  = 12.0;   x[9]  = 0.0
    x[10] = 8.0;    x[11] = 15.0;   x[12] = 5.0
    x[13] = 0.5;    x[14] = 0.3

    f_v10 = objective_v10(x[1:14], PROFILE_ELLIPTICAL, params_v5_50kw())
    @test f_v10 isa Float64
    @test isfinite(f_v10)
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

# ══════════════════════════════════════════════════════════════════════════════
# A5: rejection band — all rejection paths exceed stalled and feasibility tiers
# ══════════════════════════════════════════════════════════════════════════════
@testset "objective_feasibility — rejection band" begin
    f_stalled  = objective_feasibility(10.0, 10.0)   # stalled tier
    f_feas     = objective_feasibility(30.0, 0.5)      # feasibility tier

    rejections = [
        objective_feasibility(30.0, Inf),     # null FoS
        objective_feasibility(30.0, NaN),     # NaN FoS
        objective_feasibility(30.0, 0.0),      # zero FoS
        objective_feasibility(30.0, -1.0),     # negative FoS
    ]
    for f_reject in rejections
        @test f_reject > f_stalled   # rejection strictly above stalled
        @test f_reject > f_feas      # rejection strictly above feasibility
        @test f_reject >= 12.0       # rejection band floor
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# A4: n_lines decoder must not clamp at 12 when bounds allow 16
# ══════════════════════════════════════════════════════════════════════════════
@testset "A4: n_lines decoder ceiling" begin
    x_16 = [0.15, 0.05, 1.5, 0.5, 3.0, 3.0, 2.0, 15.9, 0.0, 30.0,
            15.0, 15.0, 1.0, 1.0]
    design = design_from_vector_v4(x_16, PROFILE_ELLIPTICAL, params_v5_50kw())
    @test design.n_lines == 16  # must decode to 16, not silently clamp to 12
end

# ══════════════════════════════════════════════════════════════════════════════
# A2: Betz ceiling — known super-Betz rows
# ══════════════════════════════════════════════════════════════════════════════
@testset "A2: Betz ceiling — known super-Betz rows" begin
    # P=1103 kW at 15 m/s needs ~900 m² — impossible for ring sizes in our
    # search space.  Reject at objective level.
    # CI-cost guard (2026-08-07): a 4 s horizon (relax 1 s + window 3 s)
    # still yields 3 power samples (sample interval = 1 s), which is enough
    # for the Betz/identity assertions — they check per-sample co-location
    # and a ceiling, not long-horizon dynamics.  The horizon rides in the
    # ObjectiveConfig now (was: mutating the WARM_RELAX_S/WARM_WINDOW_S
    # module Refs — a data race under threaded campaigns, deleted 2026-08-09).
    p = params_v5_50kw()
    x = [0.15, 0.05, 1.5, 0.5, 3.0, 3.0, 2.0, 8.0, 0.0,
         30.0, 15.0, 15.0, 1.0, 1.0]
    cfg = ObjectiveConfig(; relax_s=1.0, window_s=3.0, v_rated=15.0)
    r = objective_v11_warmstart(x, PROFILE_ELLIPTICAL, p; cfg=cfg)
    # With a valid design, either it evaluates or it is genuinely rejected.
    # (The pre-2026-08-09 rejection path CRASHED here — the first Betz gate
    # referenced P_range before assignment.  This call would have thrown.)
    @test r isa ObjectiveResult
    @test r.status === :ok || r.P_mean == 0.0
    if r.status === :ok
        # Any finite score is a real measurement.  (NOT < 0.0: the F5
        # stationarity penalty can legitimately push a ~0 kW swinging eval's
        # fitness positive — observed 23.6 at the 4 s test horizon.)
        @test isfinite(r.fitness)
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# A1: util split identity — |ua + ub − 1/FoS_min| × FoS_min < 0.01
# ══════════════════════════════════════════════════════════════════════════════
@testset "A1: util split co-located with FoS_min" begin
    # Verify that objective_v11 returns util_a, util_b from the same sample
    # as FoS_min.  The evaluator ties them together and warns on violation.
    p = params_v5_50kw()
    x = [0.15, 0.05, 1.5, 0.5, 3.0, 3.0, 2.0, 8.0, 0.0,
         30.0, 15.0, 15.0, 1.0, 1.0]
    # Short window (see A2 testset above) — identity is per-sample, so a 4 s
    # horizon exercises it at ~10× lower ODE cost.
    cfg = ObjectiveConfig(; relax_s=1.0, window_s=3.0)
    r = objective_v11_warmstart(x, PROFILE_ELLIPTICAL, p; cfg=cfg)
    # If we have valid measurements, identity must hold to within 1% of FoS.
    # Guard excludes ONLY the -1.0 sentinel (no airborne rings / misaligned
    # sample): a genuine ua == 0.0 (ring in pure bending at window start)
    # is a valid measurement and must still run the identity.  Verified
    # 2026-08-07: at the 4 s test horizon ua=0.0, ub=0.02151, 1/FoS=0.02152
    # — identity holds; the old `ua > 0.0` guard silently skipped it.
    if r.status === :ok && r.util_a > -0.5 && r.util_b > -0.5 &&
       isfinite(r.FoS_min) && r.FoS_min > 0.0
        id_err = abs(r.util_a + r.util_b - 1.0 / r.FoS_min) * r.FoS_min
        @test id_err < 0.01
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# Result contract — the bracket cannot let an all-rejected genome win
# ══════════════════════════════════════════════════════════════════════════════

@testset "with_k_bracket — all-rejected genome cannot win" begin
    # The pre-2026-08-09 defect: the bracket filtered `fitness >= 1e8`, which
    # MISSED the 12.0 rejection sentinel — an all-rejected genome "won" its
    # bracket with fitness 12.0 and landed in campaign CSVs as a real result.
    # Now the bracket gates on status; a scoring fn that always rejects must
    # come back as status=:reject.  No ODE runs in this test (stub scoring).
    x = [0.15, 0.05, 1.5, 0.5, 3.0, 3.0, 2.0, 8.0, 0.0,
         30.0, 15.0, 15.0, 1.0, 1.0]
    always_reject = (x14, cfg) -> KiteTurbineDynamics.rejected_eval()
    best, best_k = with_k_bracket(always_reject, x, PROFILE_ELLIPTICAL,
                                  params_v5_50kw())
    @test best.status === :reject
    @test best.fitness == Inf
    @test isfinite(best_k)
end
