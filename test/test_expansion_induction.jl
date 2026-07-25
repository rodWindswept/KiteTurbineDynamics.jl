# test/test_expansion_induction.jl
# Acceptance tests for the per-annulus induction fixed point + α model
# (docs/plans/induction_fix_proposal.md, amended 2026-07-18).
#
# Test 1: Betz cap + solver convergence (property test over ω × v × λ grid)
# Test 2: light-loading continuity to legacy model + design-point CL exactness
# Test 3: Daisy rotor exercises the model (non-vacuous) — full ±5% calibration
#         re-run is a validation-phase script gate, not a unit test
# Test 4 (script gate): energy balance in wind_sweep_triangle3_90s rerun —
#         v1 bound is Σ per-annulus Betz (NOT union-Betz; wake coupling is v2)
# Plus: FR4 bit-identity — N_expansion=0 systems are unaffected by the toggle.

using Test, LinearAlgebra
using KiteTurbineDynamics
import KiteTurbineDynamics: ExpansionRotorParams, expansion_rotor_forces,
    solve_expansion_induction, expansion_cl, set_expansion_physics!,
    expansion_physics, LEGACY_PHYSICS_PRE_2026_07_18, ExpansionPhysics, expansion_annulus_area,
    EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
    EXP_CL_SLOPE, EXP_CL_MAX, EXP_PHI_DESIGN, EXP_THETA_I

const RHO = 1.225

# Representative rotors (from committed geometry fingerprints)
# triangle3 λ=0.85 rotor1: ring r≈2.99, 3 blades, tip 2.37, hub -1.016, c 0.383, bank 18°
tri_rotor(λ) = ExpansionRotorParams(3, 2.37*λ/0.85, -1.016*λ/0.85, 0.383*λ/0.85,
    EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED, 18.0, 0.33, 20, 1.0)
# 12-gon λ=0.85 rotor3: ring r≈2.0–2.9, 12 blades, tip 2.09, hub -0.9, c 0.338, bank 25°
gon_rotor(λ) = ExpansionRotorParams(12, 2.091*λ/0.85, -0.896*λ/0.85, 0.338*λ/0.85,
    EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED, 25.0, 0.51, 12, 1.0)

