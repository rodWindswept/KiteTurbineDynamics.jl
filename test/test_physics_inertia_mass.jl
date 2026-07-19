# test/test_physics_inertia_mass.jl
# Acceptance tests for Gate 2b — blade inertia (axis-radius rod integral) and
# mass-fix semantics (legacy total treated as correct for 3-blade era; scaled
# to n_blades for other configurations).  Rod's advisor corrections 2026-07-18.
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
        # Daisy blade: tip=0.7, hub=-0.3 (blade-local offsets), n=3, m_per_blade≈0.5 kg,
        # r_nominal=1.52 → r₂=2.22, r₁=1.22
        m_blade = (0.3 + 0.1*0.7) * 1.0^3  # blade_scale=1.0 → 0.37 kg per assembly total
        m_per_blade = m_blade / 3           # ~0.123 kg each
        er = ExpansionRotorParams(3, 0.7, -0.3, 0.113*1.55, 1.0, 0.02, 0.05, 28.0, m_blade, 5, 1.0)
        J = expansion_rotor_inertia(er, 1.52)
        r₁ = 1.52 + (-0.3); r₂ = 1.52 + 0.7
        J_expected = 3 * m_per_blade * (r₂^2 + r₂*r₁ + r₁^2) / 3
        @test J ≈ J_expected atol=1e-12
        # Plausibility: a ~1 kg blade ring at ~1.5 m radius should have O(kg·m²), not O(0.1).
        @test J > 0.5
        @test J < 10.0
    end

    # ── Mass-fix semantics: Daisy invariance ─────────────────────────────
    @testset "mass: Daisy invariant by construction" begin
        # Choice (Rod, 2026-07-18): legacy (0.3+0.1·tip)·λ³ is the CORRECT TOTAL
        # for the 3-blade era it was calibrated in. m_per_blade = legacy / n_blades.
        # Daisy (3 blades) is invariant; a 12-blade assembly gets (12/3)×legacy.
        er3 = ExpansionRotorParams(3,  0.7, -0.3, 0.3, 1.0, 0.02, 0.05, 15.0, 0.5, 3, 1.0)
        er12 = ExpansionRotorParams(12, 0.7, -0.3, 0.3, 1.0, 0.02, 0.05, 15.0, 0.5, 3, 1.0)

        set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)
        m_leg_3blade = expansion_blade_mass(0.7, 1.0)

        set_expansion_physics!(ExpansionPhysics(true, true, true))
        m_fix_3blade = expansion_blade_mass(0.7, 1.0, 3)
        m_fix_12blade = expansion_blade_mass(0.7, 1.0, 12)

        # Daisy (3-blade) unchanged
        @test m_fix_3blade ≈ m_leg_3blade atol=1e-12
        # 12-blade = 4× the Daisy-era total
        @test m_fix_12blade ≈ 4 * m_leg_3blade atol=1e-12
    end

    # ── Mass: non-default blade_scale ────────────────────────────────────
    @testset "mass: blade_scale 0.85 (triangle3)" begin
        set_expansion_physics!(ExpansionPhysics(true, true, true))
        m_triangle = expansion_blade_mass(2.37/0.85*0.85, 0.85, 3)  # tip=2.37 at λ=0.85
        m_leg = (0.3 + 0.1*2.37) * 0.85^3
        @test m_triangle ≈ m_leg atol=1e-12
    end

    set_expansion_physics!(_prev)
end

println("\n✓ Gate 2b acceptance tests complete")
