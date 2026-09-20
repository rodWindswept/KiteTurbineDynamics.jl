# test/test_settle_preload_consistency.jl
#
# Guard for the 2026-09-11 settle↔ODE coherence fix
# (docs/plans/2026-09-11-settle-ode-coherence.md).
#
# The previous initialiser set each segment's ring AXIAL gap for the *untwisted*
# line and only then applied the twist.  Because
#
#     chord² = L_ax² + r_a² + r_b² − 2·r_a·r_b·cos Δα
#
# the twist term alone stretches the line.  At the Δα the old bisection landed on
# (6.6°) that twist strain was 1.6e-3 — six times the intended preload strain
# (2.7e-4) — so the segment looked ~7× too stiff, the settle returned a ~7×
# under-twisted state, and the ODE spent ~100 s shortening the transmission to
# relieve it (the wind-up).
#
# The invariant that must hold for ANY design is:
#
#     line tension at the settled state  ==  the intended preload F_ax/n_lines
#
# plus the twist must be the twisted equilibrium, not the old 6.6°.
# This is a pure static check — no ODE window — so it belongs in the fast suite.
#
# CORRECTED 2026-09-13.  The reference is now evaluated at the settle's OWN ω.
# `design_axial_preload` used to carry a hardcoded fallback — the campaign seed's
# 12.983466 rad/s — for any `omega_eq <= 0`, and this file called it with the
# default.  So the seed agreed to 1e-6 only because the fallback IS the seed's ω,
# while the non-seed cases carried a spurious 2.3 % / 13.2 % "error" that was
# entirely the wrong reference (measured: 0.0 against the settle's own ω).  That
# is why the threshold is now 1e-3 instead of 0.15.  See
# scratch/diag_preload_reference.jl.
#
# The former second case — `(n_lines=6, rotor_count=1)`, labelled "known tilt
# limitation" — was RETIRED on the same date for two independent reasons:
#   1. it is past the torsional realisability cliff (12 consecutive segments at
#      Δα = 90°, a three-turn wind-up), which the old `asin(clamp(...))` placed
#      silently; over-cliff designs now RAISE, so it cannot be settled at all;
#   2. its "~35 % high" tension error was the reference artefact above, not tilt.
# The cliff is guarded by test/test_trpt_realisability.jl; the tilt limitation
# itself is currently UNQUANTIFIED and needs a realisable vehicle to re-measure.

using Test, KiteTurbineDynamics, LinearAlgebra
include(joinpath(dirname(@__DIR__), "scripts", "compute_seeds.jl"))
include(joinpath(@__DIR__, "settle_case_builders.jl"))

function settled_case(n_lines, rotor_count)
    sys, u0, pc, lift, wf = build_case(n_lines, rotor_count)
    # Settle FIRST: the operating ω is an output of the settle, and the intended
    # preload must be evaluated at the ω the settle actually ran at.
    #
    # `operational_polish=false` IS DELIBERATE (2026-09-19).  This file guards the
    # MATCHED-PLACE stage: `trpt_matched_place` prescribes the tension F_ax and
    # derives the geometry, so at that placed state the invariant below holds
    # exactly.  The operational-equilibrium polish is a SUBSEQUENT stage that
    # intentionally relaxes the positions onto force balance under the full
    # handoff force field, and the equilibrium tension is NOT the design preload —
    # measured 2026-09-19 on the campaign seed it sits between 0.96x and 1.32x of
    # it per segment.  Testing the polish's output against the pre-polish target
    # would test the wrong stage.  The equilibrium is guarded instead by
    # `test_settle_validity.jl` (V6) and by its equilibrium realisability margin.
    # See scratch/probe_dr_equilibrium.jl.  ACTIVE.md item 2's load split landed
    # 2026-09-20, so the equilibrium side is no longer pending.
    u = settle_to_operational_state(
        sys,
        copy(u0),
        pc,
        60.0;
        lift_device=lift,
        wind_fn=wf,
        n_op=2_000,
        operational_polish=false,
    )
    N, Nr = sys.n_total, sys.n_ring
    ω = u[6N + Nr + 1]
    # UPGRADED 2026-09-20.  The reference must be evaluated at the hub the settle
    # actually placed the machine at, not the raw `u0` geometry.  Since the taut
    # load split landed, `settle_to_operational_state` places FIRST and sizes the
    # preload from the CONTRACTED hub `placement.ctrs[Nr]` (the 2x2 is
    # ill-conditioned and the split is very sensitive to that position).  Reading
    # the post-settle hub back is therefore the same contract the settle used.
    # Measured on the campaign seed: raw-`u0` reference reads 4.95 % error against
    # the placed state; the settled hub reads 0.69 %, which is the residual motion
    # of the operational settle's own loop (`operational_polish=false` still runs
    # it), not a modelling gap.  Threshold raised 1e-3 -> 1e-2 to cover exactly
    # that loop; a regression to the old ~7x under-twist state still fails it by
    # two orders of magnitude.
    hub = u[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)]
    F_ax = design_axial_preload(sys, pc, lift, u0; omega_eq=ω, wind_fn=wf, hub_pos=hub)
    @test length(F_ax) == sys.n_ring - 1
    intended = F_ax ./ pc.n_lines
    ef = KiteTurbineDynamics.capture_extended(u, sys, pc, 0.0, wf, lift)
    return sys, pc, u, intended, ef
end

@testset "settle matched-place preload — tension equals the intended preload" begin
    # The campaign seed: the geometry the wind-up was diagnosed and fixed on.
    sys, pc, u, intended, ef = settled_case(nothing, nothing)

    err = maximum(abs.(ef.segment_tension .- intended) ./ intended)
    @test err < 1e-2

    # Guard against regression to the old ~7x-under-twisted state.  A correct
    # matched-place solve puts the first segment far past the old 6.6° — it
    # carries the full generator torque at the design tension.
    @test ef.segment_twist_deg[1] > 30.0

    # The transmission must shorten under torsion (rings pulled together),
    # not sit at the untwisted design length.
    untwisted = sum(
        ROPE_SUBSEGS * sys.sub_segs[(k - 1) * pc.n_lines * ROPE_SUBSEGS + 1].length_0 for
        k in 1:(sys.n_ring - 1)
    )
    hub = u[(3 * (sys.rotor.node_id - 1) + 1):(3 * sys.rotor.node_id)]
    @test norm(hub) < untwisted
end