@testset "expansion induction" begin

    _prev_induction = expansion_physics().induction

    # ── Test 1: Betz cap + solver convergence ────────────────────────────
    @testset "Betz cap + convergence (property grid)" begin
        set_expansion_physics!(ExpansionPhysics(true, true, true))
        for (er, rnom) in ((tri_rotor(0.69), 2.99), (tri_rotor(0.85), 2.99), (tri_rotor(1.0), 2.99),
                           (gon_rotor(0.69), 2.4),  (gon_rotor(0.85), 2.4),  (gon_rotor(1.0), 2.4)),
            ω in (1.0, 2.0, 5.0, 10.0, 20.0, 30.0, 45.0, 60.0),
            v in (5.0, 8.0, 11.0, 15.0)

            a, converged, iters, resid = solve_expansion_induction(er, RHO, v, ω, 30.0, rnom)
            @test converged                      # non-convergence FAILS (no silent clamp)
            @test 0.0 <= a <= 0.5
            @test iters <= 80

            F_r, F_ax, τ, r_eff, ωr = expansion_rotor_forces(er, RHO, v, ω, 30.0, rnom, 20_000.0, er.n_blades == 3 ? 3 : 12)
            v_ax = v * cosd(30.0)
            A_ann = expansion_annulus_area(er, rnom)
            P_betz = 0.593 * 0.5 * RHO * A_ann * v_ax^3
            P_shaft = max(τ, 0.0) * ω
            @test P_shaft <= P_betz * 1.05       # per-annulus Betz cap (5% num. tol.)
        end
    end

    # ── Test 2: light-loading continuity + design-point CL exactness ─────
    @testset "continuity + design point" begin
        # design-point CL is exact by construction of θ_i
        @test expansion_cl(EXP_PHI_DESIGN) ≈ EXP_CL_DESIGN atol=1e-12
        @test EXP_THETA_I ≈ EXP_PHI_DESIGN - EXP_CL_DESIGN / EXP_CL_SLOPE atol=1e-12

        # tiny-solidity rotor at design inflow: a→0 and forces → legacy within 1%
        er = ExpansionRotorParams(3, 2.37, -1.016, 0.001,  # 1 mm chord
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED, 18.0, 0.33, 20, 1.0)
        rnom = 2.99
        v = 11.0
        v_ax = v * cosd(30.0)
        bank = deg2rad(18.0)
        r_mean = rnom + (er.blade_hub_radius + er.blade_tip_radius)/2 * cos(bank)
        ω = 3.0 * v_ax / r_mean       # annulus TSR 3 → φ = φ_design exactly

        a, converged, _, _ = solve_expansion_induction(er, RHO, v, ω, 30.0, rnom)
        @test converged
        @test a < 0.01

        set_expansion_physics!(ExpansionPhysics(true, true, true))
        F_r1, F_a1, τ1, _, _ = expansion_rotor_forces(er, RHO, v, ω, 30.0, rnom, 20_000.0, 3)
        set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)
        F_r0, F_a0, τ0, _, _ = expansion_rotor_forces(er, RHO, v, ω, 30.0, rnom, 20_000.0, 3)
        @test isapprox(F_r1, F_r0; rtol=0.01)
        @test isapprox(F_a1, F_a0; rtol=0.01)
        @test isapprox(τ1,  τ0;  rtol=0.01)
    end

    # ── Test 3: Daisy path is non-vacuous and momentum-bounded ───────────
    @testset "Daisy rotor exercises the model" begin
        # daisy_builder.jl models Daisy's main rotor as ExpansionRotorParams —
        # verify the induction path runs on it and respects Betz.
        # (Full ±5% Bergey-Cp calibration re-run = validation-phase script gate.)
        daisy_er = ExpansionRotorParams(5, 0.7*1.55, -0.3*1.55, 0.113*1.55,
            1.0, 0.02, 0.05, 0.0, 0.5, 24, 1.0)
        set_expansion_physics!(ExpansionPhysics(true, true, true))
        for ω in (5.0, 10.0, 15.0, 20.0), v in (6.0, 10.0)
            a, converged, _, _ = solve_expansion_induction(daisy_er, RHO, v, ω, 30.0, 0.0)
            @test converged
            _, _, τ, _, _ = expansion_rotor_forces(daisy_er, RHO, v, ω, 30.0, 0.0, 5_000.0, 5)
            A_ann = expansion_annulus_area(daisy_er, 0.0)
            @test max(τ, 0.0) * ω <= 0.593 * 0.5 * RHO * A_ann * (v*cosd(30.0))^3 * 1.05
        end
    end

    # ── FR4: N_expansion=0 bit-identity, toggle-independent ──────────────
    @testset "FR4: no expansion rotors → toggle inert" begin
        p = params_v5_50kw()
        wf(pos, t) = [0.0, 0.0, 0.0]   # gravity-only: benign, no NaN transients
        # fresh system per run — run_canonical_sim! mutates sys internals,
        # so sharing one sys would alias state across the toggle branches
        set_expansion_physics!(ExpansionPhysics(true, true, true))
        sysA, u0A = build_kite_turbine_system(p)
        @test isempty(sysA.expansion_rotors)
        uA = copy(u0A); run_canonical_sim!(uA, sysA, p, wf, 50, 0.002; lift_device=nothing)
        set_expansion_physics!(LEGACY_PHYSICS_PRE_2026_07_18)
        sysB, u0B = build_kite_turbine_system(p)
        uB = copy(u0B); run_canonical_sim!(uB, sysB, p, wf, 50, 0.002; lift_device=nothing)
        @test isequal(uA, uB)                     # bit-for-bit (NaN-safe)
    end

    set_expansion_physics!(_prev_induction ? ExpansionPhysics(true, true, true) : LEGACY_PHYSICS_PRE_2026_07_18)
end

println("\n✓ expansion induction acceptance tests complete")
