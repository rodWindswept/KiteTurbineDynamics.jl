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
# RE-BASELINED 2026-09-22 (fourth time), for the EXPANSION-THRUST profile fix.
# `design_axial_preload` accumulated only the ring WEIGHT going down the shaft, so
# the axial thrust of every expansion rotor was missing from the preload profile
# (the 2026-09-12 fault-ledger entry "Hub axial budget counted only the thrust of
# the main rotor. Wrong by 6.6x").  Every segment below an expansion rotor was
# therefore under-tensioned, which INFLATED its twist demand.  The profile now adds
# each rotor's thrust at the segment immediately below its own ring:
#
#     S_{r-1} = S_r + F_r − W_r·sinβ        (axial free body of ring r)
#
# so Section B's `T_top` stays MAIN-ROTOR-ONLY (the expansion rotors sit below the
# Section-B cut) and `F_ax[end]` is unchanged at 1163.72 N.
#
# CONSEQUENCE — the fixture is no longer over the cliff.  It read demand 1.1276 /
# crossing 1.4716 under the omission, and `design_axial_preload` refused it as
# unrepairable at >1.5x the bare preload.  With the thrust included it reads
# demand 0.8671 / crossing 0.8959 and the floor REPAIRS it inside the cap.
# **The 2026-09-16 re-seed away from L/r 2.0 was motivated in part by that
# refusal, so the citation for it in this file is now superseded and is flagged
# for Rod rather than silently rewritten.**  See DECISIONS.md [2026-09-22].
#
# Section A's fixture (SEED_LR20) is an L/r = 2.0 campaign seed.  Until 2026-09-20
# `lift_chain_design` projected the whole sky-anchor load onto the cyan line (the
# back line solved as SLACK), which OVER-predicted T_cyan by 73 % and T_top by
# 188 N.  With the taut 2x2 (245.5 N cyan / 320.2 N back) the L/r 2.0 machine's
# top tension drops below the torsional-realisability floor.
#
# The floor also gained a second, TIGHTER criterion (2026-09-20): the discrete
# geometric crossing limit δα* = 2·asin(L/√(2(L²+2r²))), which
# `objective_evaluator.jl` gates the ODE window on.  The continuum sin law only
# bites at Δα = 90°, so a demand-only check could declare headroom on a machine
# whose lines had already crossed (campaign seed: demand 0.8565 at crossing ratio
# 1.0911).
#
# This fixture stays FROZEN: do not update it when the seed moves.  Re-baseline
# only for a physics correction, and say which one (as above).

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
    # is the design as the taut split sizes it, with no rescue.
    sys, u0, pc, lift, wf = build_case(nothing, nothing; genome=SEED_LR20)
    F_ax = design_axial_preload(
        sys, pc, lift, u0; omega_eq=OMEGA_SEED, realisability_margin=1.0
    )
    τ_eq = sys.k_mppt_ref[] * OMEGA_SEED^2
    # `raise_on_unrealisable=false`: the point is genuinely over the cliff, so the
    # default would (correctly) refuse it.  The DIAGNOSTIC is what is under test.
    r = trpt_matched_place(sys, pc, F_ax, τ_eq, OMEGA_SEED, wf; raise_on_unrealisable=false)

    @test length(r.demand) == sys.n_ring - 1
    @test all(r.demand .>= 0.0)
    @test maximum(r.demand) < 1.0                  # UNDER the cliff once thrust is in
    @test argmax(r.demand) == 4                    # same binding segment as before
    @test r.demand[1] ≈ 0.85800 atol = 5e-3
    @test r.demand[4] ≈ 0.86715 atol = 5e-3
    @test rad2deg(asin(min(r.demand[4], 1.0))) ≈ 60.1287 atol = 0.01
    # Demand falls going up the shaft because each rotor injects its own torque:
    # segs 1-6 carry the generator load, seg 7 carries it less the ring-7
    # expansion rotor, seg 8 less that again.
    @test r.τ_carry[7] ≈ 325.772 atol = 2.0
    @test r.τ_carry[8] ≈ 230.811 atol = 2.0
    @test r.demand[7] ≈ 0.20724 atol = 5e-3
    @test r.demand[8] ≈ 0.16531 atol = 5e-3
    # Section B's top tension is MAIN-ROTOR-ONLY and so is UNCHANGED by the
    # 2026-09-22 thrust-in-profile fix: the expansion rotors sit below the cut.
    @test F_ax[end] ≈ 1163.72 atol = 1.0
    @test F_ax[end] < 1274.47

    # ── A2. this L/r 2.0 fixture is REPAIRABLE inside the cap ────────────────
    # Before 2026-09-22 the omitted expansion thrust left the lower segments
    # under-tensioned, which inflated their demand: the bare design read demand
    # 1.1276 and crossing 1.4716, needing 1.4716 x 1.05 = 1.545x the bare preload
    # — past TRPT_REALISABILITY_MAX_PRELOAD_FACTOR = 1.5 — so
    # `design_axial_preload` REFUSED outright.  With the thrust in the profile the
    # same fixture clears both criteria inside the margin, so the floor repairs it.
    m = KiteTurbineDynamics.TRPT_REALISABILITY_TENSION_MARGIN
    @test m > 1.0
    cross_bare = KiteTurbineDynamics.max_segment_cross_ratio(r, sys)
    @test maximum(r.demand) < 1.0            # under the sin-law cliff
    @test cross_bare ≈ 0.89592 atol = 5e-3   # and under the geometric crossing limit
    @test cross_bare * m <= 1.0              # so one margin step clears it
    @test cross_bare * m < KiteTurbineDynamics.TRPT_REALISABILITY_MAX_PRELOAD_FACTOR
    # The raising call RETURNS now (it used to raise).  Assert the repaired
    # placement clears BOTH floor criteria, not just the sin law.
    F_raised = design_axial_preload(sys, pc, lift, u0; omega_eq=OMEGA_SEED, wind_fn=wf)
    @test F_raised isa AbstractVector
    @test length(F_raised) == sys.n_ring - 1
    @test F_raised[end] >= F_ax[end]         # the floor only ever raises tension
    p_raised = trpt_matched_place(
        sys, pc, F_raised, sys.k_mppt_ref[] * OMEGA_SEED^2, OMEGA_SEED, wf
    )
    @test maximum(p_raised.demand) <= (1.0 / m) * (1.0 + 1e-9)
    @test KiteTurbineDynamics.max_segment_cross_ratio(p_raised, sys) <=
        (1.0 / m) * (1.0 + 1e-9)

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

    # ── C. end-to-end: the preload floor REPAIRS a repairable design ─────────
    # This used the L/r 2.0 SEED_LR20 (4 lines / 3 rotors).  With the crossing
    # limit enforced (A2) that machine is no longer repairable at all — it needs
    # >1.5x the bare preload — so the settle correctly REFUSES it and the old
    # "the floor repairs it" claim is superseded.  The end-to-end repair case is
    # now the L/r 1.5 CAMPAIGN seed geometry, which is the machine the floor is
    # actually sized for.
    sys3, u03, pc3, lift3, wf3 = build_case(nothing, nothing)
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
