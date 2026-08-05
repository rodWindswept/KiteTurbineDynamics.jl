# src/objective_v11.jl
#
# V11: Windowed dynamic objective with k_mppt in the DE genome.
# Replaces the static equilibrium solver from v10 with an ODE window
# protocol: settle → kickstart → 60 s MPPT window → window-mean P_kw
# and window-min FoS scoring.
#
# Design vector (15 DoF): V10's 14 DoF + log₁₀(k_mppt)
#   x[1:14] — V10 genome (see objective_v10.jl)
#   x[15]   — log₁₀(k_mppt) ∈ [-2, 3] covering k ∈ [0.01, 1000]
#
# Reference: PRD 0007 Gate 3 (docs/prd/0007-gate3-spec.md)

# Inside KiteTurbineDynamics module — all symbols are in scope.
# No self-import needed.

# ── V10 decode symbols (injected by module include order) ──────────────────
# design_from_vector_v10, search_bounds_v10, TRPT_V10_DIM,
# VALID_ROTOR_MASKS, N_VALID_MASKS, decode_rotor_mask are available
# from objective_v10.jl which is included before this file.

const TRPT_V11_DIM = 15

# ══════════════════════════════════════════════════════════════════════════════
# Search bounds — v10 + log₁₀(k) bounds
# ══════════════════════════════════════════════════════════════════════════════

function search_bounds_v11(
    p::SystemParams,
    beam_profile::BeamProfile;
    max_ground_radius::Float64=OPT_MAX_GROUND_RADIUS,
)
    v10_lo, v10_hi = search_bounds_v10(p, beam_profile; max_ground_radius=max_ground_radius)
    lo = vcat(v10_lo, [-2.0])
    hi = vcat(v10_hi, [3.0])
    return lo, hi
end

# ══════════════════════════════════════════════════════════════════════════════
# ODE window protocol — constants matching Gate 1 sensitivity script
# ══════════════════════════════════════════════════════════════════════════════

const WINDOW_S    = 60.0   # scoring window after transient
const DISCARD_S   = 30.0   # transient discard before window
const WIND_MS     = 11.0   # rated wind speed
const FOS_DESIGN  = 1.5    # minimum acceptable FoS
const V11_DT      = 4e-5   # ODE time step — must match sim fidelity (stiff system)
                            # Each evaluation: ~90s sim / 4e-5 = 2.25M steps
                            # Wall time: ~10-30 min depending on system size.
                            # Gate 3 is a verification gate, not a full-campaign evaluator.

# ══════════════════════════════════════════════════════════════════════════════
# System builder — adapted from builders_util.jl:build_v10_tight_no_lowest
# ══════════════════════════════════════════════════════════════════════════════

function build_system_from_v10(result, blade_scale::Float64, k_mppt::Float64)
    (; design, rotors, n_rings) = result
    n_lines = design.n_lines
    n_exp = length(rotors)

    # Build expansion rotor params (Gate 1c: n_blades = n_lines)
    sys_n_rings_total = n_rings + 2
    expansion_params = ExpansionRotorParams[]
    for rotor in rotors
        sys_ring = rotor.ring_idx == n_rings ? sys_n_rings_total : rotor.ring_idx + 1
        er = ExpansionRotorParams(
            n_lines,
            rotor.blade_tip_radius * blade_scale,
            rotor.blade_hub_radius * blade_scale,
            rotor.blade_chord * blade_scale,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg,
            expansion_blade_mass(rotor.blade_tip_radius * blade_scale, blade_scale),
            sys_ring, 1.0,
        )
        push!(expansion_params, er)
    end

    p_base = params_v5_50kw()
    tether_diameter = 0.003
    le = blade_scale
    geo = GeometrySpec(p_base.elevation_angle, p_base.lifter_elevation, 5.0 * le,
                       design.tether_length, design.r_hub,
                       p_base.trpt_rL_ratio,
                       n_lines, n_rings, n_lines)
    mat = MaterialSpec(tether_diameter, p_base.e_modulus, p_base.m_ring,
                       p_base.m_blade * le^2)
    aero = AeroSpec(p_base.rho, p_base.v_wind_ref, p_base.h_ref, p_base.cp)
    ctrl = ControlSpec(p_base.i_pto, k_mppt, p_base.p_rated_w,
                       p_base.β_min, p_base.β_max, p_base.β_rate_max, p_base.kp_elev)
    back = BackLineSpec(p_base.EA_back_line, p_base.c_back_line, p_base.back_anchor_fwd_x, 0.1)
    pc = SystemParams(geo, mat, aero, ctrl, back)

    sys, u0 = build_kite_turbine_system(pc; expansion_rotors=expansion_params)
    return sys, u0, pc
