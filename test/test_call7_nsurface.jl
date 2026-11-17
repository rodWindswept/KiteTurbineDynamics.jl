# test/test_call7_nsurface.jl — the Call 7 ODE n-surface, acceptance pins
#
# Written at the science-validator seat on 2026-11-17 as the executable half of
# `docs/reporting/room-responses/science-validator-2026-11-17-call7-nsurface-proposal.md`.
#
# NOT wired into `test/runtests.jl`. It stays out of the suite until
# `BEM.cp_ode` lands behind both signs (aero counter-read + founder call 7 is
# already ruled Option A), then it wires in beside `test_bem_unified.jl`.
#
# The numbers below are read from the committed tables at the proposal HEAD:
#   src/aerodynamics.jl (BEM_TSR / BEM_CP, the AeroDyn n = 3 anchor)
#   src/bem.jl         (_RATIO_TSR, _RATIO_CP, the 96-point regen family)
#   .scratch/bem_regression/fine_lambda_2026-10-22/fine_lambda_bladecount.csv
#
# The two defects this file exists to catch, both in `cp_bem` as it stands:
#   1. Above the last ratio knot (8.3905) the table is HELD at its end value.
#      For n >= 4 that value is positive while `cp_at_tsr` has gone negative, so
#      the product turns positive and reaches the Betz clamp at lambda 9.93 to
#      10.52. The sizing read would FEED a rotor the anchor says is braking.
#   2. `cp_bem` clamps at 0, which deletes the measured brake band inside the
#      table (n = 6 negative from lambda 6.839, n = 9 from 5.748).
# Neither fires on the sizing path, which asks only for a positive radius. Both
# fire on the ODE path, whose lambda band runs to 12.

using Test
using KiteTurbineDynamics
const BEM = KiteTurbineDynamics.BEM

# ── Reference implementation (delete when BEM.cp_ode lands) ──────────────────
# Identical in form to the proposal's definition: the measured ratio inside the
# knots, the anchor alone beyond the last knot, no lower clamp.
function ref_rf_ode(n::Int, lambda::Float64)
    row = BEM._RATIO_CP[clamp(n, 3, 9)-2]
    lambda <= BEM._RATIO_TSR[1] && return row[1]
    for j in 1:(length(BEM._RATIO_TSR)-1)
        if BEM._RATIO_TSR[j] <= lambda <= BEM._RATIO_TSR[j+1]
            t = (lambda - BEM._RATIO_TSR[j]) / (BEM._RATIO_TSR[j+1] - BEM._RATIO_TSR[j])
            return row[j] + t * (row[j+1] - row[j])
        end
    end
    return row[end]
end
function ref_cp_ode(n::Int, lambda::Float64)
    anchor = cp_at_tsr(lambda)
    # The ratio corrects the anchor's positive-power branch only. Where the
    # anchor has gone negative it is the flat-plate brake, and no blade-count
    # ratio may touch it: Rf(end) is negative for n >= 4, so a plain product
    # would turn the brake into positive power past the anchor's zero.
    anchor <= 0.0 && return anchor
    return anchor * ref_rf_ode(n, lambda)
end

# The read under test: the package function once it exists, the reference until then.
cp_read(n::Int, lambda::Float64) =
    isdefined(BEM, :cp_ode) ? BEM.cp_ode(n, lambda) : ref_cp_ode(n, lambda)

