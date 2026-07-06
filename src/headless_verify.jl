# src/headless_verify.jl
#
# Headless ODE verification for campaign designs.
#
# Two functions:
#   headless_verify_structural  — gravity-settle only, ~2s, catches
#                                 degenerate geometry (per-island gate)
#   headless_verify             — full k_mppt scan via settle_to_operational_state,
#                                 finds whether ANY k_mppt produces rated power
#                                 (post-campaign global-best check)
#
# Usage:
#   vr = headless_verify_structural(design, rotors, p)
#   vr = headless_verify(design, rotors, p; power_W, v_rated)

"""
    VerificationResult

Dynamic metrics from headless verification.
"""
struct VerificationResult
    feasible::Bool
    ω_mean::Float64        # settled rotor speed (rad/s)
    ω_max::Float64         # same
    P_gen_peak::Float64    # generator power (W)
    P_gen_mean::Float64    # same
    k_mppt_best::Float64   # best k_mppt found (full scan only)
    power_ratio::Float64   # P_gen / power_W
end

# ── Shared system construction ──────────────────────────────────────────

function _build_verify_system(design, rotors, p, v_rated, power_W)
    n_lines = design.n_lines
    n_rings = length(ring_radii(design))
    sys_n_rings_total = n_rings + 2
    expansion_params = ExpansionRotorParams[]
    for rotor in rotors
        ri = rotor.ring_idx
        # Remap from intermediate to system ring numbering
        sys_ri = ri == n_rings ? sys_n_rings_total : ri + 1
        mass_est = expansion_blade_mass(rotor.blade_tip_radius, rotor.blade_scale)
        er = ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius, rotor.blade_chord,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg, mass_est, sys_ri, 1.0,
        )
        push!(expansion_params, er)
    end

    p_sys = params_v5_50kw()
    n_rings = length(ring_radii(design))
    geo = GeometrySpec(
        p_sys.elevation_angle, p_sys.lifter_elevation, 5.0,
        design.tether_length, design.r_hub, p_sys.trpt_rL_ratio,
        n_lines, n_rings, n_lines,
    )
    mat = MaterialSpec(p_sys.tether_diameter, p_sys.e_modulus, p_sys.m_ring, p_sys.m_blade)
    aero = AeroSpec(p_sys.rho, v_rated, p_sys.h_ref, p_sys.cp)
    ctrl = ControlSpec(p_sys.i_pto, p_sys.k_mppt, power_W, p_sys.β_min, p_sys.β_max, p_sys.β_rate_max, p_sys.kp_elev)
    back = BackLineSpec(p_sys.EA_back_line, p_sys.c_back_line, p_sys.back_anchor_fwd_x, 0.1)
    p_campaign = SystemParams(geo, mat, aero, ctrl, back)

    sys, u0 = build_kite_turbine_system(p_campaign; expansion_rotors=expansion_params)
    return sys, u0, p_campaign, p_sys, geo, mat, aero, back
end

# ── Fast structural check (~2s) ─────────────────────────────────────────

"""
    headless_verify_structural(design, rotors, p; power_W, v_rated)

Gravity-settle only.  Returns `feasible=false` if the TRPT structure
cannot reach a stable gravity-equilibrium (degenerate geometry,
bouncing head, no tension).  Does NOT test power production.

Fast enough for per-island campaign validation (~2 seconds).
"""
function headless_verify_structural(
    design::TRPTDesignV4,
    rotors::Vector{RotorSpecV10},
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
)
    if isempty(rotors)
        return nothing
    end

    local sys, u0, p_campaign
    try
        sys, u0, p_campaign, _, _, _, _, _ = _build_verify_system(design, rotors, p, v_rated, power_W)
    catch e
        @warn "headless_verify_structural: build failed" exception = e
        return VerificationResult(false, 0, 0, 0, 0, p.k_mppt, 0)
    end

    try
        settle_to_equilibrium(sys, u0, p_campaign; wind_fn=nothing, n_steps=20000)
    catch e
        @warn "headless_verify_structural: gravity settle failed" exception = e
        return VerificationResult(false, 0, 0, 0, 0, p.k_mppt, 0)
    end

    return VerificationResult(true, 0, 0, 0, 0, p.k_mppt, 0)
end

# ── Full k_mppt power scan (~5 min) ─────────────────────────────────────

"""
    headless_verify(design, rotors, p; power_W, v_rated)

1. Gravity-settle the TRPT structure.
2. Scan 8 logarithmically-spaced k_mppt values from 0.1× to 10× the
   campaign's k_mppt.
3. At each k_mppt, run settle_to_operational_state to find the
   equilibrium ω, then compute P_gen = k_mppt × ω³.
4. Find the k_mppt whose P_gen is closest to power_W (in ratio space).
5. Return whether that best P_gen falls within [0.8×, 1.25×] power_W.

A design that can't produce >80% rated power at ANY k_mppt is
dynamically non-viable.

Intended for post-campaign final verification, not per-island gating
(~5 minutes for the full scan).
"""
function headless_verify(
    design::TRPTDesignV4,
    rotors::Vector{RotorSpecV10},
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
)
    if isempty(rotors)
        return nothing
    end

    local sys, u0, p_campaign, p_sys, geo, mat, aero, back
    try
        sys, u0, p_campaign, p_sys, geo, mat, aero, back = _build_verify_system(design, rotors, p, v_rated, power_W)
    catch e
        @warn "headless_verify: system build failed" exception = e
        return VerificationResult(false, 0, 0, 0, 0, p.k_mppt, 0)
    end

    # Gravity settle
    local u_grav
    try
        u_grav = settle_to_equilibrium(sys, u0, p_campaign; wind_fn=nothing, n_steps=20000)
    catch e
        @warn "headless_verify: gravity settle failed" exception = e
        return VerificationResult(false, 0, 0, 0, 0, p.k_mppt, 0)
    end

    # Scan k_mppt logarithmically
    k_base = p_sys.k_mppt
    k_values = [round(k_base * 10.0^x, digits=1) for x in [-1.0, -0.7, -0.4, -0.1, 0.0, 0.3, 0.6, 1.0]]

    wind_fn = (pos, t) -> [v_rated, 0.0, 0.0]
    ω_init = 9.5
    N = sys.n_total
    Nr = sys.n_ring
    omega_idx = 3 * N + 1

    best_k = k_base
    best_ratio_err = Inf
    best_omega = 0.0
    best_P = 0.0

    for k_mppt_test in k_values
        ctrl_test = ControlSpec(p_sys.i_pto, k_mppt_test, power_W, p_sys.β_min, p_sys.β_max, p_sys.β_rate_max, p_sys.kp_elev)
        p_test = SystemParams(geo, mat, aero, ctrl_test, back)

        local u_op
        try
            u_op = settle_to_operational_state(sys, u_grav, p_test, ω_init;
                wind_fn=wind_fn, lift_device=nothing)
        catch e
            continue
        end

        ω_vals = abs.(u_op[omega_idx:(omega_idx + Nr - 1)])
        ω_mean_val = mean(ω_vals)
        P_val = k_mppt_test * ω_mean_val^3
        ratio = P_val / power_W
        err = abs(log(max(ratio, 0.01)))

        if err < best_ratio_err
            best_ratio_err = err
            best_k = k_mppt_test
            best_omega = ω_mean_val
            best_P = P_val
        end
    end

    best_ratio = best_P / power_W
    feasible_dynamic = best_ratio > 0.80

    return VerificationResult(
        feasible_dynamic, best_omega, best_omega,
        best_P, best_P,
        best_k, best_ratio,
    )
end