end

# ══════════════════════════════════════════════════════════════════════════════
# V11 objective — windowed ODE evaluator
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
    fos_penalty = FoS_min < FOS_DESIGN ? FOS_DESIGN / FoS_min : 1.0
    return -P_mean / fos_penalty
end

"""
    objective_v11(x, beam_profile, p; power_W, v_rated, spoke, ...)

Scalar fitness for the V11 DE optimiser.  Returns negative window-mean P_kw
multiplied by a FoS penalty (DE minimises → more negative = better).

The window protocol: settle → kickstart → 60 s window @ 1 Hz → score.
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
)
    # ── Decode genome ────────────────────────────────────────────────────
    result = design_from_vector_v10(
        x[1:14], beam_profile, p; power_W=power_W, v_rated=v_rated
    )
    if result.n_active == 0
        return 1e9  # no rotors = infeasible
    end

    # Model-validity gate: Tulloch TRPT model is uncalibrated at L/r > 3.5.
    # n_rings < 5 implies L/seg >> validated range.  Gate at decode time;
    # re-check after A1 lands — if the degenerate family disappears without
    # this gate, it's insurance rather than necessity.
    if result.n_rings < 5
        return 1e9  # outside Tulloch calibration range
    end

    k_mppt = 10.0^x[15]
    k_mppt = clamp(k_mppt, 0.01, 1000.0)  # safety clamp

    # ── Build ODE system ─────────────────────────────────────────────────
    # Use blade_scale = 1.0 — the genome's λ values already scale blades
    # via design_from_vector_v10's RotorSpecV10.blade_tip_radius etc.
    sys, u0, pc = build_system_from_v10(result, 1.0, k_mppt)

    # ── Wind function ────────────────────────────────────────────────────
    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [WIND_MS * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end

    # ── Settle ───────────────────────────────────────────────────────────
    u_settled = nothing
    try
        u_settled = settle_to_operational_state(
            sys, copy(u0), pc, 60.0; wind_fn=wf
        )
    catch e
        @warn "Settle failed for genome" exception = e
        return 1e9
    end
    if u_settled === nothing
        return 1e9
    end

    # ── Kickstart — brief PTO reversal to spin the rotor ─────────────────
    orig_k = sys.k_mppt_ref[]
    try
        # PTO torque reversal: set k negative momentarily to motor the rotor
        sys.k_mppt_ref[] = -60.0  # N·m·s²/rad² — motor torque
        kick_steps = round(Int, 2.0 / V11_DT)  # 2 s kick
        run_canonical_sim!(
            u_settled, sys, pc, wf, kick_steps, V11_DT;
            lift_device=nothing, lin_damp=lin_damp, spoke=spoke
        )
    catch e
        @warn "Kickstart failed" exception = e
        sys.k_mppt_ref[] = orig_k
    end
    sys.k_mppt_ref[] = orig_k  # restore MPPT k

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
                uc, sys, pc, tc, wf, nothing; brake_engaged=sys.brake_engaged[]
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
            lift_device=nothing, lin_damp=lin_damp, spoke=spoke, callback=window_callback
        )
    catch e
        @warn "Window sim failed" exception = e
        return 1e9
    end

    # ── Score ────────────────────────────────────────────────────────────
    P_score = isempty(P_samples) ? 0.0 : mean(P_samples)
    FoS_score = isempty(fos_samples) || all(isinf.(fos_samples)) ? Inf : minimum(fos_samples)
    return v11_fitness(P_score, FoS_score)
end

# ══════════════════════════════════════════════════════════════════════════════
# Warm-start v11 — skip startup theater, start ODE from static equilibrium
# ══════════════════════════════════════════════════════════════════════════════

const WARM_RELAX_S = 10.0   # relaxation after warm-start init
const WARM_WINDOW_S = 30.0  # measurement window (shorter — signal is in departure)

"""
    objective_v11_warmstart(x, beam_profile, p; spoke, ...)

Warm-start v11 variant for anchor evaluation.  Skips settle + kickstart:
runs the static solver (solve_equilibrium_self_consistent) to get ω_eq,
initialises the ODE at that equilibrium, then runs 10 s relaxation + 30 s
measurement window.

