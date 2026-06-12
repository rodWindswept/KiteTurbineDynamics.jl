#!/usr/bin/env julia
# scripts/pitch_depower_campaign_v3.jl
#
# Windswept & Interesting Ltd
# Pitch-Depower Parameter Sweep (V3 Campaign).
# Sweeps over expanded Wind Speeds, Tether Stiffness, Tether Damping, and PTO Inertia
# to investigate dynamic elasticity and electromechanical matching bounds.
#
# Usage:
#   julia --project=. --threads=auto scripts/pitch_depower_campaign_v3.jl
#
# Output files:
#   scripts/results/pitch_depower_campaign_v3/campaign_metrics.csv  — summary table
#   scripts/results/pitch_depower_campaign_v3/timeseries_<run_id>.csv — per-run timeseries
#

using Pkg;
Pkg.activate(joinpath(@__DIR__, ".."))

using KiteTurbineDynamics
using LinearAlgebra, Statistics, Printf
using CSV, DataFrames
import Base.Threads: @threads, nthreads

# ── Output directory ──────────────────────────────────────────────────────────
const RESULTS_DIR = joinpath(@__DIR__, "results", "pitch_depower_campaign_v3")
mkpath(RESULTS_DIR)

# ── Sweep axes (256-run V3 Campaign grid) ──────────────────────────────────────
WIND_SPEEDS = [6.0, 11.0, 15.0, 20.0]          # m/s (Light to storm wind speed sweep)
PAYOUT_DURATIONS = [4.0, 15.0]                      # s (Fast payout vs. standard)
ACTIVE_WINCH_VALS = [false, true]                    # Winch compliance toggle
DAMPING_MODES = [0.0, 2.0]                       # 0=MPPT, 2=LPF Speed Mode
EA_BACK_LINES = [350000.0, 700000.0]             # N (Tether elasticity / compliant vs. stiff)
C_BACK_LINES = [250.0, 500.0]                   # N·s/m (Tether viscoelastic damping)
I_PTO_VALS = [12.5, 25.0]                     # kg·m² (PTO inertia mass scaling)

# Build full V3 factorial grid
function build_grid()
    grid = NamedTuple[]
    for ws in WIND_SPEEDS
        for pdur in PAYOUT_DURATIONS
            for awinch in ACTIVE_WINCH_VALS
                for dmode in DAMPING_MODES
                    for ea in EA_BACK_LINES
                        for c in C_BACK_LINES
                            for i_pto in I_PTO_VALS
                                push!(
                                    grid,
                                    (
                                        wind_speed=ws,
                                        payout_duration=pdur,
                                        active_winch=awinch,
                                        damping_mode=dmode,
                                        EA_back_line=ea,
                                        c_back_line=c,
                                        i_pto=i_pto,
                                        field_imu=true,  # Fixed to true (essential for safety)
                                        mppt_stall=false, # Fixed to false (stall is destructive)
                                        payout_base_m=15.0,  # Fixed default payout base
                                        lifter_elev_deg=75.0,  # Fixed optimal elevation angle
                                        duration_s=30.0,  # Fixed scenario duration
                                    ),
                                )
                            end
                        end
                    end
                end
            end
        end
    end

    # Longest Processing Time (LPT) Sorting to minimize thread tail latency
    grid = sort(grid; by=x -> x.payout_duration, rev=true)
    return grid
end

function build_smoke_grid()
    return [
        (
            wind_speed=6.0,
            payout_duration=4.0,
            active_winch=false,
            damping_mode=0.0,
            EA_back_line=350000.0,
            c_back_line=250.0,
            i_pto=12.5,
            field_imu=true,
            mppt_stall=false,
            payout_base_m=15.0,
            lifter_elev_deg=75.0,
            duration_s=10.0,
        ),
        (
            wind_speed=15.0,
            payout_duration=4.0,
            active_winch=true,
            damping_mode=2.0,
            EA_back_line=700000.0,
            c_back_line=500.0,
            i_pto=25.0,
            field_imu=true,
            mppt_stall=false,
            payout_base_m=15.0,
            lifter_elev_deg=75.0,
            duration_s=10.0,
        ),
        (
            wind_speed=20.0,
            payout_duration=15.0,
            active_winch=true,
            damping_mode=2.0,
            EA_back_line=700000.0,
            c_back_line=500.0,
            i_pto=25.0,
            field_imu=true,
            mppt_stall=false,
            payout_base_m=15.0,
            lifter_elev_deg=75.0,
            duration_s=10.0,
        ),
    ]
end