@testset "Call 7 n-surface (2026-11-17 proposal pins)" begin

    # ── A1. The n = 3 anchor is the committed table, bit for bit ───────────
    @testset "A1 n = 3 identity is exact" begin
        worst = 0.0
        lambda = 0.0
        while lambda <= 12.0
            worst = max(worst, abs(cp_read(3, lambda) - cp_at_tsr(lambda)))
            lambda += 0.001
        end
        @test worst == 0.0
    end

    # ── A2. The ratio table reproduces at all eight knots ──────────────────
    @testset "A2 measured ratio at the eight knots" begin
        for n in 3:9, k in 1:8
            @test ref_rf_ode(n, BEM._RATIO_TSR[k]) ≈ BEM._RATIO_CP[n-2][k] rtol = 1e-12
        end
    end

    # ── A3. The peak moves down with n, and lands where the data puts it ───
    @testset "A3 peak lambda per n" begin
        pins = ((3, 0.308697, 5.2000), (4, 0.323635, 4.2000), (5, 0.318044, 4.0145),
                (6, 0.317304, 3.4355), (7, 0.317034, 3.2000), (8, 0.316255, 2.9782),
                (9, 0.319333, 2.8131))
        for (n, cp_pin, lam_pin) in pins
            best, arg = -Inf, 0.0
            lambda = 0.0
            while lambda <= 9.0
                c = cp_read(n, lambda)
                if c > best
                    best, arg = c, lambda
                end
                lambda += 0.0005
            end
            @test isapprox(best, cp_pin; atol = 5e-4)
            @test isapprox(arg, lam_pin; atol = 5e-3)
        end
        # ordering, never re-sorted by a re-pin
        for n in 3:8
            @test argmax([cp_read(n, l) for l in 0.0:0.01:9.0]) >=
                  argmax([cp_read(n+1, l) for l in 0.0:0.01:9.0])
        end
    end

    # ── A4. The zero crossing per n: where the rotor stops delivering ──────
    @testset "A4 zero crossing per n" begin
        pins = ((4, 8.0991), (5, 7.4356), (6, 6.8392), (7, 6.4602),
                (8, 6.1546), (9, 5.7484))
        for (n, lam_pin) in pins
            lo, hi = 4.0, 10.0
            @test cp_read(n, lo) > 0.0
            @test cp_read(n, hi) < 0.0
            for _ in 1:80
                mid = (lo + hi) / 2
                if cp_read(n, mid) > 0.0
                    lo = mid
                else
                    hi = mid
                end
            end
            @test isapprox((lo + hi) / 2, lam_pin; atol = 2e-3)
        end
    end

    # ── A5. The archived operating point, 6.8415 ───────────────────────────
    @testset "A5 the flown point" begin
        @test isapprox(cp_read(3, 6.8415), 0.225785; atol = 1e-6)   # NR-032
        @test isapprox(cp_read(4, 6.8415), 0.162351; atol = 1e-5)
        @test isapprox(cp_read(5, 6.8415), 0.089445; atol = 1e-5)
        # n = 6 crosses at 6.8392: the archive's point sits 0.0023 past the
        # crossing, so an n = 6 machine brakes there and must settle lower.
        @test cp_read(6, 6.8415) < 0.0
        @test cp_read(6, 6.8415) > -1e-3
        for n in 7:9
            @test cp_read(n, 6.8415) < -0.05
        end
    end

    # ── A6. The overspeed branch never feeds: above the anchor's zero the
    #        surface returns the anchor unchanged, so no n reads positive.
    @testset "A6 no positive power past the anchor zero" begin
        for n in 3:9
            lambda = 9.7
            while lambda <= 12.0
                @test cp_read(n, lambda) <= 0.0
                lambda += 0.01
            end
        end
        # and the guard this replaces: the sizing read does feed there.
        @test BEM.cp_bem(9, 10.5) > 0.0
    end

    # ── A7. The measured brake band survives: no lower clamp on the ODE read.
    @testset "A7 the brake band" begin
        for n in 6:9
            @test cp_read(n, 7.6) < 0.0
        end
        @test cp_read(6, 7.0) < 0.0            # crossing 6.839
        @test BEM.cp_bem(6, 7.0) == 0.0        # the sizing read deletes it
    end

    # ── A8. Bounds: no Betz clamp fires, and the peak is the peak.
    @testset "A8 bounds" begin
        top = 0.0
        for n in 3:9
            lambda = 0.0
            while lambda <= 12.0
                c = cp_read(n, lambda)
                top = max(top, c)
                lambda += 0.01
            end
        end
        @test top < 16/27
        @test isapprox(top, 0.323635; atol = 5e-4)   # n = 4 at 4.2, not a clamped 0.5926
    end

    # ── A9. The sizing design point keeps its signed ratios.
    @testset "A9 design-point ratios at 4.1" begin
        base = cp_at_tsr(4.1)
        for (n, ratio) in ((3, 1.0000), (4, 1.0821), (5, 1.0756), (6, 1.0261),
                           (7, 0.9575), (8, 0.8813), (9, 0.8031))
            @test isapprox(cp_read(n, 4.1) / base, ratio; atol = 5e-4)
        end
    end

    # ── A10. One axis at a time: CT does not move in this change.
    @testset "A10 CT stays on the anchor" begin
        for lambda in (3.0, 4.1, 5.2, 6.8415)
            @test BEM.ct_bem(3, lambda) ≈ ct_at_tsr(lambda) rtol = 1e-12
        end
        for src in ("src/ring_forces.jl", "src/initialization.jl")
            @test occursin("ct_at_tsr(", read(joinpath(@__DIR__, "..", src), String))
        end
    end

    # ── A11. The implementation gate. RED until `cp_ode` lands.
    @testset "A11 cp_ode is implemented and the ODE uses it" begin
        @test isdefined(BEM, :cp_ode)
        if isdefined(BEM, :cp_ode)
            for (n, lambda) in ((4, 6.8415), (6, 7.0), (9, 10.5), (3, 6.8415))
                @test BEM.cp_ode(n, lambda) == ref_cp_ode(n, lambda)
            end
        end
        # the clamped sizing read must not reach the ODE torque path
        @test !occursin("cp_bem", read(joinpath(@__DIR__, "..", "src", "ring_forces.jl"), String))
        @test !occursin("cp_bem", read(joinpath(@__DIR__, "..", "src", "sim_frame.jl"), String))
        @test !occursin("cp_bem", read(joinpath(@__DIR__, "..", "src", "initialization.jl"), String))
    end

end
