# test/test_fitness_appropriateness_2026_09.jl
# Unit tests for appropriate_mass_fitness (T3, 2026-09-02).
#
# "Good" now means light AND appropriate AND safe:
#   - light:           mass is still the base of the score
#   - appropriate:     P > p_ceiling_kw is penalised (no over-rated machine)
#   - safe:            FoS close to fos_hard (little margin) and twist_ratio
#                      near 1 (approaching collapse) are both penalised
#
# These tests check RELATIVE ordering (not exact penalty magnitudes), so the
# PLACEHOLDER weights in src/objective_v12.jl can be tuned without breaking them.

using Test, KiteTurbineDynamics

# 5 kW campaign config (matches the runner: floor and ceiling both 5 kW,
# hard FoS floor 2.5).
const CFG = ObjectiveConfig(; p_floor_kw=5.0, p_ceiling_kw=5.0,
                            fos_target=2.5, fos_hard=2.5)

@testset "appropriate_mass_fitness — hard reject gates unchanged" begin
    # FoS below the floor → reject.
    @test KiteTurbineDynamics.appropriate_mass_fitness(5.0, 2.4, CFG, 50.0) == Inf
    # Power below the floor → reject.
    @test KiteTurbineDynamics.appropriate_mass_fitness(4.9, 5.0, CFG, 50.0) == Inf
    # Non-finite FoS → reject (exploit-register row 1 class).
    @test KiteTurbineDynamics.appropriate_mass_fitness(5.0, Inf, CFG, 50.0) == Inf
    @test KiteTurbineDynamics.appropriate_mass_fitness(5.0, NaN, CFG, 50.0) == Inf
end

@testset "appropriate_mass_fitness — over-power penalty (a)" begin
    at_rated = KiteTurbineDynamics.appropriate_mass_fitness(5.0, 5.0, CFG, 50.0)
    over     = KiteTurbineDynamics.appropriate_mass_fitness(6.0, 5.0, CFG, 50.0)
    # A machine making more than rated power scores WORSE at equal mass.
    @test over > at_rated
    # Monotonic: more excess → worse.
    over_more = KiteTurbineDynamics.appropriate_mass_fitness(7.0, 5.0, CFG, 50.0)
    @test over_more > over
    # At or below the ceiling there is no over-power penalty.
    below = KiteTurbineDynamics.appropriate_mass_fitness(5.0, 5.0, CFG, 50.0)
    @test below == at_rated
end

@testset "appropriate_mass_fitness — beam-utilisation penalty (b)" begin
    low_margin  = KiteTurbineDynamics.appropriate_mass_fitness(5.0, 2.6, CFG, 50.0)   # FoS close to 2.5
    high_margin = KiteTurbineDynamics.appropriate_mass_fitness(5.0, 10.0, CFG, 50.0)  # comfortable FoS
    # A design with little safety margin scores WORSE at equal mass and power.
    @test low_margin > high_margin
    # Monotonic: the margin penalty shrinks as FoS grows.
    huge_margin = KiteTurbineDynamics.appropriate_mass_fitness(5.0, 100.0, CFG, 50.0)
    @test high_margin > huge_margin
end

@testset "appropriate_mass_fitness — over-twist penalty (c)" begin
    no_twist   = KiteTurbineDynamics.appropriate_mass_fitness(5.0, 5.0, CFG, 50.0; twist_ratio=0.0)
    near_twist = KiteTurbineDynamics.appropriate_mass_fitness(5.0, 5.0, CFG, 50.0; twist_ratio=0.9)
    # A design approaching the twist-crossing limit scores WORSE than one with
    # no twist, at equal mass and power.
    @test near_twist > no_twist
    # Monotonic: the penalty grows as twist_ratio approaches 1.
    mid_twist  = KiteTurbineDynamics.appropriate_mass_fitness(5.0, 5.0, CFG, 50.0; twist_ratio=0.5)
    @test near_twist > mid_twist
    @test mid_twist > no_twist
end

@testset "appropriate_mass_fitness — zero penalties collapse to mass" begin
    # At the ceiling, huge FoS, and zero twist, all penalties → 0, so the
    # fitness is just the mass.  (FoS 1e9 makes the utilisation term ~1e-18.)
    f = KiteTurbineDynamics.appropriate_mass_fitness(5.0, 1.0e9, CFG, 50.0; twist_ratio=0.0)
    @test f ≈ 50.0 atol=1e-6
end
