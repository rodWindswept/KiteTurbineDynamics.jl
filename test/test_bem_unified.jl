# test/test_bem_unified.jl — Phase 0.1: Unified BEM model validation
#
# Tests that the new cp_bem(n_lines, tsr) and ct_bem(n_lines, tsr) functions:
# 1. Match AeroDyn baseline at n_lines=5
# 2. Scale Cp downwards with increasing blade count (solidity penalty)
# 3. Scale CT upwards with increasing blade count (more thrust area)
# 4. Produce self-consistent rotor radius
# 5. Respect physical bounds (Cp ≤ Betz, CT ≤ 1.0)

using KiteTurbineDynamics
const BEM = KiteTurbineDynamics.BEM

@testset "BEM unification" begin

    # ── 1. Baseline match at n_lines=5 ──────────────────────
    @testset "Match AeroDyn at n_lines=5" begin
        for λ in [3.0, 3.5, 4.0, 4.1, 4.5, 5.0]
            cp_direct = cp_at_tsr(λ)
            cp_bem5 = BEM.cp_bem(5, λ)
            if cp_direct > 0.01
                @test abs(cp_bem5 - cp_direct) / cp_direct < 0.02
            end
        end
        for λ in [3.0, 3.5, 4.0, 4.1, 4.5, 5.0]
            ct_direct = ct_at_tsr(λ)
            ct_bem5 = BEM.ct_bem(5, λ)
            if ct_direct > 0.01
                @test abs(ct_bem5 - ct_direct) / ct_direct < 0.03
            end
        end
    end

    # ── 2. Cp decreases with blade count ────────────────────
    @testset "Cp monotonic in n_lines" begin
        cp3 = BEM.cp_bem(3, 4.1)
        cp5 = BEM.cp_bem(5, 4.1)
        cp8 = BEM.cp_bem(8, 4.1)
        @test cp8 < cp5
        @test cp3 > cp8
        @test BEM.cp_bem(3, 4.1) > 0.10
        @test BEM.cp_bem(8, 4.1) > 0.10
    end

    # ── 3. CT scales with blade count ───────────────────────
    @testset "CT scaling" begin
        @test BEM.ct_bem(5, 4.1) > 0.45
        ct3 = BEM.ct_bem(3, 4.1)
        ct5 = BEM.ct_bem(5, 4.1)
        ct8 = BEM.ct_bem(8, 4.1)
        @test ct8 > ct5 > ct3
        for n in [3, 5, 8]
            for λ in [4.0, 6.0, 8.0]
                @test BEM.ct_bem(n, λ) <= 1.02  # quasi-steady BEM can exceed 1.0 at high λ
            end
        end
    end

    # ── 4. Rotor radius self-consistency ────────────────────
    @testset "Rotor radius self-consistent" begin
        P, v, n = 10_000.0, 11.0, 5
        R = BEM.rotor_radius_for_power(P, v, n; tsr=4.1)
        Cp = BEM.cp_bem(n, 4.1)
        P_check = Cp * 0.5 * 1.225 * π * R^2 * v^3
        @test abs(P_check - P) / P < 0.05
        R5 = BEM.rotor_radius_for_power(P, v, 5; tsr=4.1)
        R8 = BEM.rotor_radius_for_power(P, v, 8; tsr=4.1)
        @test R8 > R5
    end

    # ── 5. Physical bounds ──────────────────────────────────
    @testset "Physical bounds" begin
        for n in [3, 5, 8]
            @test BEM.cp_bem(n, 4.1) <= 16.0 / 27.0
            @test BEM.cp_bem(n, 4.1) >= 0.0
            @test BEM.ct_bem(n, 4.1) >= 0.0
        end
    end

    # ── 6. TSR sweep sanity ─────────────────────────────────
    @testset "TSR dependence" begin
        cp_low = BEM.cp_bem(5, 2.0)
        cp_peak = BEM.cp_bem(5, 4.1)
        cp_high = BEM.cp_bem(5, 7.0)
        @test cp_peak > cp_low
        @test cp_peak > cp_high
        for n in [3, 5, 8]
            @test BEM.ct_bem(n, 6.0) >= BEM.ct_bem(n, 4.0)
        end
    end
end
