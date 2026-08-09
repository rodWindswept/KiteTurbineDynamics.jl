# src/objective_v12.jl
#
# V12: Power-window + FoS-target objective.
# Reuses V11 simulation infrastructure (build, settle, kickstart, window sim)
# and replaces only the fitness scoring.  The DE minimises fitness, so more
# negative = better.
#
# Design targets:
#   P ∈ [25, 50] kW  — penalty outside this window
#   FoS ≥ 1.5         — hard rejection below
#   FoS ≈ 3.0         — ideal; progressive penalty both below and above
#
# All weights are Refs — tunable without source edits or precompile-cache flushes.

# ── Tunable constants (Refs for sweep compatibility) ─────────────────────────

const V12_P_FLOOR      = Ref(25.0)   # kW — penalty below
const V12_P_CEILING    = Ref(50.0)   # kW — penalty above
const V12_FOS_TARGET   = Ref(3.0)    # ideal factor of safety
const V12_FOS_HARD     = Ref(1.5)    # hard rejection below
const V12_W_FLOOR      = Ref(4.0)    # P < floor: quadratic weight
const V12_W_CEILING    = Ref(2.0)    # P > ceiling: quadratic weight
const V12_W_FOS_BELOW  = Ref(4.0)    # FoS < target: steep quadratic
const V12_W_FOS_ABOVE  = Ref(0.02)   # FoS > target: gentle linear slope

# ══════════════════════════════════════════════════════════════════════════════
# V12 fitness function
# ══════════════════════════════════════════════════════════════════════════════

"""
    v12_fitness(P_mean::Float64, FoS_min::Float64) -> Float64

Scalar DE fitness.  More negative = better.

Power window: target [P_FLOOR, P_CEILING] kW.  Quadratic penalty outside.
FoS target: ideal at FOS_TARGET.  Quadratic below (steep — safety-critical),
linear above (gentle — wasteful but not dangerous).

Hard gate: FoS < FOS_HARD → 1e9 (infeasible).
"""
function v12_fitness(P_mean::Float64, FoS_min::Float64)::Float64
    # Hard gate
    FoS_min < V12_FOS_HARD[] && return 1e9

    # ── Power window penalty ─────────────────────────────────────────────
    pw = 1.0
    if P_mean < V12_P_FLOOR[]
        pw += ((V12_P_FLOOR[] - P_mean) / V12_P_FLOOR[])^2 * V12_W_FLOOR[]
    elseif P_mean > V12_P_CEILING[]
        pw += ((P_mean - V12_P_CEILING[]) / V12_P_CEILING[])^2 * V12_W_CEILING[]
    end

    # ── FoS target penalty (asymmetric) ──────────────────────────────────
    fw = 1.0
    if FoS_min < V12_FOS_TARGET[]
        # Quadratic below target: gap=0 at FOS_TARGET, gap=1 at FOS_HARD
        gap = (V12_FOS_TARGET[] - FoS_min) / (V12_FOS_TARGET[] - V12_FOS_HARD[])
        fw += gap^2 * V12_W_FOS_BELOW[]
    else
        # Linear above target: gentle slope so DE can follow gradient down
        fw += (FoS_min - V12_FOS_TARGET[]) * V12_W_FOS_ABOVE[]
    end

    return -P_mean / (pw * fw)
end

# ══════════════════════════════════════════════════════════════════════════════
# V12 cold-start objective — delegates to V11 simulation, re-scores with V12
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v12(x, beam_profile, p; power_W, v_rated, spoke, ...)

V12 scalar fitness.  Same simulation as V11 (settle → kickstart → 60 s window),
scored with v12_fitness instead of v11_fitness.
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
)
    # ── Decode genome ────────────────────────────────────────────────────
    result = design_from_vector_v10(
        x[1:14], beam_profile, p; power_W=power_W, v_rated=v_rated
    )
    if result.n_active == 0
        return 1e9
    end

    if result.n_rings < 1
        return 1e9
    end

    k_mppt = 10.0^x[15]
    k_mppt = clamp(k_mppt, 0.01, K_MPPT_MAX)

    # ── Build ODE system ─────────────────────────────────────────────────
    sys, u0, pc = build_system_from_v10(result, 1.0, k_mppt)
    lift_dev = lift_device isa Function ? lift_device(sys, pc) : lift_device

    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [WIND_MS * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end

    # ── Settle ───────────────────────────────────────────────────────────
    u_settled = nothing
    try
        u_settled = settle_to_operational_state(
            sys, copy(u0), pc, 60.0; wind_fn=wf, lift_device=lift_dev
        )
    catch e
        @warn "Settle failed for genome" exception = e
        return 1e9
    end
    if u_settled === nothing
        return 1e9
    end

    # ── Kickstart ─────────────────────────────────────────────────────────
    orig_k = sys.k_mppt_ref[]
    try
        sys.k_mppt_ref[] = -60.0
        kick_steps = round(Int, 2.0 / V11_DT)
        run_canonical_sim!(
            u_settled, sys, pc, wf, kick_steps, V11_DT;
            lift_device=lift_dev, lin_damp=lin_damp, spoke=spoke
        )
    catch e
        @warn "Kickstart failed" exception = e
        sys.k_mppt_ref[] = orig_k
    end
    sys.k_mppt_ref[] = orig_k

    # ── Window sim ───────────────────────────────────────────────────────
    total_s = DISCARD_S + WINDOW_S
    total_n = round(Int, total_s / V11_DT)
    sample_interval = round(Int, 1.0 / V11_DT)

    P_samples = Float64[]
    fos_samples = Float64[]

    function window_callback(uc, tc, s)
        t_cum = s * V11_DT
        if t_cum > DISCARD_S && s % sample_interval == 0
            ef = capture_extended(
                uc, sys, pc, tc, wf, lift_dev; brake_engaged=sys.brake_engaged[]
            )
            push!(P_samples, ef.base.P_kw)
            airborne = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]
                (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
            end
            push!(fos_samples, isempty(airborne) ? Inf : minimum(airborne))
        end
    end

    try
        run_canonical_sim!(
            u_settled, sys, pc, wf, total_n, V11_DT;
            lift_device=lift_dev, lin_damp=lin_damp, spoke=spoke, callback=window_callback
        )
    catch e
        @warn "Window sim failed" exception = e
        return 1e9
    end

    # ── Score with V12 fitness ───────────────────────────────────────────
    P_score = isempty(P_samples) ? 0.0 : mean(P_samples)
    FoS_score = isempty(fos_samples) || all(isinf.(fos_samples)) ? Inf : minimum(fos_samples)
    return v12_fitness(P_score, FoS_score)
end

# ══════════════════════════════════════════════════════════════════════════════
# V12 warmstart — V11 simulation, V12 scoring
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v12_warmstart(x, beam_profile, p; spoke, ...)

V12 warmstart variant.  Runs V11's warmstart simulation (static solver →
settle → relax + window), then re-scores with v12_fitness.

