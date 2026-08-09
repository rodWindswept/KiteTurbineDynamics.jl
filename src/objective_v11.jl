# src/objective_v11.jl
#
# V11: Windowed dynamic objective with k_mppt owned by the warm-start bracket.
#
# Since 2026-08-09 this file is a thin adapter over the shared windowed
# evaluator (src/objective_evaluator.jl).  The protocol — build → start →
# window ODE run → gates → score — lives there, once.  This file contributes
# what is genuinely V11: the search space (14-D V10 genome), the fitness
# function, and the versioned entry points.
#
# The fitness seam: `fitness_fn(P_mean, FoS_min, cfg)`.  A non-finite return
# is a hard rejection.  k comes from `cfg.k_mppt` — never from the genome.
# A legacy 15-D vector (x[15] = log₁₀ k_mppt) is still accepted and sliced;
# the slot is inert (S1 audit 2026-08-07: the bracket overwrote it before
# every eval, so it was a dead search dimension).
#
# Reference: PRD 0007 Gate 3 (docs/prd/0007-gate3-spec.md)

# Inside KiteTurbineDynamics module — all symbols are in scope.
# No self-import needed.

# ── V10 decode symbols (injected by module include order) ──────────────────
# design_from_vector_v10, search_bounds_v10, TRPT_V10_DIM,
# VALID_ROTOR_MASKS, N_VALID_MASKS, decode_rotor_mask are available
# from objective_v10.jl which is included before this file.

# 14-D search space: the V10 genome (Do_top … λ_bottom).  x15 (log₁₀ k_mppt)
# was removed 2026-08-07 (S1 audit): warmstart_with_k_bracket overwrote it
# before every eval, so the DE's 15th gene had zero fitness effect and only
# railed at a bound.  k is owned solely by the bracket's λ²-scaled prior.
const TRPT_V11_DIM = 14

# ══════════════════════════════════════════════════════════════════════════════
# Search bounds — V10 genome only (k owned by the bracket, not the search)
# ══════════════════════════════════════════════════════════════════════════════

function search_bounds_v11(
    p::SystemParams,
    beam_profile::BeamProfile;
    max_ground_radius::Float64=OPT_MAX_GROUND_RADIUS,
)
    return search_bounds_v10(p, beam_profile; max_ground_radius=max_ground_radius)
end

# ══════════════════════════════════════════════════════════════════════════════
# V11 fitness — pure scoring (tested in isolation)
# ══════════════════════════════════════════════════════════════════════════════

"""
    v11_fitness(P_mean::Float64, FoS_min::Float64) -> Float64

DE fitness score: negative mean power, penalised for FoS < FOS_DESIGN.
Division (not multiplication): FoS down → |fitness| down → worse.

Monotonicity properties:
  ∂fitness/∂FoS > 0  when FoS < FOS_DESIGN (verified by test)
  ∂fitness/∂P  < 0  always
"""
function v11_fitness(P_mean::Float64, FoS_min::Float64)::Float64
    fos_penalty = FoS_min < FOS_GATE ? FOS_GATE / FoS_min : 1.0
    return -P_mean / fos_penalty
end

# ══════════════════════════════════════════════════════════════════════════════
# V11 cold-start objective — scalar fitness (settle → kickstart → 60 s window)
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v11(x, beam_profile, p; k_mppt, power_W, v_rated, spoke, ...)

Scalar fitness for the V11 DE optimiser (DE minimises → more negative =
better).  The window protocol — settle → kickstart → 60 s window @ 1 Hz →
score — is `evaluate_windowed` with `start_mode=:cold`.  Rejected genomes
return `Inf` (check with `isfinite`).