# ── Metric derivation from DepowerResult ──────────────────────────────────────
function derive_metrics(res::DepowerResult, config::NamedTuple, run_id::Int)
    times = res.times
    omega_h = res.omega_hub
    omega_g = res.omega_gnd
    tau_g = res.tau_gen
    T_mx = res.T_max
    n_sl = res.n_slack
    payout = res.backline_payout

    n = length(times)
    if n < 2
        return (
            run_id=run_id,
            config...,
            d_tau_gen_rms=NaN,
            d_omega_rms=NaN,
            T_min=NaN,
            T_mean=NaN,
            T_std=NaN,
            slack_events=0,
            brake_time=NaN,
            brake_engaged=false,
            omega_hub_final=NaN,
            omega_gnd_final=NaN,
            time_to_omega1=NaN,
            max_payout_reached=NaN,
            peak_tau_gen=NaN,
            min_tension_before_brake=NaN,
            T_cyan_min=NaN,
            twist_max=NaN,
            fos_buckling_min=NaN,
            is_disqualified=1,
            disqualification_reason="degenerate_run",
            smoothness_raw=NaN,
            tension_raw=NaN,
            composite_score=-99999.0,
        )
    end

    dt_fr = (times[end] - times[1]) / (n - 1)

    # Smoothness metrics
    d_tau = diff(tau_g) ./ dt_fr
    d_tau_rms = sqrt(mean(d_tau .^ 2))

    d_omega = diff(omega_h) ./ dt_fr
    d_omega_rms = sqrt(mean(d_omega .^ 2))

    # Tension stability
    T_min_val = minimum(T_mx)
    T_mean_val = mean(T_mx)
    T_std_val = std(T_mx)
    slack_ev = sum(n_sl .> 0)

    # Brake metrics
    brake_eng = !isnan(res.brake_time)
    brake_t = res.brake_time

    t_omega1 = findfirst(x -> x < 1.0, omega_h)
    time_to_omega1 = isnothing(t_omega1) ? NaN : times[t_omega1]

    max_payout_r = maximum(payout)
    half = max(1, n ÷ 2)
    peak_tg = maximum(tau_g[1:half])
    tail_start = max(1, round(Int, 0.8 * n))
    T_min_tail = minimum(T_mx[tail_start:end])

    # ── Phase-Aware Safety Disqualifications ──
    is_disqualified = false
    disq_reason = "none"

    if res.T_cyan_min < 50.0
        is_disqualified = true
        disq_reason = "slack_sky_anchor"
    elseif res.twist_max >= 0.95 * pi
        is_disqualified = true
        disq_reason = "tulloch_overtwist"
    elseif res.fos_buckling_min < 1.5
        is_disqualified = true
        disq_reason = "ring_buckling"
    end

    smoothness_raw = d_tau_rms + 0.5 * d_omega_rms
    tension_raw = T_min_val - 200.0 * slack_ev

    # Set composite score to massive penalty if disqualified
    composite = is_disqualified ? -99999.0 : -smoothness_raw + 0.01 * tension_raw

    return (
        run_id=run_id,
        wind_speed=config.wind_speed,
        payout_duration=config.payout_duration,
        active_winch=Int(config.active_winch),
        damping_mode=Int(config.damping_mode),
        EA_back_line=config.EA_back_line,
        c_back_line=config.c_back_line,
        i_pto=config.i_pto,
        field_imu=Int(config.field_imu),
        mppt_stall=Int(config.mppt_stall),
        payout_base_m=config.payout_base_m,
        lifter_elev_deg=config.lifter_elev_deg,
        duration_s=config.duration_s,
        d_tau_gen_rms=d_tau_rms,
        d_omega_rms=d_omega_rms,
        T_min=T_min_val,
        T_mean=T_mean_val,
        T_std=T_std_val,
        slack_events=slack_ev,
        brake_time=brake_t,
        brake_engaged=Int(brake_eng),
        omega_hub_final=omega_h[end],
        omega_gnd_final=omega_g[end],
        time_to_omega1=time_to_omega1,
        max_payout_reached=max_payout_r,
        peak_tau_gen=peak_tg,
        min_tension_before_brake=T_min_tail,
        T_cyan_min=res.T_cyan_min,
        twist_max=res.twist_max,
        fos_buckling_min=res.fos_buckling_min,
        is_disqualified=Int(is_disqualified),
        disqualification_reason=disq_reason,
        smoothness_raw=smoothness_raw,
        tension_raw=tension_raw,
        composite_score=composite,
    )
end

function save_timeseries(res::DepowerResult, run_id::Int)
    path = joinpath(RESULTS_DIR, @sprintf("timeseries_%04d.csv", run_id))
    df = DataFrame(;
        t=res.times,
        omega_hub=res.omega_hub,
        omega_gnd=res.omega_gnd,
        tau_gen=res.tau_gen,
        T_max=res.T_max,
        n_slack=res.n_slack,
        backline_payout=res.backline_payout,
        k_mppt_scale=res.k_mppt_scale,
    )
    return CSV.write(path, df)
end

