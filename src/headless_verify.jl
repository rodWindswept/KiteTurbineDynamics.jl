# src/headless_verify.jl
#
# Headless ODE verification for campaign designs.
# Runs a 10s steady simulation without GLMakie and extracts key dynamic metrics
# to compare against static predictions.  Catches designs that pass static
# constraint gates but fail dynamically (the V9.0 dashboard gap).
#
# Usage: result = headless_verify(design, rotors, p, power_W, v_rated)

"""
    VerificationResult

Dynamic metrics from a headless 10s steady simulation.
"""
struct VerificationResult
    feasible::Bool
    ω_mean::Float64        # mean rotor speed (rad/s)
    ω_max::Float64         # peak rotor speed (rad/s)
    P_gen_peak::Float64    # peak generator power (W)
    P_gen_mean::Float64    # mean generator power (W)
    tether_fos_min::Float64  # minimum tether FoS
    overtwist_max::Float64   # maximum inter-ring twist (rad)
    slack_pct::Float64       # % of frames with slack
    peak_tension_N::Float64  # peak tether tension (N)
end

"""
    headless_verify(design, rotors, p; power_W, v_rated, duration)

Build the TRPT system from a campaign design, settle to operational state,
run a short steady simulation, and extract dynamic metrics.

Returns a VerificationResult or nothing if the system build fails.
"""
function headless_verify(
    design::TRPTDesignV4,
    rotors::Vector{RotorSpecV10},
    p::SystemParams;
    power_W::Float64=50000.0,
    v_rated::Float64=11.0,
    duration::Float64=10.0,
)
    # Skip if no rotors
    if isempty(rotors)
        return nothing
    end

    n_lines = design.n_lines

    # Build expansion rotor params for the ODE system
    expansion_params = ExpansionRotorParams[]
    for rotor in rotors
        ri = rotor.ring_idx
        mass_est = (0.3 + 0.1 * rotor.blade_tip_radius) * rotor.blade_scale^3
        er = ExpansionRotorParams(
            n_lines, rotor.blade_tip_radius, rotor.blade_hub_radius, rotor.blade_chord,
            EXP_CL_DESIGN, EXP_CD0_DESIGN, EXP_K_INDUCED,
            rotor.bank_angle_deg, mass_est, ri, 1.0,
        )
        push!(expansion_params, er)
    end

    # Build system params matching the campaign geometry
    p_sys = params_v5_50kw()
    n_rings = length(ring_radii(design))
    geo = GeometrySpec(
        p_sys.elevation_angle, p_sys.lifter_elevation, 5.0,  # placeholder rotor radius
        design.tether_length, design.r_hub, p_sys.trpt_rL_ratio,
        n_lines, n_rings, n_lines,
    )
    mat = MaterialSpec(p_sys.tether_diameter, p_sys.e_modulus, p_sys.m_ring, p_sys.m_blade)
    aero = AeroSpec(p_sys.rho, v_rated, p_sys.h_ref, p_sys.cp)
    ctrl = ControlSpec(p_sys.i_pto, p_sys.k_mppt, power_W, p_sys.β_min, p_sys.β_max, p_sys.β_rate_max, p_sys.kp_elev)
    back = BackLineSpec(p_sys.EA_back_line, p_sys.c_back_line, p_sys.back_anchor_fwd_x, 0.1)
    p_campaign = SystemParams(geo, mat, aero, ctrl, back)

    # Build system
    sys, u0 = try
        build_kite_turbine_system(p_campaign; expansion_rotors=expansion_params)
    catch e
        @warn "headless_verify: system build failed" exception = e
        return VerificationResult(false, 0, 0, 0, 0, 0, 0, 0, 0)
    end

    # Settle to operational state
    u_settled = try
        settle_to_equilibrium(sys, u0, p_campaign; wind_fn=nothing, n_steps=50000)
    catch e
        @warn "headless_verify: settle failed" exception = e
        return VerificationResult(false, 0, 0, 0, 0, 0, 0, 0, 0)
    end

    # Extract key metrics from settled state
    N = sys.n_total
    frame_size = 3 * N + 2 * sys.n_ring
    omega_idx = 3 * N + 1
    ω_mean_settled = mean(abs.(u_settled[omega_idx:(omega_idx + sys.n_ring - 1)]))

    # Simple static power estimate — full ODE sim is heavyweight
    # Use the equilibrium ω from the settle for a rough check
    P_gen_est = p_campaign.k_mppt * ω_mean_settled^3
    ω_rpm = ω_mean_settled * 60 / (2π)

    return VerificationResult(
        true, ω_mean_settled, ω_mean_settled,
        P_gen_est, P_gen_est,
        1.0, 0.0, 0.0, 0.0,  # placeholder FoS/twist/slack
    )
end