Returns (fitness, P_mean, FoS_min, omega_eq, window_P_range, drift_flag).
Caller runs a 3-point k-bracket and keeps the best.
"""
function objective_v11_warmstart(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    elev_angle::Float64=π / 6,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,     # bearing damper retention factor
    lift_device::Union{Nothing,LiftDevice}=nothing,
)
    # ── Decode genome ────────────────────────────────────────────────────
    result = design_from_vector_v10(
        x[1:14], beam_profile, p; power_W=power_W, v_rated=v_rated
    )
    if result.n_active == 0
        return (12.0, 0.0, Inf, 0.0, 0.0, true, false, -1.0, -1.0)
    end

    k_mppt = 10.0^x[15]
    k_mppt = clamp(k_mppt, 0.01, 1000.0)

    (; design, rotors, n_rings, zs) = result
    n_lines = design.n_lines

    # n_rings gate (A3 fix) — reject designs with fewer than 5 rings.
    # This is a model-validity bound, not a physical finding.  The Tulloch
    # collapse model is uncalibrated at L/r > 3.5, which occurs when n_rings
    # is too low.  n_rings = 3 permits degenerate geometry with unrealistically
    # high FoS that the DE exploits (register row 5).
    if n_rings < 5
        return (12.0, 0.0, Inf, 0.0, 0.0, true, false, -1.0, -1.0)
    end

    # ── Build ODE system ─────────────────────────────────────────────────
    sys, u0, pc = build_system_from_v10(result, 1.0, k_mppt)

    # ── Static equilibrium solve (same path as objective_v10:374) ────────
    expansion_params_v10 = ExpansionRotorParams[]
    for rotor in rotors
        er = ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius,
            rotor.blade_chord, EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg,
            expansion_blade_mass(rotor.blade_tip_radius, rotor.blade_scale),
            rotor.ring_idx, 1.0,
        )
        push!(expansion_params_v10, er)
    end

    _, radii, _ = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
        density_profile=design.density_profile,
    )

    λ_eff = result.n_active > 0 ? rotors[1].blade_scale : 1.0
    k_mppt_eff = p.k_mppt * λ_eff^2  # λ²-scaling for static solver
    p_scaled = override_params(p; k_mppt=k_mppt_eff)

    ω_eq, r_ref = solve_equilibrium_self_consistent(
        design, expansion_params_v10, p_scaled, n_lines, radii, zs;
        P_per_rotor=power_W / max(result.n_active, 1),
        v_wind=v_rated, elev_rad=elev_angle,
    )

    if ω_eq === nothing || isnan(ω_eq) || ω_eq <= 0.0
        return (12.0, 0.0, Inf, 0.0, 0.0, true, false, -1.0, -1.0)
    end

    # ── Settle rope geometry from ODE ────────────────────────────────────
    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [WIND_MS * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end

    u_settled = settle_to_equilibrium(sys, u0, pc; wind_fn=wf)
    if any(isnan.(u_settled)) || any(isinf.(u_settled))
        return (12.0, 0.0, Inf, ω_eq, 0.0, true, false, -1.0, -1.0)
    end

    # ── Set ring angular velocities and orbital velocities ─────────────
    N = sys.n_total
    Nr = sys.n_ring
    # Ring twist rates: u[6N+Nr+1:6N+2Nr]
    u_settled[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
    # Set ring node orbital velocities: v = ω_eq × r tangential
    # Without this, spinning rings + zero node velocity = violent transient
    # that produces spurious FoS collapse and power overshoot (ref:
    # recheck_12gon_convergence.jl:74-84).
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = u_settled[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
            vx_idx = 3*N + 3*(gid-1) + 1
            u_settled[vx_idx:(vx_idx+2)] .= (ω_eq * r) .* tang
        end
    end

    # ── Set k_mppt for the ODE run ──────────────────────────────────────
    sys.k_mppt_ref[] = k_mppt

    # ── Run relaxation + window ─────────────────────────────────────────
    total_s = WARM_RELAX_S + WARM_WINDOW_S
    total_n = round(Int, total_s / V11_DT)
    sample_interval = round(Int, 1.0 / V11_DT)

    P_samples = Float64[]
    fos_samples = Float64[]
    util_a_samples = Float64[]  # worst-ring axial share per sample
    util_b_samples = Float64[]  # worst-ring bending share per sample

    function window_callback(uc, tc, s)
        t_cum = s * V11_DT
        if t_cum > WARM_RELAX_S && s % sample_interval == 0
            ef = capture_extended(
                uc, sys, pc, tc, wf, nothing; brake_engaged=sys.brake_engaged[]
            )
            push!(P_samples, ef.base.P_kw)
            airborne = Float64[]
            for i in 2:length(ef.ring_fos)
                v = ef.ring_fos[i]
                (!isnan(v) && !isinf(v) && v > 0) && push!(airborne, v)
            end
            push!(fos_samples, isempty(airborne) ? Inf : minimum(airborne))
            # Axial and bending shares at worst-FoS ring (A1 fix — always push
            # to keep array lengths aligned with fos_samples)
            if !isempty(airborne)
                worst_idx = argmin(airborne) + 1  # +1 for 1-based indexing
                if worst_idx <= length(ef.ring_util_axial)
                    push!(util_a_samples, ef.ring_util_axial[worst_idx])
                    push!(util_b_samples, ef.ring_util_bending[worst_idx])
                else
                    push!(util_a_samples, -1.0)
                    push!(util_b_samples, -1.0)
                end
            else
                push!(util_a_samples, -1.0)
                push!(util_b_samples, -1.0)
            end
        end
    end

    try
        run_canonical_sim!(
            u_settled, sys, pc, wf, total_n, V11_DT;
            lift_device=lift_device, lin_damp=lin_damp, spoke=spoke, callback=window_callback
        )
    catch e
        @warn "Warm-start sim failed" exception = e
        return (12.0, 0.0, Inf, ω_eq, 0.0, true, false, -1.0, -1.0)
    end

    # ── Score ────────────────────────────────────────────────────────────
    # Filter NaN/Inf from samples before computing statistics
    P_finite = [p for p in P_samples if isfinite(p) && p >= 0.0]
    fos_finite = [f for f in fos_samples if isfinite(f) && f > 0.0]

    if isempty(P_finite) || length(P_finite) < 2
        # No valid power samples — simulation produced garbage
        return (12.0, 0.0, Inf, ω_eq, 0.0, true, false, -1.0, -1.0)
    end

    P_mean = mean(P_finite)

    # Find FoS_min and its sample index in the original arrays (A1 fix).
    # Was: FoS_min = minimum(fos_finite) — no index tracking, so util_a
    # and util_b came from independent maxima rather than the FoS-min instant.
    FoS_min = Inf
    fos_idx_min = 0
    for i in eachindex(fos_samples)
        f = fos_samples[i]
        if isfinite(f) && f > 0.0 && f < FoS_min
            FoS_min = f
            fos_idx_min = i
        end
    end

    # Guard against astronomical P from numerical blowup
    if !isfinite(P_mean) || P_mean > 1e6
        return (12.0, 0.0, Inf, ω_eq, 0.0, true, false, -1.0, -1.0)
    end

    # Betz ceiling (A2 fix) — reject designs exceeding the physical power
    # limit for their swept area.  Was: only P_mean > 1e6 (a 1 TW overflow
    # trap, ~10 million × the machine's ceiling).  The 1103 kW row passed
    # it untouched and contaminated later generations.
    # NOTE: swept area = π·R² uses the airborne ring radius.  Rod should
    # tune this if the multi-line annulus area (n_lines × blade annulus)
    # is the intended reference area.
    P_betz = (16.0 / 27.0) * 0.5 * p.rho * π * p.rotor_radius^2 * v_rated^3 / 1000.0
    P_aero_peak = maximum(P_finite)
    if P_mean > P_betz || P_aero_peak > P_betz
        return (12.0, P_mean, FoS_min, ω_eq, P_range, true, false, -1.0, -1.0)
    end

    # Betz ceiling — physical admissibility check.
    # Total projected swept area: hub rotor + expansion rotors (banked area).
    # Betz power ceiling: 0.593 × ½ρv³ × A_projected.  P_mean must not exceed
    # 1.1× this ceiling (10% tolerance for transient overshoot during window).
    A_total = π * p.rotor_radius^2  # hub rotor, face-on
    for rotor in result.rotors
        bank_rad = rotor.bank_angle_deg * π / 180.0
        A_total += π * rotor.blade_tip_radius^2 * cos(bank_rad)
    end
    Betz_ceiling_kW = 0.593 * 0.5 * p.rho * A_total * v_rated^3 / 1000.0
    if P_mean > 1.1 * Betz_ceiling_kW
        return (1e9, 0.0, Inf, ω_eq, 0.0, true, false, -1.0, -1.0)
    end

    P_range = length(P_finite) >= 2 ? maximum(P_finite) - minimum(P_finite) : 0.0
    drift = length(P_finite) >= 2 ? abs(P_finite[end] - P_finite[1]) / max(mean(P_finite), 0.01) : 0.0
    # Axial and bending util at the FoS-min sample (A1 fix).
    # Was: independent maxima over each array — util_a + util_b ≠ 1/FoS_min.
    # Now: extract from the same ring at the same sample that produced FoS_min.
    # Identity: util_a + util_b = 1/FoS_min for a single beam at a single instant.
    if fos_idx_min > 0 && fos_idx_min <= length(util_a_samples) &&
       fos_idx_min <= length(util_b_samples)
        util_a = util_a_samples[fos_idx_min]
        util_b = util_b_samples[fos_idx_min]
        expected = 1.0 / FoS_min
        if !isapprox(util_a + util_b, expected; rtol=0.01)
            @warn "A1 identity check failed" util_a util_b sum=util_a+util_b expected FoS_min fos_idx_min
        end
    else
        util_a = -1.0
        util_b = -1.0
    end

    # Stationarity gate: split window into halves, check drift (trend)
    # AND amplitude (steadiness).  A limit cycle with a stable mean is
    # not stationary — it must not oscillate violently.
    n = length(P_finite)
    stationary = false
    if n >= 4
        mid = n ÷ 2
        P1 = P_finite[1:mid]; P2 = P_finite[mid+1:end]
        nf = length(fos_finite)
        if all(isfinite.(P1)) && all(isfinite.(P2)) && mean(P1) > 0.01 &&
           nf >= 4
            mid_f = nf ÷ 2
            F1 = fos_finite[1:mid_f]; F2 = fos_finite[mid_f+1:end]
            # Drift: half-window means must be stable
            dP = abs(mean(P1) - mean(P2)) / mean(P1)
            dF = abs(minimum(F1) - minimum(F2)) / max(mean(F1), 0.01)
            # Amplitude: the design must not oscillate wildly around its mean.
            # P_range is already computed above; FoS_range from fos_finite.
            FoS_range = length(fos_finite) >= 2 ?
                maximum(fos_finite) - minimum(fos_finite) : 0.0
            P_steady = P_mean > 0.1 ? P_range / P_mean < 0.20 : false
            FoS_steady = FoS_min > 0.01 ? FoS_range / FoS_min < 0.20 : false
            stationary = dP < 0.10 && dF < 0.10 && P_steady && FoS_steady
        end
    end

    fitness = v11_fitness(P_mean, FoS_min)
    drifted = drift > 0.20  # >20% drift = flagged

    return (fitness, P_mean, FoS_min, ω_eq, P_range, drifted, stationary, util_a, util_b)
end

# ══════════════════════════════════════════════════════════════════════════════
# Warm-start with 3-point k-bracket (Phase 1b)
# ══════════════════════════════════════════════════════════════════════════════

"""
    warmstart_with_k_bracket(x, beam_profile, p; spoke, ...)

