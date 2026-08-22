# test/test_physics_inertia_mass.jl
# Acceptance tests for Gate 2b — blade inertia (axis-radius rod integral).
# Blade-mass expectations follow the UNIFIED volume law (2026-08-22, Rod):
# m_assembly = n_blades · m_ref · λ³ with m_ref = 0.420 kg (measured Daisy
# blade) — replaces the CFRP (0.3+0.1·tip)·λ³ constants and the corrected_mass
# era toggle.  See docs/plans/2026-08-22-blade-mass-volume-law.md.
using Test, LinearAlgebra
using KiteTurbineDynamics
import KiteTurbineDynamics: ExpansionRotorParams, ExpansionPhysics,
    expansion_rotor_inertia, expansion_blade_mass,
    set_expansion_physics!, expansion_physics,
    LEGACY_PHYSICS_PRE_2026_07_18

@testset "Gate 2b: inertia + mass fix" begin

    _prev = expansion_physics()

    # ── Inertia: regularity + regression guard ───────────────────────────
    @testset "inertia: rod-integral property + regression guard" begin
        # Test 1: analytic rod integral
        er = ExpansionRotorParams(3, 1.5, 0.5, 0.3, 1.0, 0.02, 0.05, 15.0, 2.0, 3, 1.0)
        J = expansion_rotor_inertia(er, 2.5)
        m_per = er.mass / 3
        r₁ = 2.5 + 0.5; r₂ = 2.5 + 1.5
        J_expected = 3 * m_per * (r₂^2 + r₂*r₁ + r₁^2) / 3
        @test J ≈ J_expected atol=1e-12

        # Test 2: regression guard — the offset-only approximation (r₂²−r₁²)/2
        # overstates J for narrow blades, understates it for wide spans. Any
        # reversion to the wrong formula shifts J measurably.
        J_wrong = 3 * m_per * (r₂^2 - r₁^2) / 2
        @test abs(J - J_wrong) > 1e-9            # formulas are not identical
        @test J / J_wrong > 0.5                  # same order of magnitude
    end

    # ── Inertia: Daisy-specific plausibility check ──────────────────────
    @testset "inertia: Daisy rotor is physically plausible" begin
        # Daisy blade: tip=0.7, hub=-0.3 (blade-local offsets), n=3,
        # r_nominal=1.52 → r₂=2.22, r₁=1.22.  Assembly mass under the unified
        # λ³ law at λ=1: 3 × 0.420 = 1.26 kg → m_per_blade = 0.420 kg.
        m_blade = expansion_blade_mass(0.7, 1.0, 3)   # 1.26 kg assembly
        m_per_blade = m_blade / 3                     # 0.420 kg each
        er = ExpansionRotorParams(3, 0.7, -0.3, 0.113*1.55, 1.0, 0.02, 0.05, 28.0, m_blade, 5, 1.0)
        J = expansion_rotor_inertia(er, 1.52)
        r₁ = 1.52 + (-0.3); r₂ = 1.52 + 0.7
        J_expected = 3 * m_per_blade * (r₂^2 + r₂*r₁ + r₁^2) / 3
        @test J ≈ J_expected atol=1e-12
        # Plausibility: a ~1.3 kg blade ring at ~1.5 m radius should have O(kg·m²)
        @test J > 0.5
        @test J < 10.0
    end

    # ── Mass: unified volume law (2026-08-22) ────────────────────────────
    @testset "mass: unified λ³ law, measured anchor" begin
        # Daisy 3-blade assembly at λ=1: 3 × 420 g = 1.26 kg (measured)
        m3 = expansion_blade_mass(0.7, 1.0, 3)
        @test m3 ≈ 3 * 0.420 atol=1e-12
        # 12-blade assembly = 12 × 0.420 = 5.04 kg
        m12 = expansion_blade_mass(0.7, 1.0, 12)
        @test m12 ≈ 12 * 0.420 atol=1e-12
        # the era toggle no longer affects the law
        set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)
        @test expansion_blade_mass(0.7, 1.0, 3) ≈ m3 atol=1e-12
        set_expansion_physics!(ExpansionPhysics(true, true))
        @test expansion_blade_mass(0.7, 1.0, 3) ≈ m3 atol=1e-12
    end

    # ── Mass: non-default blade_scale ────────────────────────────────────
    @testset "mass: blade_scale 0.85 (triangle3)" begin
        # volume law: 3 × 0.420 × 0.85³ (the old CFRP comparison is dead —
        # (0.3 + 0.1·tip)·λ³ was rejected for rigid foam)
        m_triangle = expansion_blade_mass(2.37/0.85*0.85, 0.85, 3)  # tip=2.37 at λ=0.85
        @test m_triangle ≈ 3 * 0.420 * 0.85^3 atol=1e-12
    end

    set_expansion_physics!(_prev)
end

println("\n✓ Gate 2b acceptance tests complete")
