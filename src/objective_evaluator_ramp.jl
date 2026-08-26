# src/objective_evaluator_ramp.jl
#
# Ramp-controller evaluator — replaces the fixed-k bracket with a dynamically
# converging RampController.  The protocol:
#
#   decode genome → gates → build system → warm pre-solve → settle →
#   RampController ramp to HOLDING → scoring window (ramp continues) →
#   gates (Betz, stationarity) → score via fitness_fn.
#
# The ramp controller discovers the sustainable k_mppt for the design rather
# than guessing it from a 3-point bracket.  k is an OUTPUT, not an input.
#
# Included from objective_evaluator.jl so it shares all module-internal
# symbols (ObjectiveConfig, ObjectiveResult, build_system_from_v10, etc.).

# ══════════════════════════════════════════════════════════════════════════════
# Ramp-mode constants
# ══════════════════════════════════════════════════════════════════════════════

const RAMP_CHUNK_S = 2.0        # ODE seconds per ramp-controller chunk
const RAMP_MAX_CHUNKS = 60      # safety cap: 60 × 2s = 120s max ramp
const RAMP_WINDOW_S = 60.0      # scoring window after HOLDING reached

"""
    evaluate_ramp(x, beam_profile, p, cfg; fitness_fn, ...) -> ObjectiveResult

Ramp-controller evaluation.  Same contract as `evaluate_windowed` but uses
the RampController instead of a fixed k_mppt bracket.

Returns `ObjectiveResult` with `status = :ok` or `:reject`.
"""
function evaluate_ramp(
    x::AbstractVector,
    beam_profile::BeamProfile,
    p::SystemParams,
    cfg::ObjectiveConfig;
    elev_angle::Float64=π / 6,
    spoke::Union{Nothing,SpokeParams}=nothing,
    lin_damp::Float64=0.05,
    lift_device::Union{Nothing,LiftDevice,Function}=nothing,
    trace_callback::Union{Nothing,Function}=nothing,
    fitness_fn::Function,       # the version seam — required
)
    # ── Decode genome ────────────────────────────────────────────────────
    (length(x) == TRPT_V10_DIM || length(x) == TRPT_V10_DIM + 1) ||
        error("evaluate_ramp expects $TRPT_V10_DIM-D genome, got $(length(x))")
    x14 = x[1:TRPT_V10_DIM]
    result = design_from_vector_v10(
        x14, beam_profile, p; power_W=cfg.power_W, v_rated=cfg.v_rated
    )
    if result.n_active == 0
        return rejected_eval()
    end
    if result.n_rings < 1
        return rejected_eval()
    end

    # ── Build ODE system ─────────────────────────────────────────────────
    # base_params=p — the rung-scaled campaign base (2026-08-22).  This call
    # previously omitted it, so the ramp evaluator built EVERY rung with the
    # 50 kW base (12.0757 kg/blade) — the same contamination DECISIONS
    # [2026-08-20] fixed for evaluate_windowed, missed here.  evaluate_windowed
    # and evaluate_ramp must build the same machine.
    sys, u0, pc = build_system_from_v10(result, 1.0, cfg.k_mppt;
                                        tether_diameter=cfg.tether_diameter,
                                        base_params=p)
    (; design, rotors, n_rings, zs) = result
    n_lines = design.n_lines

    lift_dev = lift_device isa Function ? lift_device(sys, pc) : lift_device

    function wf(pos, t)
        z = max(pos[3], 1.0)
        return [WIND_MS * (z / p.h_ref)^(1.0 / 7.0), 0.0, 0.0]
    end

    # ── Warm pre-solve (shared with :warm path) ──────────────────────────
    expansion_params_v10 = expansion_params_from_rotors(rotors, n_rings, n_lines)
    _, radii, _ = ring_spacing_v4(
        design.r_hub, design.r_bottom, design.tether_length, design.target_Lr;
        density_profile=design.density_profile,
    )

    λ_eff = result.n_active > 0 ? rotors[1].blade_scale : 1.0
    k_mppt_eff = p.k_mppt * λ_eff^2
    p_scaled = override_params(p; k_mppt=k_mppt_eff)

    ω_eq, r_ref = solve_equilibrium_self_consistent(
        design, expansion_params_v10, p_scaled, n_lines, radii, zs;
        P_per_rotor=cfg.power_W / max(result.n_active, 1),
        v_wind=cfg.v_rated, elev_rad=elev_angle,
    )
    if ω_eq === nothing || isnan(ω_eq) || ω_eq <= 0.0
        return rejected_eval()
    end

    u = settle_to_equilibrium(sys, u0, pc; wind_fn=wf, lift_device=lift_dev)
    if any(isnan.(u)) || any(isinf.(u))
        return rejected_eval(ω_eq)
    end

    # Set ring angular + orbital velocities
    N = sys.n_total
    Nr = sys.n_ring
    u[(6N + Nr + 1):(6N + 2Nr)] .= ω_eq
    for ri in 1:Nr
        gid = sys.ring_ids[ri]
        pos = u[(3*(gid-1)+1):(3*gid)]
        r = norm(pos)
        if r > 0.01
            tang = [-pos[2], pos[1], 0.0]; tang ./= norm(tang)
            vx_idx = 3N + 3*(gid-1) + 1
            u[vx_idx:(vx_idx+2)] .= (ω_eq * r) .* tang
        end
    end

    # ── Ramp controller initialisation ────────────────────────────────────
    ctrl = RampController(; P_target=cfg.power_W)
    init_geometry!(ctrl, sys, pc)

    # ── Ramp loop: chunked ODE with update_ramp! between chunks ──────────
    chunk_steps = round(Int, RAMP_CHUNK_S / V11_DT)
    holding_reached = false
    ramp_chunks_used = 0
    t_cum = 0.0

    for chunk in 1:RAMP_MAX_CHUNKS
        try
            run_canonical_sim!(
                u, sys, pc, wf, chunk_steps, V11_DT;
                lift_device=lift_dev, lin_damp=lin_damp, spoke=spoke
            )
        catch e
            @warn "Ramp chunk $chunk failed" exception = e
            return rejected_eval(ω_eq)
        end
        t_cum += RAMP_CHUNK_S
        ramp_chunks_used += 1

        sf = capture_frame(u, sys, pc, t_cum, wf, lift_dev)
        min_fos_val = min_ring_fos(u, sys, pc)
        collapse_margin = min_collapse_margin(u, sys, ctrl)

        update_ramp!(ctrl, sys, sf, V11_DT;
            min_fos=min_fos_val, collapse_margin_deg=collapse_margin)

        if ctrl.state === HOLDING
            holding_reached = true
            break
        end
    end

    # ── Scoring window (ramp continues) ───────────────────────────────────
    window_n = round(Int, RAMP_WINDOW_S / V11_DT)
    sample_interval = round(Int, 1.0 / V11_DT)

    P_samples = Float64[]
    fos_samples = Float64[]
    util_a_samples = Float64[]
    util_b_samples = Float64[]
    T_lift_samples = Float64[]
    k_samples = Float64[]

    trace_ctx = (; sys=sys, pc=pc, wf=wf, lift_device=lift_dev)

    try
        run_canonical_sim!(
            u, sys, pc, wf, window_n, V11_DT;
            lift_device=lift_dev, lin_damp=lin_damp, spoke=spoke,
            callback=(uc, tc, s) -> begin
                trace_callback !== nothing && trace_callback(uc, tc, s, trace_ctx)

                if s % sample_interval == 0
                    ef = capture_extended(
                        uc, sys, pc, tc, wf, lift_dev; brake_engaged=sys.brake_engaged[]
                    )
                    push!(P_samples, ef.base.P_kw)
                    isfinite(ef.base.T_lift) && push!(T_lift_samples, ef.base.T_lift)

                    f_min, worst_idx = min_airborne_fos(ef.ring_fos)
                    push!(fos_samples, f_min)

                    if worst_idx > 0 && worst_idx <= length(ef.ring_util_axial) &&
                       worst_idx <= length(ef.ring_util_bending)
                        push!(util_a_samples, ef.ring_util_axial[worst_idx])
                        push!(util_b_samples, ef.ring_util_bending[worst_idx])
                    else
                        push!(util_a_samples, -1.0); push!(util_b_samples, -1.0)
                    end

                    push!(k_samples, sys.k_mppt_ref[])

                    # Continue ramping during the scoring window
                    sf2 = capture_frame(uc, sys, pc, tc, wf, lift_dev)
                    min_fos2 = min_ring_fos(uc, sys, pc)
                    cm2 = min_collapse_margin(uc, sys, ctrl)
                    update_ramp!(ctrl, sys, sf2, V11_DT;
                        min_fos=min_fos2, collapse_margin_deg=cm2)
                end
            end
        )
    catch e
        @warn "Ramp scoring window failed" exception = e
        return rejected_eval(ω_eq)
    end

    # ── Score ────────────────────────────────────────────────────────────
    P_finite = [p for p in P_samples if isfinite(p) && p >= 0.0]
    fos_finite = [f for f in fos_samples if isfinite(f) && f > 0.0]

    if isempty(P_finite) || length(P_finite) < 2
        return rejected_eval(ω_eq)
    end

    P_mean = mean(P_finite)

    FoS_min = Inf
    fos_idx_min = 0
    for i in eachindex(fos_samples)
        f = fos_samples[i]
        if isfinite(f) && f > 0.0 && f < FoS_min
            FoS_min = f; fos_idx_min = i
        end
    end

    P_range = length(P_finite) >= 2 ? maximum(P_finite) - minimum(P_finite) : 0.0
    drift = length(P_finite) >= 2 ? abs(P_finite[end] - P_finite[1]) / max(mean(P_finite), 0.01) : 0.0

    util_a = fos_idx_min > 0 && fos_idx_min <= length(util_a_samples) ? util_a_samples[fos_idx_min] : -1.0
    util_b = fos_idx_min > 0 && fos_idx_min <= length(util_b_samples) ? util_b_samples[fos_idx_min] : -1.0

    # Betz gates
    A_total = π * p.rotor_radius^2
    for rotor in result.rotors
        bank_rad = rotor.bank_angle_deg * π / 180.0
        A_total += π * rotor.blade_tip_radius^2 * cos(bank_rad)
    end
    Betz_ceiling_kW = 0.593 * 0.5 * p.rho * A_total * cfg.v_rated^3 / 1000.0
    Betz_cp_kW = p.cp * 0.5 * p.rho * A_total * cfg.v_rated^3 / 1000.0
    if Betz_cp_kW < cfg.p_floor_kw * 0.8
        return rejected_eval(ω_eq)
    end
    if P_mean > 1.1 * Betz_ceiling_kW
        return rejected_eval(ω_eq)
    end

    # Stationarity
    n = length(P_finite)
    stationary = false
    if n >= 4
        mid = n ÷ 2
        P1 = P_finite[1:mid]; P2 = P_finite[mid+1:end]
        nf = length(fos_finite)
        if all(isfinite.(P1)) && all(isfinite.(P2)) && mean(P1) > 0.01 && nf >= 4
            mid_f = nf ÷ 2
            F1 = fos_finite[1:mid_f]; F2 = fos_finite[mid_f+1:end]
            dP = abs(mean(P1) - mean(P2)) / mean(P1)
            dF = abs(minimum(F1) - minimum(F2)) / max(mean(F1), 0.01)
            FoS_range_win = length(fos_finite) >= 2 ? maximum(fos_finite) - minimum(fos_finite) : 0.0
            P_steady = P_mean > 0.1 ? P_range / P_mean < 0.20 : false
            FoS_steady = FoS_min > 0.01 ? FoS_range_win / FoS_min < 0.20 : false
            stationary = dP < 0.10 && dF < 0.10 && P_steady && FoS_steady
        end
    end

    fitness = fitness_fn(P_mean, FoS_min, cfg)
    if !isfinite(fitness)
        return rejected_eval(ω_eq)
    end

    swing = P_mean > 0.1 ? P_range / P_mean : 0.0
    excess = max(0.0, swing - STATIONARITY_SWING)
    fitness = fitness + STATIONARITY_LAMBDA * excess
    drifted = drift > 0.20

    k_converged = isempty(k_samples) ? sys.k_mppt_ref[] : mean(k_samples)
    T_lift_mean = isempty(T_lift_samples) ?
        (lift_dev isa StackedLifterParams ? lift_dev.T_ref : 0.0) :
        mean(T_lift_samples)

    return ObjectiveResult(:ok, fitness, P_mean, FoS_min, ω_eq, P_range,
                      drifted, stationary, util_a, util_b, T_lift_mean,
                      P_mean, false, false)
end