Evaluate warm-start v11 at 3 k values around the λ²-scaled prior and return
the best result.  Prior: k̂ = p.k_mppt * λ_eff².  Bracket: k̂·{0.5, 1, 2}.

Returns (best_fitness, best_k, P_mean, FoS_min, omega_eq, P_range, drift).
"""
function warmstart_with_k_bracket(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,     # bearing damper retention factor
    lift_device::Union{Nothing,LiftDevice}=nothing,
)
    result = design_from_vector_v10(
        x[1:14], beam_profile, p; power_W=power_W, v_rated=v_rated
    )
    λ_eff = result.n_active > 0 ? result.rotors[1].blade_scale : 1.0
    k_prior = p.k_mppt * λ_eff^2

    best_fitness = Inf
    best_k = k_prior
    best_P = 0.0; best_FoS = Inf; best_ω = 0.0
    best_P_range = 0.0; best_drifted = true; best_stationary = false
    best_util_a = -1.0; best_util_b = -1.0

    for k_scale in [0.5, 1.0, 2.0]
        k_try = clamp(k_prior * k_scale, 0.01, 1000.0)
        x_k = copy(x)
        x_k[15] = log10(k_try)

        fitness, P_mean, FoS_min, ω_eq, P_range, drifted, stationary, util_a, util_b =
            objective_v11_warmstart(x_k, beam_profile, p;
                power_W=power_W, v_rated=v_rated, spoke=spoke,
                lin_damp=lin_damp, lift_device=lift_device)

        # Skip garbage evals (NaN/Inf blowup returns 1e9 sentinel)
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
        end
    end

    return (best_fitness, best_k, best_P, best_FoS, best_ω, best_P_range, best_drifted, best_stationary, best_util_a, best_util_b)
end

# ══════════════════════════════════════════════════════════════════════════════
# Snapshot mode — backwards-compat single-point evaluation
# ══════════════════════════════════════════════════════════════════════════════

"""
    objective_v11_snapshot(x, beam_profile, p; ...)

Backwards-compatible snapshot mode: single equilibrium point, no window.
Returns the same fitness structure as objective_v10 for comparison.
"""
function objective_v11_snapshot(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
)
    return objective_v10(x[1:14], beam_profile, p; power_W=power_W, v_rated=v_rated)
end
