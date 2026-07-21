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
)
    # ── Decode genome ────────────────────────────────────────────────────
    result = design_from_vector_v10(
        x[1:14], beam_profile, p; power_W=power_W, v_rated=v_rated
    )
    if result.n_active == 0
        return 1e9  # no rotors = infeasible
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
            lift_device=nothing, lin_damp=0.05, spoke=spoke
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
            lift_device=nothing, lin_damp=0.05, spoke=spoke, callback=window_callback
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
)
    # ── Decode genome ────────────────────────────────────────────────────
    result = design_from_vector_v10(
        x[1:14], beam_profile, p; power_W=power_W, v_rated=v_rated
    )
    if result.n_active == 0
        return (1e9, 0.0, Inf, 0.0, 0.0, true)
    end

    k_mppt = 10.0^x[15]
    k_mppt = clamp(k_mppt, 0.01, 1000.0)

    (; design, rotors, n_rings, zs) = result
    n_lines = design.n_lines

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
        return (1e9, 0.0, Inf, 0.0, 0.0, true)
    end

    # ── Settle rope geometry from ODE ────────────────────────────────────
    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [WIND_MS * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end

    u_settled = settle_to_equilibrium(sys, u0, pc; wind_fn=wf)
    if any(isnan.(u_settled)) || any(isinf.(u_settled))
        return (1e9, 0.0, Inf, ω_eq, 0.0, true)
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
        end
    end

    try
        run_canonical_sim!(
            u_settled, sys, pc, wf, total_n, V11_DT;
            lift_device=nothing, lin_damp=0.05, spoke=spoke, callback=window_callback
        )
    catch e
        @warn "Warm-start sim failed" exception = e
        return (1e9, 0.0, Inf, ω_eq, 0.0, true)
    end

    # ── Score ────────────────────────────────────────────────────────────
    P_mean = isempty(P_samples) ? 0.0 : mean(P_samples)
    FoS_min = isempty(fos_samples) || all(isinf.(fos_samples)) ? Inf : minimum(fos_samples)
    P_range = length(P_samples) >= 2 ? maximum(P_samples) - minimum(P_samples) : 0.0
    drift = length(P_samples) >= 2 ? abs(P_samples[end] - P_samples[1]) / max(mean(P_samples), 0.01) : 0.0
    drifted = drift > 0.15  # >15% drift flag

    fos_penalty = FoS_min < FOS_DESIGN ? FOS_DESIGN / FoS_min : 1.0
    fitness = v11_fitness(P_mean, FoS_min)

    return (fitness, P_mean, FoS_min, ω_eq, P_range, drifted)
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
)
    result = design_from_vector_v10(
        x[1:14], beam_profile, p; power_W=power_W, v_rated=v_rated
    )
    λ_eff = result.n_active > 0 ? result.rotors[1].blade_scale : 1.0
    k_prior = p.k_mppt * λ_eff^2

    best_fitness = Inf
    best_k = k_prior
    best_P = 0.0; best_FoS = Inf; best_ω = 0.0
    best_P_range = 0.0; best_drifted = true

    for k_scale in [0.5, 1.0, 2.0]
        k_try = clamp(k_prior * k_scale, 0.01, 1000.0)
        x_k = copy(x)
        x_k[15] = log10(k_try)

        fitness, P_mean, FoS_min, ω_eq, P_range, drifted =
            objective_v11_warmstart(x_k, beam_profile, p;
                power_W=power_W, v_rated=v_rated, spoke=spoke)

        if fitness < best_fitness
            best_fitness = fitness
            best_k = k_try
            best_P = P_mean
            best_FoS = FoS_min
            best_ω = ω_eq
            best_P_range = P_range
            best_drifted = drifted
        end
    end

    return (best_fitness, best_k, best_P, best_FoS, best_ω, best_P_range, best_drifted)
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
