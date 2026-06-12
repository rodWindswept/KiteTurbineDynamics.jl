#!/usr/bin/env julia
# scripts/science_pitch_depower_dynamics.jl
#
# Standalone simulation script to analyze Pitch Depower dynamics.
# Runs a high-fidelity 20s Pitch Depower simulation under:
#   1. Mode 0 (Standard MPPT + 15m baseline payout)
#   2. Mode 1 (Active Torsional Damping + 25m extended payout)
#   3. Mode 2 (LPF Speed MPPT + 25m extended payout)
#
# Saves all frame telemetry to a clean, structured CSV for programmatic analysis.

using Pkg;
Pkg.activate(dirname(@__DIR__))
using KiteTurbineDynamics
using CSV, DataFrames, Printf

# Helper to override SystemParams fields
function _modified_params(base::SystemParams; overrides...)
    fnames = fieldnames(SystemParams)
    ftypes = fieldtypes(SystemParams)
    override_dict = Dict{Symbol, Any}(overrides)
    vals = ntuple(length(fnames)) do i
        return convert(ftypes[i], get(override_dict, fnames[i], getfield(base, fnames[i])))
    end
    return SystemParams(vals...)
end

function run_pitch_depower_case(mode_name::String, ctrl_mode::Float64, payout_base::Float64)
    println("\n=== Running Case: $mode_name (payout_base = $payout_base m) ===")

    p = params_10kw()
    # Apply initial overrides
    p_run = _modified_params(p; β_rate_max=ctrl_mode, β_min=payout_base)

    sys, u0 = build_kite_turbine_system(p_run)
    ld = rotary_lifter_default()

    # Wind at 11.0 m/s reference
    vref = 11.0
    wf = (pos, t) -> begin
        z = max(pos[3], 1.0);
        sh = (z / p_run.h_ref)^(1/7)
        [vref * sh, 0.0, 0.0]
    end

    # Settle to rated operating state
    omega_rated = cbrt(p_run.p_rated_w / p_run.k_mppt)
    u_s = settle_to_operational_state(
        sys, u0, p_run, omega_rated; lift_device=ld, wind_fn=wf
    )

    # Simulation timing
    t_total = 20.0
    dt = 4e-5
    n_steps = round(Int, t_total / dt)
    save_every = max(1, round(Int, 0.02 / dt)) # 0.02s per frame

    # Pre-allocate frames
    n_frames = n_steps ÷ save_every
    df_rows = Vector{Dict{Symbol, Any}}(undef, n_frames)

    u = copy(u_s)
    du = zeros(Float64, length(u))
    t = 0.0
    release_frac = 0.0
    frame_idx = 1

    N = sys.n_total
    Nr = sys.n_ring

    depower_delay = 0.15 * t_total
    depower_duration = 0.70 * t_total

    ode_p = isnothing(ld) ? (sys, p_run, wf) : (sys, p_run, wf, ld)

    for step in 1:n_steps
        # Pitch Depower winching payout update every 500 steps
        if step % 500 == 0
            x = clamp((t - depower_delay) / depower_duration, 0.0, 1.0)
            release_frac = 3.0 * x^2 - 2.0 * x^3 # Sigmoid curve

            geom_scale = p_run.tether_length / 30.0
            max_payout = payout_base * geom_scale

            p_depower = _modified_params(p_run; backline_payout=max_payout * release_frac)
            ode_p = isnothing(ld) ? (sys, p_depower, wf) : (sys, p_depower, wf, ld)
        end

        fill!(du, 0.0)
        multibody_ode!(du, u, ode_p, t)
        t += dt

        @views u[(3N + 1):6N] .+= dt .* du[(3N + 1):6N]
        @views u[1:3N] .+= dt .* u[(3N + 1):6N]
        @views u[(6N + Nr + 1):(6N + 2Nr)] .+= dt .* du[(6N + Nr + 1):(6N + 2Nr)]
        @views u[(6N + 1):(6N + Nr)] .+= dt .* u[(6N + Nr + 1):(6N + 2Nr)]

        orbital_damp_rope_velocities!(u, sys, p_run, 0.05)

        # PTO co-braking hack (Mode 0 only!)
        if release_frac > 0.0 && ctrl_mode ≈ 0.0
            @views u[(6N + Nr + 1):(6N + 2Nr)] .*= (1.0 - release_frac * 1e-5)
        end

        # Boundary anchors
        u[1:3] .= 0.0
        u[(3N + 1):(3N + 3)] .= 0.0

        # Save frame at save_every steps
        if step % save_every == 0
            # Retrieve parameter state corresponding to current winching payout
            geom_scale = p_run.tether_length / 30.0
            max_payout = payout_base * geom_scale
            p_current = _modified_params(p_run; backline_payout=max_payout * release_frac)

            sf = capture_frame(u, sys, p_current, t, wf, ld)

            df_rows[frame_idx] = Dict(
                :mode => mode_name,
                :t => sf.t,
                :omega_hub => sf.omega_hub,
                :omega_gnd => sf.omega_gnd,
                :P_kw => sf.P_kw,
                :hub_z => sf.hub_z,
                :delta_alpha_deg => sf.delta_alpha_deg,
                :delta_omega => sf.delta_omega,
                :tau_gen => sf.tau_gen,
                :T_max => sf.T_max,
                :ring_max_util => sf.ring_max_util,
                :n_slack => sf.n_slack,
                :backline_payout => max_payout * release_frac,
            )

            if frame_idx % 200 == 0
                @printf(
                    "  Progress: %.1f s / %.1f s  (payout = %.2f m)\n",
                    t,
                    t_total,
                    max_payout * release_frac
                )
            end

            frame_idx += 1
        end
    end

    return DataFrame(df_rows)
end

function main()
    results_dir = joinpath(@__DIR__, "results")
    mkpath(results_dir)

    # 1. Mode 0: Standard MPPT, 15m Baseline
    df_mode0 = run_pitch_depower_case("Mode 0 (Standard)", 0.0, 15.0)

    # 2. Mode 1: Active Damping, 25m Extended
    df_mode1 = run_pitch_depower_case("Mode 1 (Active Damping)", 1.0, 25.0)

    # 3. Mode 2: LPF Speed MPPT, 25m Extended
    df_mode2 = run_pitch_depower_case("Mode 2 (LPF Speed)", 2.0, 25.0)

    # Merge results
    df_all = vcat(df_mode0, df_mode1, df_mode2)

    csv_path = joinpath(results_dir, "pitch_depower_dynamics_comparison.csv")
    CSV.write(csv_path, df_all)
    return println("\n✓ Saved high-fidelity simulation telemetry to: $csv_path")
end

main()
