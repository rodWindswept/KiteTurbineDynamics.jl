# test/test_trpt_realisability.jl
#
# Guard for the TRPT torsional realisability cliff (2026-09-13).
#
# The transmission can only carry so much torque at a given line tension: the
# torsional constitutive law is
#
#     τ = n_lines · T_s · r_a · r_b · sin(Δα) / chord,
#
# so a segment demanded to carry τ at tension T has a REQUIRED
#
#     sin Δα = τ · chord / (n_lines · T_s · r_a · r_b).
#
# `sin Δα > 1` is past the cliff: no twist transmits that torque.  The initialiser
# used to write `asin(clamp(sinΔα, -1, 1))`, which silently saturated Δα at 90°.
# Measured 2026-09-13 (scratch/diag_twist_origin.jl), the two non-seed variants in
# `test_settle_preload_consistency.jl` were BOTH past the cliff and were placed as
# multi-turn wind-ups — 4 segments × 90° (a full turn) at n_lines=4/3 rotors, and
# 12 × 90° (three turns) at n_lines=6/1 rotor — while every guard passed, because
# the tension is still self-consistent at whatever Δα was chosen.  The preload
# guard cannot see this; the twist gate (`> 30°`) passes 90°.  Hence this file.
#
# `physics-topology.md` §6: when a physical precondition cannot be met, RAISE.
#
# TWO LAYERS, tested separately:
#   1. the SEAM (`trpt_matched_place`) refuses an over-cliff design point;
#   2. `design_axial_preload` raises the preload until every segment clears the
#      floor by `TRPT_REALISABILITY_TENSION_MARGIN`, so the pipeline's own seeds
#      are not sitting on the cliff.  Measured before that margin existed: the
#      seed family sat within ~3 % of the cliff and several designs were past it.
#
# The campaign seed is realisable but was TIGHT — the handover's table puts the
# binding segment at Δα ≈ 79.4°, 10.6° from the 90° collapse.  That margin is
# asserted here as an angle, not as "+N N above a floor".
#
# RE-BASELINED 2026-09-16 (second time).  The SIZING MODEL moved, not the genome:
# `HELIX_LOAD_FACTOR` 0.32 -> 1.2 (the 0.32 was a stale pre-re-seed calibration)
# and `MIN_RING_DO_M` = 10 mm.  The tubes are now thicker, so ring mass, the
# lifter floor and every tension-derived number moved with them.  The pins below
# are re-measured on this fixture.  The design IMPROVED on every axis: demand[4]
# 0.983 -> 0.9531, binding twist 79.4° -> 72.99°, cliff margin 15° -> 17.01°,
# τ_carry[8] 238.2 -> 235.35.  As in the 2026-09-16 re-seed re-baseline above,
# this is a recorded improvement, NOT a regression.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "settle_case_builders.jl"))

# Measured operating points (rad/s).  OMEGA_SEED is the campaign seed's own
# equilibrium ω — the constant `lift_chain_design` used to hardcode as its
# fallback, removed 2026-09-13.  The other two come from
# .julia_depot/logs/dsh_twist_origin.log.
const OMEGA_SEED = 12.983466
const OMEGA_4L3R = 13.399535
const OMEGA_6L1R = 11.398798

# ── FROZEN GENOME (2026-09-16, Rod) ─────────────────────────────────────────
# This file reproduces INDEPENDENTLY MEASURED numbers (the 2026-09-13 handover's
# table: binding segment 4, demand[1] ~ 0.974, demand[4] ~ 0.983, twist 79.4°,
# τ_carry[7] ~ 329.9, τ_carry[8] ~ 238.2).  Those are properties of ONE design
# point, so the test must PIN that design rather than inherit the campaign seed.
#
# It previously called `build_case(nothing, nothing)`, which tracks
# `seed_genome(5.0)`.  The 2026-09-16 L/r 2.0 -> 1.5 re-seed then moved the
# binding segment from 4 to 8 and every pinned value with it, turning 13 green
# assertions red for a change that IMPROVED the design (demand 0.974 -> 0.7357,
# twist 79.4° -> 47.7°).  That was a test-coupling defect, not a regression.
#
# This is `seed_genome(5.0)` as measured at the L/r 2.0 campaign seed.  It is a
# FIXTURE: do not update it when the campaign seed moves.  Values are written out
# literally so a change in `params_daisy`/`DAISY` scaling cannot silently move it.
const SEED_LR20 = [2.4, 0.5751086854, 2.0, 6.0, 0.0, 3.0, 0.0, 0.0, 0.7, 0.7]

