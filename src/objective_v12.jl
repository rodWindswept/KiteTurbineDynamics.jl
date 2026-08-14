# src/objective_v12.jl
#
# V12: Power-window + FoS-target objective.
#
# Since 2026-08-09 this file is a thin adapter over the shared windowed
# evaluator (src/objective_evaluator.jl) — same shape as V11.  What is
# genuinely V12: the fitness function and its scoring knobs, which ride in
# `ObjectiveConfig` (p_floor_kw, p_ceiling_kw, fos_target, fos_hard, weights).
# The former `V12_*` module-level Refs are gone — a config field now, so the
# "pure" fitness is actually pure and sweeps cannot race the threaded DE.
#
# Design targets:
#   P ∈ [25, 50] kW  — penalty outside this window
#   FoS ≥ 1.5         — hard rejection below (Inf → status=:reject)
#   FoS ≈ 3.0         — ideal; progressive penalty both below and above

"""
    v12_fitness(P_mean::Float64, FoS_min::Float64, cfg::ObjectiveConfig=...) -> Float64

Scalar DE fitness.  More negative = better.

Power window: target [p_floor_kw, p_ceiling_kw] kW.  Quadratic penalty outside.
FoS target: ideal at fos_target.  Quadratic below (steep — safety-critical),
linear above (gentle — wasteful but not dangerous).

Hard gate: FoS < fos_hard → `Inf`.  The evaluator treats a non-finite score
as a hard rejection (status=:reject) — this is a reject signal, not a score.
"""
function v12_fitness(P_mean::Float64, FoS_min::Float64,
                     cfg::ObjectiveConfig=ObjectiveConfig())::Float64
    # Hard gate
    FoS_min < cfg.fos_hard && return Inf

    # ── Power window penalty ─────────────────────────────────────────────
    # V13: penalize_ceiling=false → above-ceiling power at rated wind is
    # headroom, not a flaw. The Betz hard gate in evaluate_windowed rejects
    # physical cheating; the floor penalty is unchanged.
    pw = 1.0
    if P_mean < cfg.p_floor_kw
        pw += ((cfg.p_floor_kw - P_mean) / cfg.p_floor_kw)^2 * cfg.w_floor
    elseif cfg.penalize_ceiling && P_mean > cfg.p_ceiling_kw
        pw += ((P_mean - cfg.p_ceiling_kw) / cfg.p_ceiling_kw)^2 * cfg.w_ceiling
    end

    # ── FoS target penalty (asymmetric) ──────────────────────────────────
    fw = 1.0
    if cfg.fos_target - cfg.fos_hard < 1e-9
        # V13: target == hard floor → no soft pressure above the floor
        # (the hard gate covers FoS < fos_hard). Prevents the divide-by-zero
        # gap formula from driving selection toward unloaded structures.
        fw = 1.0
    elseif FoS_min < cfg.fos_target
        # Quadratic below target: gap=0 at FOS_TARGET, gap=1 at FOS_HARD
        gap = (cfg.fos_target - FoS_min) / (cfg.fos_target - cfg.fos_hard)
        fw += gap^2 * cfg.w_fos_below
    else
        # Hard cap: FoS above fos_cap is excessive mass — reject.
        # Linear above target: gentle slope so DE can follow gradient down.
        FoS_min > cfg.fos_cap && return Inf
        fw += (FoS_min - cfg.fos_target) * cfg.w_fos_above
    end

    return -P_mean / (pw * fw)
end

# ══════════════════════════════════════════════════════════════════════════════
# V12 cold-start objective — V12 scoring over the shared cold protocol
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v12(x, beam_profile, p; k_mppt, power_W, v_rated, spoke, ...)

V12 scalar fitness.  Same simulation as V11 cold (settle → kickstart →
60 s window), scored with `v12_fitness` instead of `v11_fitness`.
Rejected genomes return `Inf`.
"""
function objective_v12(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    elev_angle::Float64=π / 6,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
    k_mppt::Float64=10.0,
)
    cfg = ObjectiveConfig(; k_mppt=k_mppt, relax_s=DISCARD_S, window_s=WINDOW_S,
                          power_W=power_W, v_rated=v_rated)
    return evaluate_windowed(x, beam_profile, p, cfg;
        start_mode=:cold, elev_angle=elev_angle, spoke=spoke, lin_damp=lin_damp,
        lift_device=lift_device,
        fitness_fn=(P, F, c) -> v12_fitness(P, F, c)).fitness
end

# ══════════════════════════════════════════════════════════════════════════════
# V12 warmstart — V12 scoring over the shared warm protocol
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v12_warmstart(x, beam_profile, p; cfg, spoke, ...) -> ObjectiveResult

V12 warmstart variant.  Runs the shared warm protocol (static solver →
settle → relax + window), scored with `v12_fitness`.

Returns an `ObjectiveResult` — same contract as `objective_v11_warmstart`.
"""
function objective_v12_warmstart(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    cfg::ObjectiveConfig=ObjectiveConfig(),
    elev_angle::Float64=π / 6,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
    trace_callback::Union{Nothing,Function}=nothing,
)
    # power_W/v_rated ride in cfg (see objective_v11_warmstart).
    return evaluate_windowed(x, beam_profile, p, cfg;
        start_mode=:warm, elev_angle=elev_angle, spoke=spoke, lin_damp=lin_damp,
        lift_device=lift_device, trace_callback=trace_callback,
        fitness_fn=(P, F, c) -> v12_fitness(P, F, c))
end

# ══════════════════════════════════════════════════════════════════════════════
# V12 warmstart with 3-point k-bracket
# ══════════════════════════════════════════════════════════════════════════════

"""
    warmstart_with_k_bracket_v12(x, beam_profile, p; spoke, ...) -> (ObjectiveResult, k)

Evaluate warm-start v12 at 3 k values around the λ²-scaled prior, keep best.
Same bracket logic as V11 (shared `with_k_bracket`), scored with v12_fitness.
"""
function warmstart_with_k_bracket_v12(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    cfg::Union{Nothing,ObjectiveConfig}=nothing,  # base tunables (relax/window/knobs)
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
)
    scoring = (x14, c) -> objective_v12_warmstart(x14, beam_profile, p;
        cfg=c, spoke=spoke, lin_damp=lin_damp, lift_device=lift_device)
    return with_k_bracket(scoring, x, beam_profile, p;
        power_W=power_W, v_rated=v_rated, cfg=cfg)
end

# ══════════════════════════════════════════════════════════════════════════════
# V12 ramp-controller evaluator
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v12_ramp(x, beam_profile, p; cfg, spoke, ...) -> ObjectiveResult

V12 ramp-controller evaluation.  Uses the RampController (IDLE → RAMPING →
HOLDING) to discover the sustainable k_mppt dynamically.  The ramp continues
through the scoring window — k is never frozen.  Scored with `v12_fitness`.
"""
function objective_v12_ramp(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    cfg::ObjectiveConfig=ObjectiveConfig(),
    elev_angle::Float64=π / 6,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
    trace_callback::Union{Nothing,Function}=nothing,
)
    return evaluate_ramp(x, beam_profile, p, cfg;
        elev_angle=elev_angle, spoke=spoke, lin_damp=lin_damp,
        lift_device=lift_device, trace_callback=trace_callback,
        fitness_fn=(P, F, c) -> v12_fitness(P, F, c))
end