Returns (fitness, P_mean, FoS_min, omega_eq, P_range, drifted, stationary,
util_a, util_b, T_lift_mean) — same tuple shape as V11 warmstart.
"""
function objective_v12_warmstart(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    elev_angle::Float64=π / 6,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
    trace_callback::Union{Nothing,Function}=nothing,
)
    # ── Run V11 warmstart to get simulation results ──────────────────────
    fitness_v11, P_mean, FoS_min, ω_eq, P_range, drifted, stationary,
        util_a, util_b, T_lift =
        objective_v11_warmstart(x, beam_profile, p;
            power_W=power_W, v_rated=v_rated, elev_angle=elev_angle,
            spoke=spoke, lin_damp=lin_damp, lift_device=lift_device,
            trace_callback=trace_callback)

    # ── Guard: reject garbage evals ──────────────────────────────────────
    if !isfinite(fitness_v11) || fitness_v11 >= 1e8
        return (1e9, P_mean, FoS_min, ω_eq, P_range, true, false, -1.0, -1.0, 0.0)
    end

    # ── Re-score with V12 fitness ────────────────────────────────────────
    fitness_v12 = v12_fitness(P_mean, FoS_min)

    # Re-apply stationarity soft penalty (same as V11)
    swing = P_mean > 0.1 ? P_range / P_mean : 0.0
    excess = max(0.0, swing - STATIONARITY_SWING)
    fitness_v12 = fitness_v12 + STATIONARITY_LAMBDA * excess

    return (fitness_v12, P_mean, FoS_min, ω_eq, P_range, drifted, stationary, util_a, util_b, T_lift)
end

# ══════════════════════════════════════════════════════════════════════════════
# V12 warmstart with 3-point k-bracket
# ══════════════════════════════════════════════════════════════════════════════

"""
    warmstart_with_k_bracket_v12(x, beam_profile, p; spoke, ...)

Evaluate warm-start v12 at 3 k values around the λ²-scaled prior, keep best.
Same bracket logic as V11, scored with v12_fitness.

Returns (best_fitness, best_k, P_mean, FoS_min, omega_eq, P_range,
drifted, stationary, util_a, util_b, T_lift).
"""
function warmstart_with_k_bracket_v12(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
)
    (length(x) == TRPT_V11_DIM || length(x) == TRPT_V11_DIM + 1) ||
        error("warmstart_with_k_bracket_v12 expects $TRPT_V11_DIM-D genome, got $(length(x))")
    x14 = x[1:TRPT_V11_DIM]
    result = design_from_vector_v10(
        x14, beam_profile, p; power_W=power_W, v_rated=v_rated
    )
    λ_eff = result.n_active > 0 ? result.rotors[1].blade_scale : 1.0
    k_prior = p.k_mppt * λ_eff^2

    best_fitness = Inf
    best_k = k_prior
    best_P = 0.0; best_FoS = Inf; best_ω = 0.0
    best_P_range = 0.0; best_drifted = true; best_stationary = false
    best_util_a = -1.0; best_util_b = -1.0
    best_T_lift = 0.0

    tried_k = Set{Float64}()
    for k_scale in [0.5, 1.0, 2.0]
        k_try = clamp(k_prior * k_scale, 0.01, K_MPPT_MAX)
        k_try in tried_k && continue
        push!(tried_k, k_try)

        x_k = vcat(x14, [log10(k_try)])

        fitness, P_mean, FoS_min, ω_eq, P_range, drifted, stationary,
            util_a, util_b, T_lift =
            objective_v12_warmstart(x_k, beam_profile, p;
                power_W=power_W, v_rated=v_rated, spoke=spoke,
                lin_damp=lin_damp, lift_device=lift_device)

        if !isfinite(fitness) || fitness >= 1e8
            continue
        end

        if fitness < best_fitness
            best_fitness = fitness
            best_k = k_try
            best_P = P_mean
            best_FoS = FoS_min
            best_ω = ω_eq
            best_P_range = P_range
            best_drifted = drifted
            best_stationary = stationary
            best_util_a = util_a
            best_util_b = util_b
            best_T_lift = T_lift
        end
    end

    return (best_fitness, best_k, best_P, best_FoS, best_ω, best_P_range,
            best_drifted, best_stationary, best_util_a, best_util_b, best_T_lift)
end