@testset "TRPT realisability — the matched-place solve must refuse the cliff" begin
    # ── A. the seam reproduces the handover's table (margin DISABLED) ────────
    # `realisability_margin=1.0` turns off the preload floor enforcement, so this
    # is the UNMARGINED design point — exactly what the handover's independently
    # cross-validated table describes.  Reproducing it is the check that the seam
    # is behaviour-preserving, not a re-derivation.  (scoped: the constant is a
    # documented design constraint, so the enforced result differs by design.)
    sys, u0, pc, lift, wf = build_case(nothing, nothing; genome=SEED_LR20)
    F_ax = design_axial_preload(
        sys, pc, lift, u0; omega_eq=OMEGA_SEED, realisability_margin=1.0
    )
    τ_eq = sys.k_mppt_ref[] * OMEGA_SEED^2
    r = trpt_matched_place(sys, pc, F_ax, τ_eq, OMEGA_SEED, wf)

    @test length(r.demand) == sys.n_ring - 1
    @test all(r.demand .>= 0.0)
    @test maximum(r.demand) < 1.0                  # realisable at the design point
    @test argmax(r.demand) == 4                    # binding segment (handover §5)
    @test r.demand[1] ≈ 0.9416 atol = 5e-3
    @test r.demand[4] ≈ 0.9531 atol = 5e-3
    @test rad2deg(asin(r.demand[4])) ≈ 72.99 atol = 0.5
    # Demand falls going up the shaft because each rotor injects its own torque:
    # segs 1-6 carry the generator load, seg 7 carries it less the ring-7
    # expansion rotor, seg 8 less that again.
    @test r.τ_carry[7] ≈ 329.9 atol = 2.0
    @test r.τ_carry[8] ≈ 235.35 atol = 2.0
    @test r.demand[7] ≈ 0.1975 atol = 5e-3
    @test r.demand[8] ≈ 0.1421 atol = 5e-3
    # The margin is a DESIGN CONSTRAINT to widen, and on the unmargined design it
    # is tight: state it as an angle.
    margin_deg = 90.0 - rad2deg(asin(maximum(r.demand)))
    @test margin_deg > 0.0
    @test margin_deg ≈ 17.01 atol = 0.1     # pinned (re-baselined 2026-09-16)
    @test margin_deg < 20.0                 # still tight against the cliff

    # ── A2. the SHIPPED design clears the floor by the stated margin ─────────
    m = KiteTurbineDynamics.TRPT_REALISABILITY_TENSION_MARGIN
    @test m > 1.0
    F_ship = design_axial_preload(sys, pc, lift, u0; omega_eq=OMEGA_SEED, wind_fn=wf)
    r_ship = trpt_matched_place(sys, pc, F_ship, τ_eq, OMEGA_SEED, wf)
    # The physical guarantee is the strict inequality against the cliff; the
    # design margin is met to floating-point rounding (the loop compares against
    # `1/m` exactly, so the last accepted step can sit 1 ulp above it).
    @test maximum(r_ship.demand) < 1.0
    @test maximum(r_ship.demand) <= (1.0 / m) * (1.0 + 1e-9)
    # Enforcement may only RAISE the preload, and only the top tension is scaled
    # (the ring-weight increments are physical).
    @test all(F_ship .>= F_ax)

    # ── B. the seam still REFUSES an over-cliff design point ────────────────
    for (nl, rc, ω) in ((4, 3.0, OMEGA_4L3R), (6, 1.0, OMEGA_6L1R))
        sys2, u02, pc2, lift2, wf2 = build_case(nl, rc; genome=SEED_LR20)
        F2 = design_axial_preload(
            sys2, pc2, lift2, u02; omega_eq=ω, wind_fn=wf2, realisability_margin=1.0
        )
        τ2 = sys2.k_mppt_ref[] * ω^2
        # Measure the demand (this is what the old clamp hid)...
        d = trpt_matched_place(sys2, pc2, F2, τ2, ω, wf2; raise_on_unrealisable=false)
        @test maximum(d.demand) > 1.0
        # ...and the default must refuse rather than place a wind-up.
        @test_throws ErrorException trpt_matched_place(sys2, pc2, F2, τ2, ω, wf2)
    end

    # ── C. end-to-end: the preload floor REPAIRS those designs ──────────────
    # Before the margin existed the settle raised on this machine.  With it, the
    # settle succeeds and its placement clears the floor.
    sys3, u03, pc3, lift3, wf3 = build_case(4, 3.0; genome=SEED_LR20)
    u3 = settle_to_operational_state(
        sys3, copy(u03), pc3, 60.0; lift_device=lift3, wind_fn=wf3, n_op=2_000
    )
    N3, Nr3 = sys3.n_total, sys3.n_ring
    ω3 = u3[6N3 + Nr3 + 1]
    F3 = design_axial_preload(sys3, pc3, lift3, u03; omega_eq=ω3, wind_fn=wf3)
    p3 = trpt_matched_place(sys3, pc3, F3, sys3.k_mppt_ref[] * ω3^2, ω3, wf3)
    @test maximum(p3.demand) < 1.0
    @test maximum(p3.demand) <= (1.0 / m) * (1.0 + 1e-9)

    # ── D. the preload is evaluated at the CALLER's ω ───────────────────────
    # `lift_chain_design` used to substitute 12.983466 — the seed's own ω —
    # whenever `omega_eq <= 0`, which made ω = 0 (a non-rotating rotor) both
    # unrepresentable and silently borrowed another design's speed.
    sys4, u04, pc4, lift4, _ = build_case(6, 1.0; genome=SEED_LR20)
    hub4 = u04[(3 * (sys4.rotor.node_id - 1) + 1):(3 * sys4.rotor.node_id)]
    d0 = KiteTurbineDynamics.lift_chain_design(sys4, pc4, lift4, hub4; omega_eq=0.0)
    dop = KiteTurbineDynamics.lift_chain_design(sys4, pc4, lift4, hub4; omega_eq=OMEGA_6L1R)
    @test d0.T_thrust == 0.0                       # ct_at_tsr(0.0) == 0.0 exactly
    @test dop.T_thrust > 0.0
    @test d0.T_top < dop.T_top                     # no rotation -> no thrust term
end