# ── Single run execution ──────────────────────────────────────────────────────
function run_one(run_id::Int, config::NamedTuple; save_ts::Bool=true)
    try
        p_base = params_10kw()

        # Wire wind speed, lifter elevation, backline parameters, and PTO inertia dynamically
        p_base = override_params(
            p_base;
            lifter_elevation=deg2rad(config.lifter_elev_deg),
            v_wind_ref=config.wind_speed,
            EA_back_line=config.EA_back_line,
            c_back_line=config.c_back_line,
            i_pto=config.i_pto,
        )

        # Build system and settle
        sys, u0 = build_kite_turbine_system(p_base)
        lift_dev = rotary_lifter_default()

        wind_fn = let vref = p_base.v_wind_ref, href = p_base.h_ref
            (pos, t) -> begin
                z = max(pos[3], 1.0)
                [vref * (z / href)^(1/7), 0.0, 0.0]
            end
        end

        ω_rated = cbrt(p_base.p_rated_w / p_base.k_mppt)
        u_s = settle_to_operational_state(
            sys, u0, p_base, ω_rated; lift_device=lift_dev, wind_fn=wind_fn
        )

        # 5-line standard step
        dt = 4e-5
        n_steps = round(Int, config.duration_s / dt)

        # Reset mechanical brake
        sys.brake_engaged[] = false

        # Execute dynamic solver
        res = run_pitch_depower!(
            copy(u_s),
            sys,
            p_base,
            wind_fn,
            n_steps,
            dt;
            lift_device=lift_dev,
            use_active_winch=config.active_winch,
            use_mppt_stall=config.mppt_stall,
            use_field_imu=config.field_imu,
            payout_base=config.payout_base_m,
            damping_mode=Float64(config.damping_mode),
            depower_sequence=3, # focused on Sequence 3 (Lift -> Stall)
            payout_duration=config.payout_duration,
        )

        save_ts && save_timeseries(res, run_id)
        return derive_metrics(res, config, run_id)

    catch e
        @warn "Run $run_id failed" exception=(e, catch_backtrace())
        return (
            run_id=run_id,
            wind_speed=config.wind_speed,
            payout_duration=config.payout_duration,
            active_winch=Int(config.active_winch),
            damping_mode=Int(config.damping_mode),
            EA_back_line=config.EA_back_line,
            c_back_line=config.c_back_line,
            i_pto=config.i_pto,
            field_imu=Int(config.field_imu),
            mppt_stall=Int(config.mppt_stall),
            payout_base_m=config.payout_base_m,
            lifter_elev_deg=config.lifter_elev_deg,
            duration_s=config.duration_s,
            d_tau_gen_rms=NaN,
            d_omega_rms=NaN,
            T_min=NaN,
            T_mean=NaN,
            T_std=NaN,
            slack_events=0,
            brake_time=NaN,
            brake_engaged=0,
            omega_hub_final=NaN,
            omega_gnd_final=NaN,
            time_to_omega1=NaN,
            max_payout_reached=NaN,
            peak_tau_gen=NaN,
            min_tension_before_brake=NaN,
            T_cyan_min=NaN,
            twist_max=NaN,
            fos_buckling_min=NaN,
            is_disqualified=1,
            disqualification_reason="solver_error",
            smoothness_raw=NaN,
            tension_raw=NaN,
            composite_score=-99999.0,
        )
    end
end

# ── High-Performance Main Campaign ───────────────────────────────────────────
function main()
    smoke_test = "--test" in ARGS
    grid = smoke_test ? build_smoke_grid() : build_grid()
    n_runs = length(grid)

    @info "Pitch Depower Campaign V3" n_runs=n_runs threads=nthreads() smoke_test=smoke_test
    @info "Results directory" RESULTS_DIR

    metrics_path = joinpath(RESULTS_DIR, "campaign_metrics.csv")
    results = Vector{Any}(undef, n_runs)
    t_start = time()

    # ── Channel-based Worker Pool ──
    task_channel = Channel{Tuple{Int, NamedTuple}}(n_runs)
    for (i, config) in enumerate(grid)
        put!(task_channel, (i, config))
    end
    close(task_channel)

    completed_count = Threads.Atomic{Int}(0)

    @sync for t in 1:nthreads()
        Threads.@spawn begin
            for (i, config) in task_channel
                results[i] = run_one(i, config; save_ts=true)
                Threads.atomic_add!(completed_count, 1)
                done = completed_count[]
                elapsed = time() - t_start
                rate = done / elapsed
                eta = (n_runs - done) / max(rate, 1e-6)
                @info @sprintf(
                    "Run %4d / %4d  [%.0f s elapsed, ETA %.0f min]",
                    done,
                    n_runs,
                    elapsed,
                    eta / 60
                )
            end
        end
    end

    # Write campaign summary CSV
    df = DataFrame([NamedTuple(r) for r in results])
    CSV.write(metrics_path, df)

    elapsed_total = time() - t_start
    @info @sprintf(
        "Campaign V3 complete: %d runs in %.1f minutes", n_runs, elapsed_total / 60
    )
    @info "Summary CSV" metrics_path
end

main()
