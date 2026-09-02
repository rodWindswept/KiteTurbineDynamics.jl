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
    # Hard gate — non-finite FoS (null structural measurement) is a REJECT,
    # not a pass: `Inf < fos_hard` is false, so an unguarded comparison lets
    # a machine with unmeasured ring loads score as feasible (exploit-register
    # row 1, fixed in objective_feasibility 5d02d45; added here 2026-08-22).
    (!isfinite(FoS_min) || FoS_min < cfg.fos_hard) && return Inf

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

"""4-arg seam overload (2026-08-20): `mass` is passed but v12 is power-based —
ignored.  Keeps the shared evaluator seam `fitness_fn(P, F, cfg, mass)`
compatible with the power-scoring objectives."""
v12_fitness(P_mean::Float64, FoS_min::Float64, cfg::ObjectiveConfig, mass::Float64) =
    v12_fitness(P_mean, FoS_min, cfg)

"""
    mass_min_fitness(P_mean, FoS_min, cfg, mass) -> Float64

Hard-constraint mass-minimisation objective (Rod, 2026-08-20).  Minimise the
TRUE physics mass subject to two HARD floors:

  - FoS_min < cfg.fos_hard  → Inf  (structural reliability; re-run uses 2.5)
  - P_mean  < cfg.p_floor_kw → Inf (aero/power requirement; the rung rating)

Both are reject signals (Inf), not soft penalties — the DE cannot trade power
or safety against mass.  Score = `mass` (kg, positive → DE minimises it).
The swept-area (annulus) and rung/λ mass scaling make the λ→0 and heavy-blade
exploits impossible, so the classical minimum-mass design falls out directly.
"""
function mass_min_fitness(P_mean::Float64, FoS_min::Float64,
                          cfg::ObjectiveConfig, mass::Float64)::Float64
    # Non-finite FoS guard (2026-08-22): `Inf < fos_hard` is false, so a
    # machine with null structural measurement used to pass the floor and
    # score its mass (exploit-register row 1 class).  Reject it.
    (!isfinite(FoS_min) || FoS_min < cfg.fos_hard) && return Inf
    P_mean < cfg.p_floor_kw && return Inf
    return mass
end

# ══════════════════════════════════════════════════════════════════════════════
# Appropriateness + safety fitness (T3, 2026-09-02)
# ══════════════════════════════════════════════════════════════════════════════

# PLACEHOLDER penalty weights — Rod to tune later.  Each one converts a
# dimensionless (or unit-carrying) penalty term into kilograms, so the returned
# fitness stays in mass units and the DE can minimise it directly.  The numbers
# below are starting points, NOT calibrated values.
#
#   W_OVERPOWER_KG_PER_KW2 = 5.0   → a 1 kW excess (20% over a 5 kW ceiling)
#                                    adds 5 kg, ~10% of a 50 kg machine.
#   W_TWIST_KG              = 1.0   → twist_ratio 0.5 adds 1 kg; 0.9 adds 81 kg;
#                                    0.99 adds ~9800 kg (effectively rejected).
#   W_UTILISATION_KG        = 20.0  → FoS at the floor (zero margin) adds 20 kg;
#                                    FoS 2× floor adds 5 kg; FoS 17.6 adds ~0.4 kg.
const W_OVERPOWER_KG_PER_KW2 = 5.0     # kg per (excess power in kW)²
const W_TWIST_KG              = 1.0     # kg per (twist_ratio / twist_margin)²
const W_UTILISATION_KG        = 20.0    # kg per (fos_hard / FoS_min)²

"""
    appropriate_mass_fitness(P_mean, FoS_min, cfg, mass; twist_ratio=0.0) -> Float64

Mass-plus-penalties fitness (T3, 2026-09-02).  "Good" now means **light AND
appropriate AND safe**, not merely light.

Keeps the exact hard reject gates from `mass_min_fitness`:
  - non-finite `FoS_min`, or `FoS_min < cfg.fos_hard` → `Inf`  (structural)
  - `P_mean < cfg.p_floor_kw` → `Inf`  (power floor)

Then returns `mass + penalties`, with three soft penalty terms:

1. **Over-power** — `P_mean > cfg.p_ceiling_kw` wastes material (a machine
   making more than rated power is carrying rotor/tether it does not need).
   Quadratic in the excess: `W_OVERPOWER_KG_PER_KW2 · max(P_mean − p_ceiling, 0)²`.
2. **Over-twist** — `twist_ratio` is (actual twist)/(geometric crossing limit),
   the same `max_ratio` the gate's `twist_report` computes, so 0 = no twist and
   1 = at the collapse limit.  Penalty diverges as the twist margin
   `(1 − twist_ratio)` shrinks: `W_TWIST_KG · (twist_ratio / margin)²`.
   Defaults to `0.0` (= no penalty) so this function is unit-testable in
   isolation; wiring the live ratio from the evaluator is a follow-on.
3. **Beam utilisation** — `FoS_min` close to `cfg.fos_hard` leaves little
   safety margin.  Penalty grows with the utilisation ratio
   `(cfg.fos_hard / FoS_min)²`, which is 1 at the floor and → 0 for large FoS.

Returns `Inf` for the same hard-reject conditions as `mass_min_fitness`.
"""
function appropriate_mass_fitness(P_mean::Float64, FoS_min::Float64,
                                  cfg::ObjectiveConfig, mass::Float64;
                                  twist_ratio::Float64=0.0)::Float64
    # ── Hard reject gates (unchanged from mass_min_fitness) ──────────────
    (!isfinite(FoS_min) || FoS_min < cfg.fos_hard) && return Inf
    P_mean < cfg.p_floor_kw && return Inf

    # ── 1. Over-power penalty — quadratic in the excess above the ceiling ─
    excess_kw = max(P_mean - cfg.p_ceiling_kw, 0.0)
    penalty_overpower = W_OVERPOWER_KG_PER_KW2 * excess_kw^2

    # ── 2. Over-twist penalty — diverges as twist_ratio approaches 1 ─────
    penalty_twist = 0.0
    if twist_ratio > 0.0
        r = min(twist_ratio, 1.0)          # r ≥ 1 = collapse; clamp to avoid NaN
        margin = max(1.0 - r, 1e-6)        # never divide by zero
        penalty_twist = W_TWIST_KG * (r / margin)^2
    end

    # ── 3. Beam-utilisation penalty — grows as FoS approaches the floor ──
    penalty_util = W_UTILISATION_KG * (cfg.fos_hard / FoS_min)^2

    return mass + penalty_overpower + penalty_twist + penalty_util
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
        fitness_fn=(P, F, c, m) -> v12_fitness(P, F, c, m)).fitness
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
        fitness_fn=(P, F, c, m) -> v12_fitness(P, F, c, m))
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
        fitness_fn=(P, F, c, m) -> v12_fitness(P, F, c, m))
end