`k_mppt` is an explicit keyword (was: a phantom x[15] genome slot).
"""
function objective_v11(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    elev_angle::Float64=π / 6,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,     # bearing damper retention factor
    # A LiftDevice is used as-is.  A Function is called as `f(sys, p)` once the
    # system exists, so the device can be sized to this genome's airborne mass.
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
    k_mppt::Float64=10.0,
)
    cfg = ObjectiveConfig(; k_mppt=k_mppt, relax_s=DISCARD_S, window_s=WINDOW_S,
                          power_W=power_W, v_rated=v_rated)
    return evaluate_windowed(x, beam_profile, p, cfg;
        start_mode=:cold, elev_angle=elev_angle, spoke=spoke, lin_damp=lin_damp,
        lift_device=lift_device, fitness_fn=(P, F, c) -> v11_fitness(P, F)).fitness
end

# ══════════════════════════════════════════════════════════════════════════════
# V11 warmstart — static pre-solve → relax + measurement window
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v11_warmstart(x, beam_profile, p; cfg, spoke, ...) -> ObjectiveResult

Warm-start variant for anchor evaluation.  Skips settle + kickstart: runs the
static solver (solve_equilibrium_self_consistent) to get ω_eq, initialises
the ODE at that equilibrium, then runs `cfg.relax_s` relaxation + a
`cfg.window_s` measurement window.

Returns an `ObjectiveResult` (gate on `status`; `status == :reject` means the
eval produced no real result).  `cfg.k_mppt` replaces the x[15] channel —
the bracket passes it.
"""
function objective_v11_warmstart(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    cfg::ObjectiveConfig=ObjectiveConfig(),
    elev_angle::Float64=π / 6,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,     # bearing damper retention factor
    # A LiftDevice is used as-is.  A Function is called as `f(sys, p)` once the
    # system exists, so the device can be sized to this genome's airborne mass —
    # e.g. `(s, pp) -> sized_lifter_for(s, pp; margin=1.5)`.
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
    # Diagnostic tap.  Called every ODE step as trace_callback(u, t, step, ctx)
    # where ctx = (; sys, pc, wf, lift_device).  Scoring is unaffected — the
    # window sampling runs exactly as it does without a tap, so a traced
    # eval and an untraced eval return identical numbers.  Decimate inside the
    # callback; this fires at full step rate.
    trace_callback::Union{Nothing,Function}=nothing,
)
    # power_W/v_rated ride in cfg (they were kwargs on the old copy-pasted
    # body; on the shared evaluator the config is the single source).
    return evaluate_windowed(x, beam_profile, p, cfg;
        start_mode=:warm, elev_angle=elev_angle, spoke=spoke, lin_damp=lin_damp,
        lift_device=lift_device, trace_callback=trace_callback,
        fitness_fn=(P, F, c) -> v11_fitness(P, F))
end

# ══════════════════════════════════════════════════════════════════════════════
# Warm-start with 3-point k-bracket (Phase 1b)
# ══════════════════════════════════════════════════════════════════════════════

"""
    warmstart_with_k_bracket(x, beam_profile, p; spoke, ...) -> (ObjectiveResult, k)

Evaluate warm-start v11 at 3 k values around the λ²-scaled prior and return
the best `(ObjectiveResult, k)` pair.  Prior: k̂ = p.k_mppt * λ_eff².  Bracket:
k̂·{0.5, 1, 2}.  Rejected evals never win the bracket (status gate), so an
all-rejected genome comes back as `status == :reject` — it can no longer
land in a campaign CSV as a real result.
"""
function warmstart_with_k_bracket(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    cfg::Union{Nothing,ObjectiveConfig}=nothing,  # base tunables (relax/window/knobs)
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,     # bearing damper retention factor
    # A LiftDevice is used as-is.  A Function is called as `f(sys, p)` once the
    # system exists, so the device can be sized to this genome's airborne mass —
    # e.g. `(s, pp) -> sized_lifter_for(s, pp; margin=1.5)`.
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
)
    scoring = (x14, c) -> objective_v11_warmstart(x14, beam_profile, p;
        cfg=c, spoke=spoke, lin_damp=lin_damp, lift_device=lift_device)
    return with_k_bracket(scoring, x, beam_profile, p;
        power_W=power_W, v_rated=v_rated, cfg=cfg)
end

# ══════════════════════════════════════════════════════════════════════════════
# Snapshot mode — deleted 2026-08-09
# ══════════════════════════════════════════════════════════════════════════════
# objective_v11_snapshot was a 9-line forwarder to objective_v10 (a static
# v10 alias wearing a v11 name).  With the evaluator consolidation the
# "snapshot" concept is obsolete: v11 cold IS the windowed eval, v10 is the
# static solver — different protocols, no equality to assert.  The v10
# regression pin moved into test_objective_v11.jl as a direct objective_v10
# call.
